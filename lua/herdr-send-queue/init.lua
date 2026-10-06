-- エントリポイント。setup() で config マージ・keymap 配線を行い、
-- comment / list / flush の 3 操作を公開する。
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

-- 現在行/選択 + メモを queue へ積む。
function M.comment(line1, line2)
  comments.add_comment(line1, line2)
end

-- queue 一覧を開く（config.view.list で float/panel 切替）。
function M.list()
  if config.get().view.list == "panel" then
    panel.open()
  else
    float.open()
  end
end

-- 一覧パネル（右 split）をトグルする。
function M.panel()
  panel.toggle()
end

-- 行インライン注釈をトグルする。
function M.annotate()
  annotate.toggle()
end

-- 汎用 send: 現在行/選択を任意 pane（shell/REPL 等）へ送る。
-- line1/line2 省略時は現在行。opts.force_pick=true で送信先を選び直す。
function M.send_text(line1, line2, opts)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  line1 = line1 or cur
  line2 = line2 or line1
  if line2 < line1 then
    line1, line2 = line2, line1
  end
  send.send_lines(line1, line2, opts)
end

-- 返答取り込み: 送信先 agent/pane の画面テキストを read-only float で表示。
-- opts.force_pick=true で全 pane から選ぶ。
function M.read_response(opts)
  read.read_response(opts)
end

-- queue を 1 プロンプトに束ねて送信先へ一括送信し、成功で clear する。
-- 既定は cwd 一致 agent へ自動解決。opts.force_pick=true で全 pane から選び直す。
-- 流れ: 解決 → format → send({submit}) → queue.clear()。
---@param opts? { force_pick?: boolean }
function M.flush(opts)
  opts = opts or {}
  local items = queue.list()
  if #items == 0 then
    vim.notify("[herdr-send-queue] queue が空です", vim.log.levels.INFO)
    return
  end

  local text = format.format(items)
  local submit = config.get().send.submit

  local function do_send(pane_id, err)
    if not pane_id then
      vim.notify("[herdr-send-queue] 送信先を解決できません: " .. (err or "不明"), vim.log.levels.ERROR)
      return
    end
    local _, send_err = herdr.send(pane_id, text, { submit = submit })
    if send_err then
      -- 失敗時はキューを保持する（再送できるように）。
      vim.notify("[herdr-send-queue] 送信に失敗しました: " .. send_err, vim.log.levels.ERROR)
      return
    end
    queue.clear()
    vim.notify(string.format("[herdr-send-queue] %d 件を %s へ送信しました", #items, pane_id), vim.log.levels.INFO)
  end

  if opts.force_pick then
    -- 全 pane から明示選択（send preset と共通の picker）
    target.pick_pane(do_send)
  else
    -- 現在バッファの git root から cwd 一致 agent を自動解決（曖昧なら picker）
    local buf_path = vim.api.nvim_buf_get_name(0)
    local dir = (buf_path ~= nil and buf_path ~= "" and not buf_path:match("^%w+://"))
        and vim.fn.fnamemodify(buf_path, ":h")
      or nil
    target.resolve({ dir = dir }, do_send)
  end
end

-- keymap を配線する。
local function set_keymaps(km)
  if km.comment then
    vim.keymap.set("n", km.comment, function()
      M.comment()
    end, { silent = true, desc = "herdr-send-queue: 現在行をコメント" })
    vim.keymap.set("x", km.comment, function()
      -- 先に visual を抜けて '<,'> マークを確定させる（v/V/<C-v> いずれの選択でも範囲が取れる）
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
      M.comment(vim.fn.line("'<"), vim.fn.line("'>"))
    end, { silent = true, desc = "herdr-send-queue: 選択をコメント" })
  end
  if km.list then
    vim.keymap.set("n", km.list, M.list, { silent = true, desc = "herdr-send-queue: queue 一覧" })
  end
  if km.flush then
    vim.keymap.set("n", km.flush, M.flush, { silent = true, desc = "herdr-send-queue: 一括送信" })
  end
  if km.panel then
    vim.keymap.set("n", km.panel, M.panel, { silent = true, desc = "herdr-send-queue: 一覧パネル" })
  end
  if km.annotate then
    vim.keymap.set("n", km.annotate, M.annotate, { silent = true, desc = "herdr-send-queue: 行注釈トグル" })
  end
  if km.send_text then
    vim.keymap.set("n", km.send_text, function()
      M.send_text()
    end, { silent = true, desc = "herdr-send-queue: 現在行を pane へ送信" })
    vim.keymap.set("x", km.send_text, function()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "nx", false)
      M.send_text(vim.fn.line("'<"), vim.fn.line("'>"))
    end, { silent = true, desc = "herdr-send-queue: 選択を pane へ送信" })
  end
end

-- プラグインを有効化する。
function M.setup(opts)
  local cfg = config.setup(opts)
  float.setup_autocmd()
  panel.setup_autocmd()
  persist.setup(cfg.persist) -- enabled=true のときだけ load + 自動 save
  if cfg.set_keymaps then
    set_keymaps(cfg.keymaps)
  end
  if cfg.view.annotate then
    annotate.enable() -- 行インライン注釈を既定で ON（view.annotate=false で無効化）
  end
  return M
end

return M
