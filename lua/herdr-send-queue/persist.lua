-- queue の永続化（任意）。セッション跨ぎで queue を保存/復元する。
-- 既定 OFF（MVP は非永続）。config.persist.enabled=true で有効化する。
-- 有効時は setup で load し、以後 User HerdrSendQueueChanged のたびに save する。
local queue = require("herdr-send-queue.queue")

local M = {}

local state = {
  enabled = false,
  path = nil,
  suspend = false, -- load 中の save ループ抑止
}

-- 保存先パス（nil なら stdpath("state")/herdr-send-queue/queue.json）。
function M.path()
  return state.path
end

local function ensure_dir(p)
  pcall(vim.fn.mkdir, vim.fn.fnamemodify(p, ":h"), "p")
end

-- 現在の queue を JSON で保存する。
function M.save()
  if not state.enabled or not state.path then
    return
  end
  local ok, json = pcall(vim.json.encode, queue.list())
  if not ok then
    return
  end
  ensure_dir(state.path)
  pcall(vim.fn.writefile, { json }, state.path)
end

-- 保存ファイルから queue を復元する。
function M.load()
  if not state.path or vim.fn.filereadable(state.path) == 0 then
    return
  end
  local ok_r, lines = pcall(vim.fn.readfile, state.path)
  if not ok_r or type(lines) ~= "table" or #lines == 0 then
    return
  end
  local ok, data = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok or type(data) ~= "table" then
    return
  end
  state.suspend = true
  queue.clear()
  for _, f in ipairs(data) do
    -- id はセッション内のみ有効なので捨て、add で採番し直す
    queue.add({ text = f.text, location = f.location, meta = f.meta })
  end
  state.suspend = false
end

-- 永続化を設定する。enabled=false なら何もしない。
---@param opts? { enabled?: boolean, path?: string }
function M.setup(opts)
  opts = opts or {}
  state.enabled = opts.enabled and true or false
  state.path = opts.path or (vim.fn.stdpath("state") .. "/herdr-send-queue/queue.json")
  if not state.enabled then
    return
  end
  M.load()
  local group = vim.api.nvim_create_augroup("HerdrSendQueuePersist", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "HerdrSendQueueChanged",
    callback = function()
      if not state.suspend then
        M.save()
      end
    end,
  })
end

function M.is_enabled()
  return state.enabled
end

return M
