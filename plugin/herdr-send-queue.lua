-- Define the :HerdrSendQueue* user commands. Guard against double loading.
if vim.g.loaded_herdr_send_queue then
  return
end
vim.g.loaded_herdr_send_queue = true

-- Add the current line/selection + note to the queue (range supported).
vim.api.nvim_create_user_command("HerdrSendQueueComment", function(opts)
  local hsq = require("herdr-send-queue")
  if opts.range > 0 then
    hsq.comment(opts.line1, opts.line2)
  else
    hsq.comment()
  end
end, { range = true, desc = "Add a review comment to the queue" })

-- Queue list (floating window).
vim.api.nvim_create_user_command("HerdrSendQueueList", function()
  require("herdr-send-queue").list()
end, { desc = "Open the queue list" })

-- Flush and clear. With ! re-pick the target from all panes (default is the cwd-matching agent).
vim.api.nvim_create_user_command("HerdrSendQueueFlush", function(opts)
  require("herdr-send-queue").flush({ force_pick = opts.bang })
end, { bang = true, desc = "Flush the queue (! to pick the target)" })

-- Toggle the list panel (right split).
vim.api.nvim_create_user_command("HerdrSendQueuePanel", function()
  require("herdr-send-queue").panel()
end, { desc = "Toggle the queue list panel" })

-- Toggle inline line annotations.
vim.api.nvim_create_user_command("HerdrSendQueueAnnotate", function()
  require("herdr-send-queue").annotate()
end, { desc = "Toggle inline line annotations for comments" })

-- Generic send: send the current line/selection to any pane (shell/REPL, etc.).
-- With ! re-pick the target (default is to resend to the one remembered within the session).
vim.api.nvim_create_user_command("HerdrSendText", function(opts)
  local hsq = require("herdr-send-queue")
  local l1, l2 = nil, nil
  if opts.range > 0 then
    l1, l2 = opts.line1, opts.line2
  end
  hsq.send_text(l1, l2, { force_pick = opts.bang })
end, { range = true, bang = true, desc = "Send the selection/current line to any pane" })

-- Response capture: read and show the target's screen text. With ! pick from all panes (default is the cwd-matching agent).
vim.api.nvim_create_user_command("HerdrRead", function(opts)
  require("herdr-send-queue").read_response({ force_pick = opts.bang })
end, { bang = true, desc = "Read and show the target agent's response (screen text)" })
