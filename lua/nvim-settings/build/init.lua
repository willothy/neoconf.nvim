local util = require("nvim-settings.util")
local Schema = require("nvim-settings.schema")

local M = {}

---@param schema LspSchema
function M.get_schema(schema)
  local json = util.json_decode(util.fetch(schema.package_url)) or {}
  local config = json.contributes and json.contributes.configuration or json.properties and json

  local properties = {}

  if vim.tbl_islist(config) then
    for _, c in pairs(config) do
      vim.list_extend(properties, c.properties)
    end
  elseif config.properties then
    properties = config.properties
  end

  if schema.build then
    schema.build(properties)
  end

  return {
    ["$schema"] = "http://json-schema.org/draft-07/schema#",
    description = json.description,
    properties = properties,
  }
end

function M.clean()
  ---@diagnostic disable-next-line: param-type-mismatch
  for _, f in pairs(vim.fn.expand("schemas/*.json", false, true)) do
    vim.loop.fs_unlink(f)
  end
end

function M.update_index()
  local url = "https://gist.githubusercontent.com/williamboman/a01c3ce1884d4b57cc93422e7eae7702/raw/lsp-packages.json"
  local index = util.fetch(url)
  util.write_file(
    "lua/settings/build/lsp.lua",
    "--- auto generated from " .. url .. "\nreturn " .. vim.inspect(util.json_decode(index))
  )
end

function M.update_schemas()
  for name, s in pairs(Schema.get_lsp_schemas()) do
    print(("Generating schema for %s"):format(name))

    if not util.exists(s.settings_file) then
      local schema = M.get_schema(s)
      util.write_file(s.settings_file, util.json_format(schema))
    end
  end
end

function M.docs()
  local schemas = Schema.get_lsp_schemas()
  local keys = vim.tbl_keys(schemas)
  table.sort(keys)
  local lines = {}

  for _, name in ipairs(keys) do
    local schema = schemas[name]
    local url = schema.package_url
    if url:find("githubusercontent") then
      url = url
        :gsub("raw%.githubusercontent", "github")
        :gsub("/master/", "/tree/master/", 1)
        :gsub("/main/", "/tree/main/", 1)
    end
    table.insert(lines, ("- [x] [%s](%s)"):format(name, url))
  end
  local str = "<!-- GENERATED -->\n" .. table.concat(lines, "\n")
  local md = util.read_file("README.md")
  md = md:gsub("<!%-%- GENERATED %-%->.*", str) .. "\n"
  util.write_file("README.md", md)
end

function M.build()
  M.clean()
  M.update_index()
  M.update_schemas()
  require("nvim-settings.build.annotations").build()
  M.docs()
end

M.build()

return M