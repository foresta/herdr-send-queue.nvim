-- A list panel view. Persists in a right split and shows the queue grouped by file.
-- <CR> jumps to the file:line, d deletes. A drop-in that runs on just queue.list() + change notifications.
local queue = require("herdr-send-queue.queue")

local M = {}

local WIDTH = 42
local state = {
  win = nil,
  buf = nil,
  from_win = nil, -- the originating window used as the jump target
  line_ids = {}, -- displayed line index -> fragment id (nil for header lines)
}

local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- Group the queue by file into line text. Also build line_ids.
local function render()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  local items = queue.list()
  local lines = {}
  state.line_ids = {}

  if #items == 0 then
    lines = { "(queue is empty)", "", "<CR>: jump  d: delete  q: close" }
  else
    -- Group by relpath while preserving order
    local order, groups = {}, {}
    for _, f in ipairs(items) do
      local key = (f.location and f.location.relpath) or "(note only)"
      if not groups[key] then
        groups[key] = {}
        table.insert(order, key)
      end
      table.insert(groups[key], f)
    end

    for _, key in ipairs(order) do
      table.insert(lines, string.format("▸ %s (%d)", key, #groups[key]))
      state.line_ids[#lines] = nil -- header
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
    table.insert(lines, "<CR>: jump  d: delete  q: close")
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
end

-- Decide the jump target window (prefer a normal window other than the panel).
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

-- Open the fragment on the cursor line.
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
    -- If only the panel exists, create a split on the left
    vim.cmd("topleft vsplit")
  end
  vim.cmd("edit " .. vim.fn.fnameescape(f.location.path))
  local lnum = math.min(f.location.lnum, vim.api.nvim_buf_line_count(0))
  vim.api.nvim_win_set_cursor(0, { lnum, 0 })
end

-- Delete the fragment on the cursor line.
local function remove_under_cursor()
  local row = vim.api.nvim_win_get_cursor(state.win)[1]
  local id = state.line_ids[row]
  if id then
    queue.remove(id) -- render via the notification
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

-- Open the panel (focus it if already open).
function M.open()
  if is_open() then
    vim.api.nvim_set_current_win(state.win)
    return
  end
  state.from_win = vim.api.nvim_get_current_win()

  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].bufhidden = "hide" -- keep the buffer when closed (for toggling)
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

-- Subscribe to change notifications and redraw only while open. Call once from setup.
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
