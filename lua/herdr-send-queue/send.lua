-- 汎用 send preset。選択/現在行を「任意の pane」（shell / REPL / 別 agent 等）へ送る。
-- 汎用コア（core/herdr）をそのまま流用し、レビュー用の format/location には依存しない。
-- 送信先は herdr pane list から picker で選び、セッション内で記憶して再送を楽にする。
local herdr = require("herdr-send-queue.core.herdr")
local target = require("herdr-send-queue.core.target")
local config = require("herdr-send-queue.config")

local M = {}

-- セッション内で記憶する直近の送信先 pane_id
local last_target = nil

-- 送信先を解決する。
-- remember_target=true かつ force_pick=false で記憶があればそれを再利用、
-- それ以外（remember_target=false / force_pick / 記憶なし）は picker を出す。
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

-- 行範囲のテキストを送信先 pane へ送る。
---@param line1 integer
---@param line2 integer
---@param opts? { submit?: boolean, force_pick?: boolean }
function M.send_lines(line1, line2, opts)
  opts = opts or {}
  local lines = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
  local text = table.concat(lines, "\n")
  if vim.trim(text) == "" then
    vim.notify("[herdr-send-queue] 送信するテキストがありません", vim.log.levels.WARN)
    return
  end

  local submit = opts.submit
  if submit == nil then
    submit = config.get().send_text.submit
  end

  resolve(opts.force_pick and true or false, function(pid, err)
    if not pid then
      vim.notify("[herdr-send-queue] 送信先を解決できません: " .. (err or "不明"), vim.log.levels.ERROR)
      return
    end
    local _, serr = herdr.send(pid, text, { submit = submit })
    if serr then
      vim.notify("[herdr-send-queue] 送信に失敗しました: " .. serr, vim.log.levels.ERROR)
      return
    end
    vim.notify(string.format("[herdr-send-queue] %d 行を %s へ送信しました", line2 - line1 + 1, pid), vim.log.levels.INFO)
  end)
end

-- 記憶している送信先を忘れる（次回 picker を出す）。
function M.clear_target()
  last_target = nil
end

-- 記憶中の送信先。
function M.target()
  return last_target
end

return M
