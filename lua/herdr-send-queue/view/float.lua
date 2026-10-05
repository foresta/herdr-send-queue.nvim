-- MVP の一覧 view。floating window に queue を表示し、User HerdrSendQueueChanged で再描画する。
-- queue.list() を読むだけなので、将来の自作 view（KAZ-28）も同じ契約で差し替えできる。
local queue = require("herdr-send-queue.queue")

local M = {}

local state = {
  win = nil,
  buf = nil,
  -- 表示中の行 index → fragment id
  line_ids = {},
}

local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- queue を行テキストへ描画し、行→id の対応を作る。
local function render()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  local items = queue.list()
  local lines = {}
  state.line_ids = {}

  if #items == 0 then
    lines = { "（queue は空です）", "", "d: 削除  q/<Esc>: 閉じる" }
  else
    for _, f in ipairs(items) do
      local label = "(メモのみ)"
      if f.location then
        local loc = f.location
        label = loc.relpath .. ":" .. tostring(loc.lnum)
        if loc.end_lnum and loc.end_lnum ~= loc.lnum then
          label = label .. "-" .. tostring(loc.end_lnum)
        end
      end
      -- メモは 1 行目だけ要約表示
      local first = (f.text or ""):gsub("\n.*$", "")
      local line = string.format("● %s  — %s", label, first)
      table.insert(lines, line)
      state.line_ids[#lines] = f.id
    end
    table.insert(lines, "")
    table.insert(lines, "d: 削除  q/<Esc>: 閉じる")
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

local function close()
  if is_open() then
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

-- カーソル行の fragment を削除する。
local function remove_under_cursor()
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  local id = state.line_ids[row]
  if id then
    queue.remove(id) -- notify 経由で render が走る
  end
end

-- floating window を開く。既に開いていれば再描画のみ。
function M.open()
  if is_open() then
    render()
    return
  end

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].filetype = "herdr-send-queue"

  local width = math.min(80, math.floor(vim.o.columns * 0.8))
  local height = math.min(20, math.floor(vim.o.lines * 0.6))
  state.win = vim.api.nvim_open_win(state.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " herdr send queue ",
    title_pos = "center",
  })

  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = state.buf, nowait = true, silent = true })
  end
  map("q", close)
  map("<Esc>", close)
  map("d", remove_under_cursor)

  render()
end

-- 変更通知を購読して、開いている間だけ再描画する。setup から 1 回だけ呼ぶ。
function M.setup_autocmd()
  local group = vim.api.nvim_create_augroup("HerdrSendQueueFloat", { clear = true })
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
