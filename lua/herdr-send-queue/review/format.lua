-- Format the queue (kind="review") into one prompt string to send to the agent.
local config = require("herdr-send-queue.config")

local M = {}

-- location -> file reference string. The format differs by agent type.
-- claude: @relpath#Lx (ranges use #Lx-Ly). Use an @-prefixed relative path instead of an absolute one to avoid the agent mis-parsing it as a slash-command.
-- plain:  relpath:x (ranges use relpath:x-y). For CLIs without a prefix.
---@param loc Location
---@param agent_type string
local function reference(loc, agent_type)
  local has_range = loc.end_lnum and loc.end_lnum ~= loc.lnum
  if agent_type == "plain" then
    if has_range then
      return string.format("%s:%d-%d", loc.relpath, loc.lnum, loc.end_lnum)
    end
    return string.format("%s:%d", loc.relpath, loc.lnum)
  end
  -- Default (claude)
  if has_range then
    return string.format("@%s#L%d-L%d", loc.relpath, loc.lnum, loc.end_lnum)
  end
  return string.format("@%s#L%d", loc.relpath, loc.lnum)
end

-- Format an array of fragments into one prompt.
---@param list Fragment[]
---@param opts? { agent_type?: string, header?: string }
---@return string
function M.format(list, opts)
  opts = opts or {}
  local cfg = config.get().format
  local agent_type = opts.agent_type or cfg.agent_type
  local header = opts.header or cfg.header

  local blocks = {}
  for i, f in ipairs(list) do
    local lines = {}
    if f.location then
      table.insert(lines, string.format("%d. %s", i, reference(f.location, agent_type)))
      table.insert(lines, f.text)
    else
      table.insert(lines, string.format("%d. %s", i, f.text))
    end
    table.insert(blocks, table.concat(lines, "\n"))
  end

  local body = table.concat(blocks, "\n\n")
  if header and header ~= "" then
    return header .. "\n\n" .. body
  end
  return body
end

return M
