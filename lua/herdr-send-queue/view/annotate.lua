-- Inline annotation view. Scans the whole queue and shows, in each open buffer,
-- only the comments addressed to that file as a sign + end-of-line text. Even
-- across multiple files it spreads naturally, because each buffer is redrawn
-- whenever the file is opened and whenever the queue changes.
-- (virt_lines above the first line are not rendered in some environments, so the
-- sign + end-of-line virt_text is the primary mechanism.)
local queue = require("herdr-send-queue.queue")
local config = require("herdr-send-queue.config")

local M = {}

local ns = vim.api.nvim_create_namespace("herdr-send-queue-annotate")
local GROUP = "HerdrSendQueueAnnotate"
local enabled = false

-- Define prominent default highlights via `default` links (user/theme can override).
-- Re-apply on ColorScheme so they follow theme changes.
local function set_highlights()
  local function hl(name, link)
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
  hl("HerdrSendQueueSign", "DiagnosticWarn") -- signcolumn marker (colored)
  hl("HerdrSendQueueIcon", "DiagnosticVirtualTextWarn") -- end-of-line badge icon
  hl("HerdrSendQueueText", "DiagnosticVirtualTextWarn") -- end-of-line badge text
  hl("HerdrSendQueueLine", "Visual") -- line highlight for the target line
end

-- Normalize to an absolute path.
local function abspath(name)
  if not name or name == "" then
    return ""
  end
  return vim.fn.fnamemodify(name, ":p")
end

-- Re-apply the annotations for a single buffer.
---@param buf integer
function M.refresh_buffer(buf)
  if not enabled or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local name = abspath(vim.api.nvim_buf_get_name(buf))
  if name == "" then
    return
  end
  local line_count = vim.api.nvim_buf_line_count(buf)

  for _, f in ipairs(queue.list()) do
    local loc = f.location
    if loc and loc.path and abspath(loc.path) == name then
      local row = loc.lnum - 1
      if row >= 0 and row < line_count then
        local acfg = config.get().annotate
        local summary = (f.text or ""):gsub("\n.*$", "")
        if (f.text or ""):find("\n") then
          summary = summary .. " …"
        end
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
          sign_text = acfg.sign_text,
          sign_hl_group = "HerdrSendQueueSign",
          -- Colored badge-style label (icon + text with a background)
          virt_text = {
            { acfg.icon, "HerdrSendQueueIcon" },
            { summary .. " ", "HerdrSendQueueText" },
          },
          virt_text_pos = "eol",
          line_hl_group = acfg.line_highlight and "HerdrSendQueueLine" or nil,
          -- A range comment should get a faint marker from start line to end line, but for now only the start line
        })
      end
    end
  end
end

-- Redraw all loaded buffers.
function M.refresh_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      M.refresh_buffer(buf)
    end
  end
end

-- Clear the annotations in all buffers.
local function clear_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end
end

-- Enable the annotation display.
function M.enable()
  if enabled then
    return
  end
  enabled = true
  set_highlights()
  local group = vim.api.nvim_create_augroup(GROUP, { clear = true })
  -- Re-apply highlights to follow theme changes
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = set_highlights,
  })
  -- When a file is opened/displayed, annotate that buffer (key to multi-file support)
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufReadPost" }, {
    group = group,
    callback = function(args)
      M.refresh_buffer(args.buf)
    end,
  })
  -- Redraw all buffers when the queue changes
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "HerdrSendQueueChanged",
    callback = function()
      M.refresh_all()
    end,
  })
  M.refresh_all()
end

-- Disable the annotation display.
function M.disable()
  if not enabled then
    return
  end
  enabled = false
  pcall(vim.api.nvim_clear_autocmds, { group = GROUP })
  clear_all()
end

function M.toggle()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.is_enabled()
  return enabled
end

return M
