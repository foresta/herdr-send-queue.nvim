-- Resolve the target. Multiple agents share a name (e.g. a claude per repository), so the name is not unique.
-- Use the pane_id of the agent whose git root matches nvim's as the target. Multiple/zero matches fall back to a picker.
local herdr = require("herdr-send-queue.core.herdr")
local config = require("herdr-send-queue.config")

local M = {}

-- Normalize by dropping trailing slashes.
local function norm(path)
  if not path or path == "" then
    return nil
  end
  return (path:gsub("/+$", ""))
end

-- Return the git root of the given directory, or nil if it cannot be found.
---@param dir? string
---@return string? root, string? err
function M.git_root(dir)
  dir = dir or vim.fn.getcwd()
  local res = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if res.code ~= 0 then
    return nil, "cannot determine git root (run inside a git repository)"
  end
  return norm(vim.trim(res.stdout or "")), nil
end

-- Whether the agent's cwd matches root.
local function matches(agent, root)
  if norm(agent.cwd) == root then
    return true
  end
  if config.get().target.match_foreground_cwd and norm(agent.foreground_cwd) == root then
    return true
  end
  return false
end

-- Show a picker to let the user choose one. vim.ui.select is async, so return via callback.
---@param agents table[]
---@param cb fun(pane_id: string|nil, err: string|nil)
local function pick(agents, cb)
  vim.ui.select(agents, {
    prompt = "Select target agent",
    format_item = function(a)
      return string.format("%s  [%s]  %s", a.agent or "?", a.pane_id or "?", a.cwd or "")
    end,
  }, function(choice)
    if not choice then
      return cb(nil, "target selection was cancelled")
    end
    cb(choice.pane_id, nil)
  end)
end

-- Resolve the target pane_id starting from the current buffer (or cwd if none).
-- If unique, call back immediately; multiple/zero matches fall back to the picker.
---@param opts? { dir?: string }
---@param cb fun(pane_id: string|nil, err: string|nil)
function M.resolve(opts, cb)
  opts = opts or {}
  local root, err = M.git_root(opts.dir)
  if not root then
    return cb(nil, err)
  end

  local agents
  agents, err = herdr.list_agents()
  if not agents then
    return cb(nil, err)
  end

  local matched = {}
  for _, a in ipairs(agents) do
    if a.pane_id and matches(a, root) then
      table.insert(matched, a)
    end
  end

  if #matched == 1 then
    return cb(matched[1].pane_id, nil)
  end
  if #matched == 0 then
    -- When no cwd matches, let the user pick from all agents (a path to send to an agent in another tab/repo).
    if #agents == 0 then
      return cb(nil, "no running agent found")
    end
    return pick(agents, cb)
  end
  -- Multiple matches (e.g. worktrees sharing a cwd) also use the picker.
  return pick(matched, cb)
end

-- Shared picker for choosing a target from all panes (used by flush's explicit selection and the send preset).
-- It does not vary by flow; it always shows the same full list of panes.
local function pane_label(p)
  local title = p.terminal_title_stripped or p.terminal_title or ""
  local agent = p.agent and ("[" .. p.agent .. "] ") or ""
  return string.format("%s  %s%s  %s", p.pane_id or "?", agent, title, p.cwd or "")
end

---@param cb fun(pane_id: string|nil, err: string|nil)
function M.pick_pane(cb)
  local panes, err = herdr.list_panes()
  if not panes then
    return cb(nil, err)
  end
  if #panes == 0 then
    return cb(nil, "no pane found")
  end
  vim.ui.select(panes, { prompt = "Select target pane", format_item = pane_label }, function(choice)
    if not choice then
      return cb(nil, "target selection was cancelled")
    end
    cb(choice.pane_id, nil)
  end)
end

return M
