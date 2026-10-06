-- An input floating window for writing multi-line text.
-- Distinct from the queue list (view/float.lua); this is a transient window "for writing".
-- When opts.context is given, the target code is shown in a separate small float directly
-- above the input field (virtual lines above the first line are not rendered in some
-- environments, so a reliable separate-window approach is used instead).
local M = {}

local MAX_CONTEXT_LINES = 12

-- Create a small float (read-only, non-focusable) that shows the target code.
---@param context { title?: string, lines: string[], filetype?: string }
---@param geom { width: integer, height: integer, row: integer, col: integer }
---@return integer win, integer buf
local function open_context(context, geom)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"

  local lines = {}
  local src = context.lines or {}
  local shown = math.min(#src, MAX_CONTEXT_LINES)
  for i = 1, shown do
    table.insert(lines, (src[i]:gsub("\t", "  ")))
  end
  if #src > shown then
    table.insert(lines, "… " .. (#src - shown) .. " more lines")
  end
  if #lines == 0 then
    lines = { "(target lines are empty)" }
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  if context.filetype and context.filetype ~= "" then
    vim.bo[buf].filetype = context.filetype -- syntax highlighting
  end

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = geom.width,
    height = geom.height,
    row = geom.row,
    col = geom.col,
    style = "minimal",
    border = "rounded",
    focusable = false,
    title = " " .. (context.title or "target") .. " ",
    title_pos = "center",
  })
  return win, buf
end

-- Open the input float.
---@param opts { title?: string, initial?: string, context?: { title?: string, lines: string[], filetype?: string }, on_submit: fun(text: string), on_cancel?: fun() }
function M.open(opts)
  opts = opts or {}
  assert(type(opts.on_submit) == "function", "on_submit is required")

  local width = math.min(80, math.floor(vim.o.columns * 0.7))
  local edit_h = math.max(3, math.min(8, math.floor(vim.o.lines * 0.25)))

  -- Height of the context (number of displayed lines, capped + overflow line)
  local ctx_h = 0
  if opts.context then
    local n = #(opts.context.lines or {})
    ctx_h = math.min(n, MAX_CONTEXT_LINES) + (n > MAX_CONTEXT_LINES and 1 or 0)
    ctx_h = math.max(ctx_h, 1)
  end

  -- Stack the two (context + input) vertically and center the whole thing. The border takes one row above and below each window.
  local col = math.floor((vim.o.columns - width) / 2)
  local total = edit_h + 2 + (opts.context and (ctx_h + 2) or 0)
  local top = math.max(1, math.floor((vim.o.lines - total) / 2))

  local ctx_win
  local input_row
  if opts.context then
    local ctx_row = top
    ctx_win = open_context(opts.context, { width = width, height = ctx_h, row = ctx_row, col = col })
    input_row = ctx_row + ctx_h + 2 -- context's bottom border + input's top border
  else
    input_row = top
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown" -- comments are assumed to be markdown
  if opts.initial and opts.initial ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(opts.initial, "\n", { plain = true }))
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = edit_h,
    row = input_row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. (opts.title or "comment") .. " ",
    title_pos = "center",
    footer = " <C-s> send   q/<C-c> cancel ",
    footer_pos = "center",
  })

  local done = false

  local function close()
    if ctx_win and vim.api.nvim_win_is_valid(ctx_win) then
      vim.api.nvim_win_close(ctx_win, true)
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    -- The input opens with startinsert, so return to normal mode on close (match the caller's mode)
    if vim.fn.mode() ~= "n" then
      vim.cmd("stopinsert")
    end
  end

  local function submit()
    if done then
      return
    end
    done = true
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = vim.trim(table.concat(lines, "\n"))
    close()
    if text ~= "" then
      opts.on_submit(text)
    elseif opts.on_cancel then
      opts.on_cancel() -- empty is treated as cancel
    end
  end

  local function cancel()
    if done then
      return
    end
    done = true
    close()
    if opts.on_cancel then
      opts.on_cancel()
    end
  end

  local function map(modes, lhs, fn)
    vim.keymap.set(modes, lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  -- <CR> is used for newlines, so submit is mapped to <C-s> (both normal and insert)
  map({ "n", "i" }, "<C-s>", submit)
  map("n", "q", cancel)
  map({ "n", "i" }, "<C-c>", cancel)

  -- Also treat a manually closed window as a cancel
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = cancel,
  })

  vim.cmd("startinsert")
  return win
end

return M
