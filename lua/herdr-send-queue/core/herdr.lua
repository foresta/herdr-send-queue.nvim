-- Thin transport that only calls the herdr CLI. It never locates, opens, or writes to a pty.
-- It only passes a logical pane_id target; herdr resolves it and does the writing internally.
local config = require("herdr-send-queue.config")

local M = {}

-- Run herdr synchronously. Returns (stdout, nil) or (nil, err:string).
local function run(args)
  local cmd = config.get().herdr.cmd
  local argv = { cmd }
  vim.list_extend(argv, args)

  local ok, res = pcall(function()
    return vim.system(argv, { text = true }):wait()
  end)
  if not ok then
    return nil, string.format("failed to start herdr (is %s on your PATH?): %s", cmd, tostring(res))
  end
  if res.code ~= 0 then
    local msg = res.stderr
    if msg == nil or msg == "" then
      msg = res.stdout or ""
    end
    return nil, string.format("`herdr %s` failed (code=%d): %s", args[1] or "", res.code, vim.trim(msg))
  end
  return res.stdout or "", nil
end

-- Send text + Enter (herdr agent prompt).
-- With opts.submit=false, stage without submitting (herdr pane send-text, target is pane_id).
-- vim.system does not go through a shell, so text is passed as a single argv and needs no quoting even when multiline.
function M.send(target, text, opts)
  opts = opts or {}
  local submit = opts.submit
  if submit == nil then
    submit = true
  end
  if submit then
    return run({ "agent", "prompt", target, text })
  end
  return run({ "pane", "send-text", target, text })
end

-- Send raw keys (ctrl+c, esc, etc.).
function M.send_keys(target, ...)
  local args = { "agent", "send-keys", target }
  for _, k in ipairs({ ... }) do
    table.insert(args, k)
  end
  return M._run_keys(args)
end

-- Internal helper that exposes run for testing send_keys.
function M._run_keys(args)
  return run(args)
end

-- Parse `herdr agent list` and return the array of agents.
-- Output is {"result":{"agents":[{agent, cwd, foreground_cwd, pane_id, tab_id, workspace_id, ...}]}}.
function M.list_agents()
  local out, err = run({ "agent", "list" })
  if err then
    return nil, err
  end
  local ok, parsed = pcall(vim.json.decode, out)
  if not ok then
    return nil, "failed to parse JSON from herdr agent list: " .. tostring(parsed)
  end
  local agents = parsed and parsed.result and parsed.result.agents
  if type(agents) ~= "table" then
    return nil, "unexpected structure from herdr agent list (no result.agents)"
  end
  return agents, nil
end

-- Parse `herdr pane list` and return the array of panes.
-- Each element has pane_id / cwd / foreground_cwd / terminal_title(_stripped) / tab_id / workspace_id,
-- and a pane hosting an agent also carries agent / agent_status (no agent = plain shell/REPL, etc.).
function M.list_panes()
  local out, err = run({ "pane", "list" })
  if err then
    return nil, err
  end
  local ok, parsed = pcall(vim.json.decode, out)
  if not ok then
    return nil, "failed to parse JSON from herdr pane list: " .. tostring(parsed)
  end
  local panes = parsed and parsed.result and parsed.result.panes
  if type(panes) ~= "table" then
    return nil, "unexpected structure from herdr pane list (no result.panes)"
  end
  return panes, nil
end

-- Read the agent's screen text (not driven from flush in the MVP; used by response capture).
function M.read(target, opts)
  opts = opts or {}
  local args = { "agent", "read", target, "--format", "text" }
  if opts.source then
    vim.list_extend(args, { "--source", opts.source })
  end
  if opts.lines then
    vim.list_extend(args, { "--lines", tostring(opts.lines) })
  end
  return run(args)
end

return M
