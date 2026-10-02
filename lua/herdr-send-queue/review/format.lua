-- queue（kind="review"）→ agent へ送る 1 プロンプト文字列へ整形する。
local config = require("herdr-send-queue.config")

local M = {}

-- location → ファイル参照文字列。agent 種別で形式が違う。
-- claude: @relpath#Lx（範囲は #Lx-Ly）。絶対パスでなく @ 付き相対にして slash-command 誤爆を避ける。
-- plain:  relpath:x（範囲は relpath:x-y）。prefix 無しの CLI 向け。
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
  -- 既定（claude）
  if has_range then
    return string.format("@%s#L%d-L%d", loc.relpath, loc.lnum, loc.end_lnum)
  end
  return string.format("@%s#L%d", loc.relpath, loc.lnum)
end

-- fragment 配列を 1 プロンプトへ整形する。
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
