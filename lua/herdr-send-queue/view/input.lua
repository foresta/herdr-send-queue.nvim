-- 複数行テキストを書くための入力用 floating window。
-- queue 一覧（view/float.lua）とは別物で、こちらは「書くための」一時 window。
-- opts.context を渡すと、入力欄の真上に別の小 float でコメント対象コードを表示する
-- （虚行 virt_lines は環境により先頭行上に描画されないため、確実な別 window 方式にする）。
local M = {}

local MAX_CONTEXT_LINES = 12

-- 対象コードを表示する（編集不可・フォーカス不可）小 float を作る。
---@param context { title?: string, lines: string[], filetype?: string }
---@param geom { width: integer, height: integer, row: integer, col: integer }
---@return integer win, integer buf
local function open_context(context, geom)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"

  local lines = {}
  local src = context.lines or {}
  local shown = math.min(#src, MAX_CONTEXT_LINES)
  for i = 1, shown do
    table.insert(lines, (src[i]:gsub("\t", "  ")))
  end
  if #src > shown then
    table.insert(lines, "… 他 " .. (#src - shown) .. " 行")
  end
  if #lines == 0 then
    lines = { "(対象行が空です)" }
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  if context.filetype and context.filetype ~= "" then
    vim.bo[buf].filetype = context.filetype -- シンタックスハイライト
  end

  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = geom.width,
    height = geom.height,
    row = geom.row,
    col = geom.col,
    style = "minimal",
    border = "rounded",
    focusable = false,
    title = " " .. (context.title or "対象") .. " ",
    title_pos = "center",
  })
  return win, buf
end

-- 入力 float を開く。
---@param opts { title?: string, initial?: string, context?: { title?: string, lines: string[], filetype?: string }, on_submit: fun(text: string), on_cancel?: fun() }
function M.open(opts)
  opts = opts or {}
  assert(type(opts.on_submit) == "function", "on_submit は必須です")

  local width = math.min(80, math.floor(vim.o.columns * 0.7))
  local edit_h = math.max(3, math.min(8, math.floor(vim.o.lines * 0.25)))

  -- context の高さ（表示行数、上限 + 省略行）
  local ctx_h = 0
  if opts.context then
    local n = #(opts.context.lines or {})
    ctx_h = math.min(n, MAX_CONTEXT_LINES) + (n > MAX_CONTEXT_LINES and 1 or 0)
    ctx_h = math.max(ctx_h, 1)
  end

  -- 2 枚（context + 入力）を縦に積んで全体を中央寄せ。border は各 window の上下 1 行ずつ。
  local col = math.floor((vim.o.columns - width) / 2)
  local total = edit_h + 2 + (opts.context and (ctx_h + 2) or 0)
  local top = math.max(1, math.floor((vim.o.lines - total) / 2))

  local ctx_win
  local input_row
  if opts.context then
    local ctx_row = top
    ctx_win = open_context(opts.context, { width = width, height = ctx_h, row = ctx_row, col = col })
    input_row = ctx_row + ctx_h + 2 -- context の下 border + 入力の上 border
  else
    input_row = top
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].filetype = "markdown" -- コメントは markdown 想定
  if opts.initial and opts.initial ~= "" then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(opts.initial, "\n", { plain = true }))
  end

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = edit_h,
    row = input_row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " " .. (opts.title or "コメント") .. " ",
    title_pos = "center",
    footer = " <C-s> 送信   q/<C-c> 取消 ",
    footer_pos = "center",
  })

  local done = false

  local function close()
    if ctx_win and vim.api.nvim_win_is_valid(ctx_win) then
      vim.api.nvim_win_close(ctx_win, true)
    end
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    -- 入力は startinsert で開くので、終了時は normal へ戻す（呼び出し元のモードに合わせる）
    if vim.fn.mode() ~= "n" then
      vim.cmd("stopinsert")
    end
  end

  local function submit()
    if done then
      return
    end
    done = true
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local text = vim.trim(table.concat(lines, "\n"))
    close()
    if text ~= "" then
      opts.on_submit(text)
    elseif opts.on_cancel then
      opts.on_cancel() -- 空は取消扱い
    end
  end

  local function cancel()
    if done then
      return
    end
    done = true
    close()
    if opts.on_cancel then
      opts.on_cancel()
    end
  end

  local function map(modes, lhs, fn)
    vim.keymap.set(modes, lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  -- <CR> は改行に使うので、送信は <C-s>（normal/insert 両方）に割り当てる
  map({ "n", "i" }, "<C-s>", submit)
  map("n", "q", cancel)
  map({ "n", "i" }, "<C-c>", cancel)

  -- window を手動で閉じた場合も取消として扱う
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = cancel,
  })

  vim.cmd("startinsert")
  return win
end

return M
