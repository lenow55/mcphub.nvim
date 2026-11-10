-- Tests for server description propagation
-- Custom `description` from the servers.json config must be propagated
-- to the server objects returned by MCPHub:get_servers()
local new_set = MiniTest.new_set
local expect, eq = MiniTest.expect, MiniTest.expect.equality

local T = new_set({})

local TEST_CONFIG = vim.fn.tempname() .. "_server_description.json"

local function write_config(servers)
    local mcpServers = {}
    for name, desc in pairs(servers) do
        mcpServers[name] = { command = "echo", description = desc }
    end
    local file = io.open(TEST_CONFIG, "w")
    file:write(vim.json.encode({ mcpServers = mcpServers }))
    file:close()
end

local function setup_hub(servers_config, server_objects)
    write_config(servers_config)
    local State = require("mcphub.state")
    State.config_files_cache = {}
    State.server_state.servers = server_objects
    local MCPHub = require("mcphub.hub")
    local hub = MCPHub:new(require("tests.config"))
    hub.ready = true
    return hub
end

local function make_backend_server(name, backend_description)
    return {
        name = name,
        description = backend_description,
        config_source = TEST_CONFIG,
        status = "connected",
        capabilities = {
            tools = { { name = "some_tool", description = "a tool" } },
            resources = {},
            resourceTemplates = {},
            prompts = {},
        },
    }
end

T["get_servers"] = new_set({
    hooks = {
        post_case = function()
            if vim.uv.fs_stat(TEST_CONFIG) then
                vim.uv.fs_unlink(TEST_CONFIG)
            end
        end,
    },
})

T["get_servers"]["custom_description_replaces_backend"] = function()
    local hub = setup_hub(
        { ["with-desc"] = "My custom description" },
        { make_backend_server("with-desc", "backend description") }
    )

    local servers = hub:get_servers()
    eq(#servers, 1)
    eq(servers[1].description, "My custom description")
end

T["get_servers"]["backend_description_kept_when_config_empty"] = function()
    local hub = setup_hub({ ["no-desc"] = "" }, { make_backend_server("no-desc", "backend description") })

    local servers = hub:get_servers()
    eq(servers[1].description, "backend description")
end

T["get_servers"]["description_not_in_config_kept_from_backend"] = function()
    local hub = setup_hub({}, { make_backend_server("no-desc", "backend description") })

    local servers = hub:get_servers()
    eq(servers[1].description, "backend description")
end

T["validation"] = new_set()

T["validation"]["string_description_is_valid"] = function()
    local validation = require("mcphub.utils.validation")
    local result = validation.validate_server_config("srv", {
        command = "echo",
        description = "valid description",
    })
    eq(result.ok, true)
end

T["validation"]["non_string_description_is_rejected"] = function()
    local validation = require("mcphub.utils.validation")
    local result = validation.validate_server_config("srv", {
        command = "echo",
        description = 42,
    })
    eq(result.ok, false)
end

return T
