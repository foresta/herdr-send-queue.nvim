-- :HerdrSendQueue* ユーザーコマンドを定義する。多重ロードを防ぐ。
if vim.g.loaded_herdr_send_queue then
  return
end
vim.g.loaded_herdr_send_queue = true

-- 現在行/選択 + メモを queue へ積む（range 対応）。
vim.api.nvim_create_user_command("HerdrSendQueueComment", function(opts)
  local hsq = require("herdr-send-queue")
  if opts.range > 0 then
    hsq.comment(opts.line1, opts.line2)
  else
    hsq.comment()
  end
end, { range = true, desc = "レビューコメントを queue に積む" })

-- queue 一覧（floating window）。
vim.api.nvim_create_user_command("HerdrSendQueueList", function()
  require("herdr-send-queue").list()
end, { desc = "queue 一覧を開く" })

-- 一括送信して clear。! を付けると送信先を全 pane から選び直す（既定は cwd 一致 agent）。
vim.api.nvim_create_user_command("HerdrSendQueueFlush", function(opts)
  require("herdr-send-queue").flush({ force_pick = opts.bang })
end, { bang = true, desc = "queue を一括送信する（! で送信先を選択）" })

-- 一覧パネル（右 split）をトグル。
vim.api.nvim_create_user_command("HerdrSendQueuePanel", function()
  require("herdr-send-queue").panel()
end, { desc = "queue 一覧パネルをトグルする" })

-- 行インライン注釈をトグル。
vim.api.nvim_create_user_command("HerdrSendQueueAnnotate", function()
  require("herdr-send-queue").annotate()
end, { desc = "コメントの行インライン注釈をトグルする" })

-- 汎用 send: 現在行/選択を任意 pane（shell/REPL 等）へ送る。
-- ! を付けると送信先を選び直す（既定はセッション内で記憶した先へ再送）。
vim.api.nvim_create_user_command("HerdrSendText", function(opts)
  local hsq = require("herdr-send-queue")
  local l1, l2 = nil, nil
  if opts.range > 0 then
    l1, l2 = opts.line1, opts.line2
  end
  hsq.send_text(l1, l2, { force_pick = opts.bang })
end, { range = true, bang = true, desc = "選択/現在行を任意 pane へ送る" })
