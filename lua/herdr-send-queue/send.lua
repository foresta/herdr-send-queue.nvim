-- Generic send preset. Sends the selection/current line to "any pane" (shell / REPL / another agent, etc.).
-- It reuses the generic core (core/herdr) as-is and does not depend on the review format/location.
-- The target is chosen from herdr pane list via a picker and remembered within the session to make resending easy.
local herdr = require("herdr-send-queue.core.herdr")
local target = require("herdr-send-queue.core.target")
local config = require("herdr-send-queue.config")

local M = {}

-- The most recent target pane_id, remembered within the session.
local last_target = nil

-- Resolve the target.
-- When remember_target=true and force_pick=false and a target is remembered, reuse it;
-- otherwise (remember_target=false / force_pick / nothing remembered) show the picker.
---@param force_pick boolean
---@param cb fun(pane_id: string|nil, err: string|nil)
local function resolve(force_pick, cb)
  local remember = config.get().send_text.remember_target
  if remember and not force_pick and last_target then
    return cb(last_target, nil)
  end
  target.pick_pane(function(pid, err)
    if pid then
      last_target = pid
    end
    cb(pid, err)
  end)
end

-- Send the text of a line range to the target pane.
---@param line1 integer
---@param line2 integer
---@param opts? { submit?: boolean, force_pick?: boolean }
function M.send_lines(line1, line2, opts)
  opts = opts or {}
  local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  local text = table.concat(lines, "\n")
  if vim.trim(text) == "" then
    vim.notify("[herdr-send-queue] no text to send", vim.log.levels.WARN)
    return
  end

  local submit = opts.submit
  if submit == nil then
    submit = config.get().send_text.submit
  end

  resolve(opts.force_pick and true or false, function(pid, err)
    if not pid then
      vim.notify("[herdr-send-queue] cannot resolve target: " .. (err or "unknown"), vim.log.levels.ERROR)
      return
    end
    local _, serr = herdr.send(pid, text, { submit = submit })
    if serr then
      vim.notify("[herdr-send-queue] send failed: " .. serr, vim.log.levels.ERROR)
      return
    end
    vim.notify(string.format("[herdr-send-queue] sent %d line(s) to %s", line2 - line1 + 1, pid), vim.log.levels.INFO)
  end)
end

-- Forget the remembered target (the next call shows the picker).
function M.clear_target()
  last_target = nil
end

-- The currently remembered target.
function M.target()
  return last_target
end

return M
