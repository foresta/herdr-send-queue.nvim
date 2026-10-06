-- 設定の既定値を集約するモジュール。他モジュールは config.get() を参照する。
local M = {}

M.defaults = {
  -- false にすると setup() は keymap を配線しない（ユーザーが自前で張る）
  set_keymaps = true,
  keymaps = {
    comment = "<leader>ac", -- 現在行/選択 + メモを queue へ
    list = "<leader>al", -- queue 一覧（view.list の表示先）
    flush = "<leader>aS", -- 一括送信して clear
    panel = "<leader>ap", -- 一覧パネルのトグル
    annotate = "<leader>at", -- 行インライン注釈のトグル
  },
  view = {
    -- list キーマップ/コマンドの表示先。"float"=中央 floating、"panel"=右 split
    list = "float",
    -- setup() 時に行インライン注釈を自動で ON にするか
    annotate = true,
  },
  annotate = {
    sign_text = "▌", -- signcolumn のマーカ（最大 2 セル）
    icon = " 💬 ", -- 行末バッジの先頭アイコン
    line_highlight = true, -- 該当行の背景を強調するか
    -- ハイライトは HerdrSendQueue{Sign,Icon,Text,Line} を default リンクで定義。
    -- 色を変えたいときは setup 後に vim.api.nvim_set_hl で上書きする。
  },
  herdr = {
    cmd = "herdr", -- 実行バイナリ名（PATH 上）
  },
  target = {
    -- cwd→agent 解決は core/target.lua が git root と agent の cwd を突き合わせる。
    -- 一致が cwd と foreground_cwd のどちらでも良いか
    match_foreground_cwd = true,
  },
  review = {
    -- コメント入力の方式。"float"=複数行フローティング入力、"prompt"=1行の vim.ui.input。
    input = "float",
  },
  format = {
    -- ファイル参照形式を決める agent 種別。"claude" は @relpath#L.. 、"plain" は relpath:lnum。
    agent_type = "claude",
    header = "以下のレビューコメントに対応してください。",
  },
  send = {
    submit = true, -- flush 時に Enter まで送るか（false なら未送信ステージ）
  },
  send_text = {
    -- 汎用 send preset（:HerdrSendText）で Enter まで送るか。REPL は実行したいので既定 true。
    submit = true,
    -- 送信先を記憶して再送するか。既定 false＝毎回 picker を出す（誤爆防止）。
    -- true にするとセッション内で記憶し、:HerdrSendText! で選び直す運用になる。
    remember_target = false,
  },
  persist = {
    -- queue をセッション跨ぎで保存/復元するか（既定 OFF）
    enabled = false,
    -- nil なら stdpath("state")/herdr-send-queue/queue.json
    path = nil,
  },
  read = {
    -- 返答取り込み（:HerdrRead）の agent read ソース: visible / recent / recent-unwrapped / detection
    source = "recent",
    -- 読み取る行数（nil なら herdr 既定）
    lines = nil,
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
