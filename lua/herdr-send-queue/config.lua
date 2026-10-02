-- 設定の既定値を集約するモジュール。他モジュールは config.get() を参照する。
local M = {}

M.defaults = {
  -- false にすると setup() は keymap を配線しない（ユーザーが自前で張る）
  set_keymaps = true,
  keymaps = {
    comment = "<leader>ac", -- 現在行/選択 + メモを queue へ
    list = "<leader>al", -- queue 一覧
    flush = "<leader>aS", -- 一括送信して clear
  },
  herdr = {
    cmd = "herdr", -- 実行バイナリ名（PATH 上）
  },
  target = {
    -- cwd→agent 解決は core/target.lua が git root と agent の cwd を突き合わせる。
    -- 一致が cwd と foreground_cwd のどちらでも良いか
    match_foreground_cwd = true,
  },
  format = {
    -- ファイル参照形式を決める agent 種別。"claude" は @relpath#L.. 、"plain" は relpath:lnum。
    agent_type = "claude",
    header = "以下のレビューコメントに対応してください。",
  },
  send = {
    submit = true, -- flush 時に Enter まで送るか（false なら未送信ステージ）
  },
}

local options = nil

-- ユーザー opts を既定へ deep merge して保持する。
function M.setup(opts)
  options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return options
end

-- 現在の設定を返す。setup() 前でも既定で動くようにする。
function M.get()
  if not options then
    options = vim.deepcopy(M.defaults)
  end
  return options
end

return M
