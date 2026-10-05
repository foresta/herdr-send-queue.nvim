-- 汎用ステージング。id つき fragment の順序つき配列を in-memory で保持するだけ。
-- agent にもコメントにも依存しない（レビュー以外の preset も同じ土台に載せられる）。
--
---@class Location
---@field path     string   -- 絶対パス
---@field relpath  string   -- repo 相対（@path#L.. 用）
---@field lnum     integer  -- 1-based 開始行
---@field end_lnum integer  -- 終了行（含む）
---@field branch?  string
---@field rev?     string   -- short sha
--
---@class Fragment
---@field id       string    -- 安定 id（編集/削除用）
---@field text     string    -- ユーザーが書いた中身（メモ/コード）
---@field location? Location
---@field meta?    table     -- 自由（kind="review" 等）

local M = {}

---@type Fragment[]
local items = {}
local seq = 0

-- 変更を view へ知らせる。view は queue.list() を読むだけで再描画できる（疎結合）。
local function notify()
  vim.api.nvim_exec_autocmds("User", { pattern = "HerdrSendQueueChanged" })
end

-- fragment を末尾に積む。id を採番して返す。
---@param fragment Fragment
---@return string id
function M.add(fragment)
  seq = seq + 1
  fragment.id = tostring(seq)
  table.insert(items, fragment)
  notify()
  return fragment.id
end

-- 現在のキュー（コピー）を順序どおり返す。
---@return Fragment[]
function M.list()
  return vim.deepcopy(items)
end

-- id で 1 件取得する。
---@param id string
---@return Fragment?
function M.get(id)
  for _, f in ipairs(items) do
    if f.id == id then
      return vim.deepcopy(f)
    end
  end
  return nil
end

-- id で 1 件削除する。消したら true。
---@param id string
---@return boolean removed
function M.remove(id)
  for i, f in ipairs(items) do
    if f.id == id then
      table.remove(items, i)
      notify()
      return true
    end
  end
  return false
end

-- 全消去。
function M.clear()
  if #items == 0 then
    return
  end
  items = {}
  notify()
end

-- 件数。
---@return integer
function M.count()
  return #items
end

return M
