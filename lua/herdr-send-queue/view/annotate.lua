-- 行インライン注釈 view。queue 全体を見て、開いている各バッファに「そのファイル宛ての
-- コメント」だけを sign + 行末テキストで表示する。複数ファイルにまたがっても、ファイルを
-- 開くたび・queue 変更時に該当バッファを描き直すので自然に散る。
-- （先頭行上の virt_lines は描画されない環境があるため、sign + 行末 virt_text を主軸にする）
local queue = require("herdr-send-queue.queue")
local config = require("herdr-send-queue.config")

local M = {}

local ns = vim.api.nvim_create_namespace("herdr-send-queue-annotate")
local GROUP = "HerdrSendQueueAnnotate"
local enabled = false

-- 目立つ既定ハイライトを default リンクで定義する（ユーザー/テーマが上書き可能）。
-- テーマ変更に追従するため ColorScheme でも貼り直す。
local function set_highlights()
  local function hl(name, link)
    vim.api.nvim_set_hl(0, name, { link = link, default = true })
  end
  hl("HerdrSendQueueSign", "DiagnosticWarn") -- signcolumn マーカ（色付き）
  hl("HerdrSendQueueIcon", "DiagnosticVirtualTextWarn") -- 行末バッジのアイコン
  hl("HerdrSendQueueText", "DiagnosticVirtualTextWarn") -- 行末バッジの本文
  hl("HerdrSendQueueLine", "Visual") -- 該当行の背景強調
end

-- 絶対パスへ正規化する。
local function abspath(name)
  if not name or name == "" then
    return ""
  end
  return vim.fn.fnamemodify(name, ":p")
end

-- 1 バッファ分の注釈を貼り直す。
---@param buf integer
function M.refresh_buffer(buf)
  if not enabled or not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local name = abspath(vim.api.nvim_buf_get_name(buf))
  if name == "" then
    return
  end
  local line_count = vim.api.nvim_buf_line_count(buf)

  for _, f in ipairs(queue.list()) do
    local loc = f.location
    if loc and loc.path and abspath(loc.path) == name then
      local row = loc.lnum - 1
      if row >= 0 and row < line_count then
        local acfg = config.get().annotate
        local summary = (f.text or ""):gsub("\n.*$", "")
        if (f.text or ""):find("\n") then
          summary = summary .. " …"
        end
        vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
          sign_text = acfg.sign_text,
          sign_hl_group = "HerdrSendQueueSign",
          -- 色付きのバッジ風ラベル（アイコン + 本文を背景付きで）
          virt_text = {
            { acfg.icon, "HerdrSendQueueIcon" },
            { summary .. " ", "HerdrSendQueueText" },
          },
          virt_text_pos = "eol",
          line_hl_group = acfg.line_highlight and "HerdrSendQueueLine" or nil,
          -- 範囲コメントは開始行〜終了行に薄いマーカを付けたいが、MVP は開始行のみ
        })
      end
    end
  end
end

-- 読み込み済みの全バッファを描き直す。
function M.refresh_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) then
      M.refresh_buffer(buf)
    end
  end
end

-- 全バッファの注釈を消す。
local function clear_all()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end
  end
end

-- 注釈表示を有効化する。
function M.enable()
  if enabled then
    return
  end
  enabled = true
  set_highlights()
  local group = vim.api.nvim_create_augroup(GROUP, { clear = true })
  -- テーマ変更に追従してハイライトを貼り直す
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = group,
    callback = set_highlights,
  })
  -- ファイルを開いた/表示したら、そのバッファに注釈を貼る（複数ファイル対応の要）
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufReadPost" }, {
    group = group,
    callback = function(args)
      M.refresh_buffer(args.buf)
    end,
  })
  -- queue が変わったら全バッファ再描画
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "HerdrSendQueueChanged",
    callback = function()
      M.refresh_all()
    end,
  })
  M.refresh_all()
end

-- 注釈表示を無効化する。
function M.disable()
  if not enabled then
    return
  end
  enabled = false
  pcall(vim.api.nvim_clear_autocmds, { group = GROUP })
  clear_all()
end

function M.toggle()
  if enabled then
    M.disable()
  else
    M.enable()
  end
end

function M.is_enabled()
  return enabled
end

return M
