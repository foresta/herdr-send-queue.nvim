-- herdr CLI を叩くだけの薄い transport。pty は特定も open も write もしない。
-- pane_id という論理ターゲットを渡すだけで、解決と書き込みは herdr の内側で完結する。
local config = require("herdr-send-queue.config")

local M = {}

-- herdr を同期実行する。戻りは (stdout, nil) か (nil, err:string)。
local function run(args)
  local cmd = config.get().herdr.cmd
  local argv = { cmd }
  vim.list_extend(argv, args)

  local ok, res = pcall(function()
    return vim.system(argv, { text = true }):wait()
  end)
  if not ok then
    return nil, string.format("herdr の起動に失敗しました（%s が PATH にありますか）: %s", cmd, tostring(res))
  end
  if res.code ~= 0 then
    local msg = res.stderr
    if msg == nil or msg == "" then
      msg = res.stdout or ""
    end
    return nil, string.format("`herdr %s` が失敗しました (code=%d): %s", args[1] or "", res.code, vim.trim(msg))
  end
  return res.stdout or "", nil
end

-- テキスト + Enter を送る（herdr agent prompt）。
-- opts.submit=false なら未送信ステージ（herdr pane send-text、target は pane_id）。
-- vim.system は shell を介さないので text は 1 argv として渡り、multiline でもクォート不要。
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

-- 生キー（ctrl+c, esc 等）を送る。
function M.send_keys(target, ...)
  local args = { "agent", "send-keys", target }
  for _, k in ipairs({ ... }) do
    table.insert(args, k)
  end
  return M._run_keys(args)
end

-- send_keys のテスト用に run を公開しておく内部ヘルパ。
function M._run_keys(args)
  return run(args)
end

-- `herdr agent list` を parse して agent 配列を返す。
-- 出力は {"result":{"agents":[{agent, cwd, foreground_cwd, pane_id, tab_id, workspace_id, ...}]}}。
function M.list_agents()
  local out, err = run({ "agent", "list" })
  if err then
    return nil, err
  end
  local ok, parsed = pcall(vim.json.decode, out)
  if not ok then
    return nil, "herdr agent list の JSON 解析に失敗しました: " .. tostring(parsed)
  end
  local agents = parsed and parsed.result and parsed.result.agents
  if type(agents) ~= "table" then
    return nil, "herdr agent list の構造が想定と異なります（result.agents が無い）"
  end
  return agents, nil
end

-- `herdr pane list` を parse して pane 配列を返す。
-- 各要素は pane_id / cwd / foreground_cwd / terminal_title(_stripped) / tab_id / workspace_id、
-- agent を抱える pane には agent / agent_status も付く（agent 無し＝素の shell/REPL 等）。
function M.list_panes()
  local out, err = run({ "pane", "list" })
  if err then
    return nil, err
  end
  local ok, parsed = pcall(vim.json.decode, out)
  if not ok then
    return nil, "herdr pane list の JSON 解析に失敗しました: " .. tostring(parsed)
  end
  local panes = parsed and parsed.result and parsed.result.panes
  if type(panes) ~= "table" then
    return nil, "herdr pane list の構造が想定と異なります（result.panes が無い）"
  end
  return panes, nil
end

-- agent の画面テキストを読む（MVP では flush から駆動しない。返答取り込みは KAZ-31）。
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
