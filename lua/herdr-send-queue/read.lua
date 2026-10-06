-- Response capture. Reads the target agent/pane's screen text and shows it in a read-only float in nvim.
-- There is no structured response, so this is a screen scrape (agent read --format text).
local herdr = require("herdr-send-queue.core.herdr")
local target = require("herdr-send-queue.core.target")
local config = require("herdr-send-queue.config")

local M = {}

-- Show the captured text in a read-only floating window.
local function show(text, title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, "\n", { plain = true }))
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = "herdr-send-queue-output"

  local width = math.min(120, math.floor(vim.o.columns * 0.85))
  local height = math.floor(vim.o.lines * 0.8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2),
    col = math.floor((vim.o.columns - width) / 2),
    style = "minimal",
    border = "rounded",
    title = " " .. (title or "agent response") .. " ",
    title_pos = "center",
    footer = " q/<Esc> close ",
    footer_pos = "center",
  })
  vim.wo[win].wrap = false
  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true, silent = true })
  vim.keymap.set("n", "<Esc>", close, { buffer = buf, nowait = true, silent = true })
  return win
end

-- Read and display the target's screen text.
-- Defaults to the cwd-matching agent. With opts.force_pick=true, pick from all panes.
---@param opts? { force_pick?: boolean }
function M.read_response(opts)
  opts = opts or {}
  local rcfg = config.get().read

  local function do_read(pane_id, err)
    if not pane_id then
      vim.notify("[herdr-send-queue] cannot resolve target: " .. (err or "unknown"), vim.log.levels.ERROR)
      return
    end
    local text, rerr = herdr.read(pane_id, { source = rcfg.source, lines = rcfg.lines })
    if not text then
      vim.notify("[herdr-send-queue] read failed: " .. (rerr or "unknown"), vim.log.levels.ERROR)
      return
    end
    if vim.trim(text) == "" then
      vim.notify("[herdr-send-queue] response was empty", vim.log.levels.INFO)
      return
    end
    show(text, pane_id)
  end

  if opts.force_pick then
    target.pick_pane(do_read)
  else
    local buf_path = vim.api.nvim_buf_get_name(0)
    local dir = (buf_path ~= nil and buf_path ~= "" and not buf_path:match("^%w+://"))
        and vim.fn.fnamemodify(buf_path, ":h")
      or nil
    target.resolve({ dir = dir }, do_read)
  end
end

return M
