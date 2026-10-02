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

-- 一括送信して clear。
vim.api.nvim_create_user_command("HerdrSendQueueFlush", function()
  require("herdr-send-queue").flush()
end, { desc = "queue を一括送信する" })
