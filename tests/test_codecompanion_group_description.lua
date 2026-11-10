-- Tests for CodeCompanion dynamic tool group descriptions
-- A custom `description` in the servers.json config must fully replace
-- the auto-generated "All tools from <server> MCP server" group description
local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T = new_set({})

local TEST_CONFIG = vim.fn.tempname() .. "_codecompanion_description.json"

local function write_config()
    local json = '{"mcpServers": {'
        .. '"with-desc": {"command": "echo", "description": "My custom description"}, '
        .. '"no-desc": {"command": "echo"}'
        .. "}}"
    local file = io.open(TEST_CONFIG, "w")
    file:write(json)
    file:close()
end

local function make_backend_server(name, backend_description)
    return {
        name = name,
        description = backend_description,
        config_source = TEST_CONFIG,
        status = "connected",
        capabilities = {
            tools = {
                { name = "tool_a", description = "tool a" },
                { name = "tool_b", description = "tool b" },
            },
            resources = {},
            resourceTemplates = {},
            prompts = {},
        },
    }
end

T["register"] = new_set({
    hooks = {
        pre_case = function()
            -- Stub codecompanion.config: the real plugin is not installed in tests
            package.loaded["codecompanion.config"] = {
                interactions = {
                    chat = {
                        tools = {
                            groups = {},
                        },
                    },
                },
            }
            local State = require("mcphub.state")
            State.config_files_cache = {}
            State.server_state.servers = {}
            write_config()
        end,
        post_case = function()
            package.loaded["codecompanion.config"] = nil
            if vim.uv.fs_stat(TEST_CONFIG) then
                vim.uv.fs_unlink(TEST_CONFIG)
            end
        end,
    },
})

--- Setup the plugin and point the real state module at the given servers
local function register_with(servers)
    local hub = require("tests.helpers").setup_plugin({
        config = TEST_CONFIG,
    })
    local State = require("mcphub.state")
    State.setup_state = "completed"
    State.hub_instance = hub
    State.server_state.servers = servers

    require("mcphub.extensions.codecompanion.tools").register({})
    return package.loaded["codecompanion.config"].interactions.chat.tools
end

T["register"]["custom_description_fully_replaces_group_description"] = function()
    local cfg = register_with({ make_backend_server("with-desc", "backend description") })
    -- safe name: "with-desc" -> "with_desc"
    eq(cfg.groups.with_desc.description, "My custom description")
end

T["register"]["default_description_when_config_has_none"] = function()
    local cfg = register_with({ make_backend_server("no-desc", "backend description") })
    eq(cfg.no_desc__tool_a.description, "tool a")
    local group = cfg.groups.no_desc
    eq(group.description, " All tools from `no-desc` MCP server: \n\n - `no_desc__tool_a` \n - `no_desc__tool_b` ")
end

return T
