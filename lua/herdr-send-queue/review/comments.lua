-- レビューコメント preset。現在行/選択を location 化し、メモとともに queue へ積む。
local queue = require("herdr-send-queue.queue")
local target = require("herdr-send-queue.core.target")
local config = require("herdr-send-queue.config")
local input = require("herdr-send-queue.view.input")

local M = {}

-- git の short sha（取れなければ nil）。
local function git_rev(dir)
  local res = vim.system({ "git", "-C", dir, "rev-parse", "--short", "HEAD" }, { text = true }):wait()
  if res.code ~= 0 then
    return nil
  end
  local rev = vim.trim(res.stdout or "")
  return rev ~= "" and rev or nil
end

-- 現在の branch 名（detached 等で取れなければ nil）。
local function git_branch(dir)
  local res = vim.system({ "git", "-C", dir, "rev-parse", "--abbrev-ref", "HEAD" }, { text = true }):wait()
  if res.code ~= 0 then
    return nil
  end
  local b = vim.trim(res.stdout or "")
  if b == "" or b == "HEAD" then
    return nil
  end
  return b
end

-- 現在バッファと行範囲から Location を構築する。
-- MVP は作業ツリーのファイルバッファ（fugitive diff の右側含む）が対象。
---@param line1 integer
---@param line2 integer
---@return Location? location, string? err
local function build_location(line1, line2)
  local path = vim.api.nvim_buf_get_name(0)
  if path == nil or path == "" then
    return nil, "名前付きファイルのバッファではありません"
  end
  -- 疑似バッファ（fugitive:// 等）は実パスへ解決する。
  -- fugitive の diff/blob バッファは FugitiveReal() で作業ツリーの実ファイルパスが取れる。
  -- 行番号は現在行をそのまま使う（diff 右側＝作業ツリーならそのまま対応する）。
  if path:match("^%w+://") then
    local scheme = path:match("^(%w+)://")
    if path:match("^fugitive://") and vim.fn.exists("*FugitiveReal") == 1 then
      local real = vim.fn.FugitiveReal(path)
      if real and real ~= "" and not real:match("^%w+://") then
        path = real
      else
        return nil, "fugitive バッファの実パスを解決できませんでした（status 行など）"
      end
    else
      return nil, "このバッファ種別（" .. scheme .. "://）は未対応です"
    end
  end

  local dir = vim.fn.fnamemodify(path, ":h")
  local root = target.git_root(dir)
  local relpath = path
  if root then
    local prefix = root .. "/"
    if path:sub(1, #prefix) == prefix then
      relpath = path:sub(#prefix + 1)
    end
  end

  return {
    path = path,
    relpath = relpath,
    lnum = line1,
    end_lnum = line2,
    branch = root and git_branch(root) or nil,
    rev = root and git_rev(root) or nil,
  }, nil
end

-- 現在行/選択範囲 + メモ入力を queue へ積む。
-- line1/line2 省略時は現在行。メモ入力は vim.ui.input（非同期）。
---@param line1? integer
---@param line2? integer
function M.add_comment(line1, line2)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  line1 = line1 or cur
  line2 = line2 or line1
  if line2 < line1 then
    line1, line2 = line2, line1
  end

  local location, err = build_location(line1, line2)
  if not location then
    vim.notify("[herdr-send-queue] " .. err, vim.log.levels.WARN)
    return
  end

  local label = location.relpath .. ":" .. tostring(line1)
  if line2 ~= line1 then
    label = label .. "-" .. tostring(line2)
  end

  -- queue へ積む共通処理（入力方式に依らない）。
  local function commit(text)
    queue.add({
      text = text,
      location = location,
      meta = { kind = "review" },
    })
    vim.notify("[herdr-send-queue] queue に追加: " .. label, vim.log.levels.INFO)
  end

  if config.get().review.input == "float" then
    -- 対象コードを現在バッファから取得して入力欄の上に表示する
    local code = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
    input.open({
      title = "コメント",
      context = { title = label, lines = code, filetype = vim.bo[0].filetype },
      on_submit = commit,
    })
  else
    vim.ui.input({ prompt = "レビューコメント (" .. label .. "): " }, function(text)
      if text == nil or vim.trim(text) == "" then
        return -- キャンセル・空は積まない
      end
      commit(vim.trim(text))
    end)
  end
end

return M
