-- Entry point. setup() merges config and wires keymaps, and exposes the
-- three operations: comment / list / flush.
local config = require("herdr-send-queue.config")
local queue = require("herdr-send-queue.queue")
local comments = require("herdr-send-queue.review.comments")
local format = require("herdr-send-queue.review.format")
local target = require("herdr-send-queue.core.target")
local herdr = require("herdr-send-queue.core.herdr")
local float = require("herdr-send-queue.view.float")
local panel = require("herdr-send-queue.view.panel")
local annotate = require("herdr-send-queue.view.annotate")
local persist = require("herdr-send-queue.persist")
local send = require("herdr-send-queue.send")
local read = require("herdr-send-queue.read")

local M = {}

-- Add the current line/selection + note to the queue.
function M.comment(line1, line2)
  comments.add_comment(line1, line2)
end

-- Open the queue list (float/panel switched by config.view.list).
function M.list()
  if config.get().view.list == "panel" then
    panel.open()
  else
    float.open()
  end
end

-- Toggle the list panel (right split).
function M.panel()
  panel.toggle()
end

-- Toggle inline line annotations.
function M.annotate()
  annotate.toggle()
end

-- Generic send: send the current line/selection to any pane (shell/REPL, etc.).
-- When line1/line2 are omitted, uses the current line. opts.force_pick=true re-picks the target.
function M.send_text(line1, line2, opts)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  line1 = line1 or cur
  line2 = line2 or line1
  if line2 < line1 then
    line1, line2 = line2, line1
  end
  send.send_lines(line1, line2, opts)
end

-- Response capture: show the screen text of the target agent/pane in a read-only float.
-- opts.force_pick=true picks from all panes.
function M.read_response(opts)
  read.read_response(opts)
end

-- Bundle the queue into one prompt, flush it to the target, and clear on success.
-- By default resolves automatically to the cwd-matching agent. opts.force_pick=true re-picks from all panes.
-- Flow: resolve -> format -> send({submit}) -> queue.clear().
---@param opts? { force_pick?: boolean }
function M.flush(opts)
  opts = opts or {}
  local items = queue.list()
  if #items == 0 then
    vim.notify("[herdr-send-queue] queue is empty", vim.log.levels.INFO)
    return
  end

  local text = format.format(items)
  local submit = config.get().send.submit

  local function do_send(pane_id, err)
    if not pane_id then
      vim.notify("[herdr-send-queue] could not resolve target: " .. (err or "unknown"), vim.log.levels.ERROR)
      return
    end
    local _, send_err = herdr.send(pane_id, text, { submit = submit })
    if send_err then
      -- Keep the queue on failure (so it can be resent).
      vim.notify("[herdr-send-queue] send failed: " .. send_err, vim.log.levels.ERROR)
      return
    end
    queue.clear()
    vim.notify(string.format("[herdr-send-queue] sent %d item(s) to %s", #items, pane_id), vim.log.levels.INFO)
  end

  if opts.force_pick then
    -- Explicit pick from all panes (shared picker with the send preset).
    target.pick_pane(do_send)
  else
    -- Resolve the cwd-matching agent from the current buffer's git root (picker if ambiguous).
    local buf_path = vim.api.nvim_buf_get_name(0)
    local dir = (buf_path ~= nil and buf_path ~= "" and not buf_path:match("^%w+://"))
        and vim.fn.fnamemodify(buf_path, ":h")
      or nil
    target.resolve({ dir = dir }, do_send)
  end
end

-- Wire up keymaps.
local function set_keymaps(km)
  if km.comment then
    vim.keymap.set("n", km.comment, function()
      M.comment()
    end, { silent = true, desc = "herdr-send-queue: comment current line" })
    vim.keymap.set("x", km.comment, function()
      -- Leave visual mode first so the '<,'> marks are set (works for v/V/<C-v> selections).
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
      M.comment(vim.fn.line("'<"), vim.fn.line("'>"))
    end, { silent = true, desc = "herdr-send-queue: comment selection" })
  end
  if km.list then
    vim.keymap.set("n", km.list, M.list, { silent = true, desc = "herdr-send-queue: queue list" })
  end
  if km.flush then
    vim.keymap.set("n", km.flush, M.flush, { silent = true, desc = "herdr-send-queue: flush" })
  end
  if km.panel then
    vim.keymap.set("n", km.panel, M.panel, { silent = true, desc = "herdr-send-queue: list panel" })
  end
  if km.annotate then
    vim.keymap.set("n", km.annotate, M.annotate, { silent = true, desc = "herdr-send-queue: toggle line annotations" })
  end
  if km.send_text then
    vim.keymap.set("n", km.send_text, function()
      M.send_text()
    end, { silent = true, desc = "herdr-send-queue: send current line to pane" })
    vim.keymap.set("x", km.send_text, function()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
      M.send_text(vim.fn.line("'<"), vim.fn.line("'>"))
    end, { silent = true, desc = "herdr-send-queue: send selection to pane" })
  end
end

-- Enable the plugin.
function M.setup(opts)
  local cfg = config.setup(opts)
  float.setup_autocmd()
  panel.setup_autocmd()
  persist.setup(cfg.persist) -- load + auto-save only when enabled=true
  if cfg.set_keymaps then
    set_keymaps(cfg.keymaps)
  end
  if cfg.view.annotate then
    annotate.enable() -- inline line annotations ON by default (disable with view.annotate=false)
  end
  return M
end

return M
