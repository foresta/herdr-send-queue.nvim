-- A simple list view. Shows the queue in a floating window and redraws on User HerdrSendQueueChanged.
-- It only reads queue.list(), so a future custom view can be swapped in under the same contract.
local queue = require("herdr-send-queue.queue")

local M = {}

local state = {
  win = nil,
  buf = nil,
  -- displayed line index -> fragment id
  line_ids = {},
}

local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- Render the queue into line text and build the line -> id mapping.
local function render()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  local items = queue.list()
  local lines = {}
  state.line_ids = {}

  if #items == 0 then
    lines = { "(queue is empty)", "", "d: delete  q/<Esc>: close" }
  else
    for _, f in ipairs(items) do
      local label = "(note only)"
      if f.location then
        local loc = f.location
        label = loc.relpath .. ":" .. tostring(loc.lnum)
        if loc.end_lnum and loc.end_lnum ~= loc.lnum then
          label = label .. "-" .. tostring(loc.end_lnum)
        end
      end
      -- Summarize the note by showing only its first line
      local first = (f.text or ""):gsub("\n.*$", "")
      local line = string.format("● %s  — %s", label, first)
      table.insert(lines, line)
      state.line_ids[#lines] = f.id
    end
    table.insert(lines, "")
    table.insert(lines, "d: delete  q/<Esc>: close")
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

-- Delete the fragment on the cursor line.
local function remove_under_cursor()
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  local id = state.line_ids[row]
  if id then
    queue.remove(id) -- render runs via the notification
  end
end

-- Open the floating window. If already open, only redraw.
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

-- Subscribe to change notifications and redraw only while open. Call once from setup.
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
