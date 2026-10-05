-- 一覧パネル view。右 split に常駐し、queue をファイルごとにグルーピングして表示する。
-- <CR> で該当ファイル:行へジャンプ、d で削除。queue.list() + 変更通知だけで動く drop-in。
local queue = require("herdr-send-queue.queue")

local M = {}

local WIDTH = 42
local state = {
  win = nil,
  buf = nil,
  from_win = nil, -- ジャンプ先に使う元 window
  line_ids = {}, -- 表示行 index → fragment id（ヘッダ行は nil）
}

local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- queue をファイルごとにまとめて行テキストへ。line_ids も作る。
local function render()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  local items = queue.list()
  local lines = {}
  state.line_ids = {}

  if #items == 0 then
    lines = { "（queue は空です）", "", "<CR>: 移動  d: 削除  q: 閉じる" }
  else
    -- relpath ごとに順序を保ってグルーピング
    local order, groups = {}, {}
    for _, f in ipairs(items) do
      local key = (f.location and f.location.relpath) or "(メモのみ)"
      if not groups[key] then
        groups[key] = {}
        table.insert(order, key)
      end
      table.insert(groups[key], f)
    end

    for _, key in ipairs(order) do
      table.insert(lines, string.format("▸ %s (%d)", key, #groups[key]))
      state.line_ids[#lines] = nil -- ヘッダ
      for _, f in ipairs(groups[key]) do
        local loc = f.location
        local pos = ""
        if loc then
          pos = "L" .. loc.lnum
          if loc.end_lnum and loc.end_lnum ~= loc.lnum then
            pos = pos .. "-" .. loc.end_lnum
          end
        end
        local first = (f.text or ""):gsub("\n.*$", "")
        table.insert(lines, string.format("   %-8s %s", pos, first))
        state.line_ids[#lines] = f.id
      end
    end
    table.insert(lines, "")
    table.insert(lines, "<CR>: 移動  d: 削除  q: 閉じる")
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

-- ジャンプ先 window を決める（パネル以外の通常 window を優先）。
local function target_win()
  if state.from_win and vim.api.nvim_win_is_valid(state.from_win) and state.from_win ~= state.win then
    return state.from_win
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if w ~= state.win and vim.api.nvim_win_get_config(w).relative == "" then
      return w
    end
  end
  return nil
end

-- カーソル行の fragment を開く。
local function jump()
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  local id = state.line_ids[row]
  if not id then
    return
  end
  local f = queue.get(id)
  if not (f and f.location) then
    return
  end
  local tw = target_win()
  if tw then
    vim.api.nvim_set_current_win(tw)
  else
    -- パネルしか無ければ左に split を作る
    vim.cmd("topleft vsplit")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(f.location.path))
  local lnum = math.min(f.location.lnum, vim.api.nvim_buf_line_count(0))
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
end

-- カーソル行の fragment を削除。
local function remove_under_cursor()
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  local id = state.line_ids[row]
  if id then
    queue.remove(id) -- 通知経由で render
  end
end

local function setup_keymaps()
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = state.buf, nowait = true, silent = true })
  end
  map("q", M.close)
  map("<CR>", jump)
  map("d", remove_under_cursor)
end

-- パネルを開く（既に開いていれば focus）。
function M.open()
  if is_open() then
    vim.api.nvim_set_current_win(state.win)
    return
  end
  state.from_win = vim.api.nvim_get_current_win()

  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].bufhidden = "hide" -- 閉じてもバッファは残す（トグル用）
    vim.bo[state.buf].buftype = "nofile"
    vim.bo[state.buf].swapfile = false
    vim.bo[state.buf].filetype = "herdr-send-queue"
    vim.api.nvim_buf_set_name(state.buf, "herdr-send-queue://panel")
  end

  vim.cmd("botright vsplit")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(state.win, WIDTH)
  vim.api.nvim_win_set_buf(state.win, state.buf)
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].wrap = false
  vim.wo[state.win].cursorline = true
  vim.wo[state.win].winfixwidth = true

  setup_keymaps()
  render()
end

function M.close()
  if is_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

function M.toggle()
  if is_open() then
    M.close()
  else
    M.open()
  end
end

-- 変更通知を購読して、開いている間だけ再描画する。setup から 1 回だけ呼ぶ。
function M.setup_autocmd()
  local group = vim.api.nvim_create_augroup("HerdrSendQueuePanel", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "HerdrSendQueueChanged",
    callback = function()
      if is_open() then
        render()
      end
    end,
  })
end

return M
