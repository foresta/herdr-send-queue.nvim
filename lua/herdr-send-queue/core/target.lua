-- 送信先の解決。同名 agent（別リポジトリの claude）が複数動くので名前では一意にならない。
-- nvim の git root と一致する agent の pane_id を target にする。複数/ゼロは picker。
local herdr = require("herdr-send-queue.core.herdr")
local config = require("herdr-send-queue.config")

local M = {}

-- 末尾スラッシュを落として正規化する。
local function norm(path)
  if not path or path == "" then
    return nil
  end
  return (path:gsub("/+$", ""))
end

-- 指定ディレクトリの git root を返す。取れなければ nil。
---@param dir? string
---@return string? root, string? err
function M.git_root(dir)
  dir = dir or vim.fn.getcwd()
  local res = vim.system({ "git", "-C", dir, "rev-parse", "--show-toplevel" }, { text = true }):wait()
  if res.code ~= 0 then
    return nil, "git root を特定できません（git リポジトリ内で実行してください）"
  end
  return norm(vim.trim(res.stdout or "")), nil
end

-- agent の cwd が root と一致するか。
local function matches(agent, root)
  if norm(agent.cwd) == root then
    return true
  end
  if config.get().target.match_foreground_cwd and norm(agent.foreground_cwd) == root then
    return true
  end
  return false
end

-- picker を出して 1 つ選ばせる。vim.ui.select は非同期なので callback で返す。
---@param agents table[]
---@param cb fun(pane_id: string|nil, err: string|nil)
local function pick(agents, cb)
  vim.ui.select(agents, {
    prompt = "送信先の agent を選択",
    format_item = function(a)
      return string.format("%s  [%s]  %s", a.agent or "?", a.pane_id or "?", a.cwd or "")
    end,
  }, function(choice)
    if not choice then
      return cb(nil, "送信先の選択がキャンセルされました")
    end
    cb(choice.pane_id, nil)
  end)
end

-- 現在のバッファ（なければ cwd）を起点に送信先 pane_id を解決する。
-- 一意なら即 callback、複数/ゼロは picker にフォールバックする。
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
    -- cwd 一致が無いときは全 agent から選ばせる（別 tab/別リポの agent へ送る導線）。
    if #agents == 0 then
      return cb(nil, "起動中の agent が見つかりません")
    end
    return pick(agents, cb)
  end
  -- 複数一致（worktree 等で cwd が被る）も picker。
  return pick(matched, cb)
end

-- 全 pane から送信先を選ぶ共通 picker（flush の明示選択 / send preset で共有）。
-- フローによる出し分けはせず、常に同じ全 pane 一覧を出す。
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
    return cb(nil, "pane が見つかりません")
  end
  vim.ui.select(panes, { prompt = "送信先 pane を選択", format_item = pane_label }, function(choice)
    if not choice then
      return cb(nil, "送信先の選択がキャンセルされました")
    end
    cb(choice.pane_id, nil)
  end)
end

return M
