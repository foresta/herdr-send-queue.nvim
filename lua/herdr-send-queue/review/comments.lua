-- Review comment preset. Captures the current line / selection as a location and enqueues it with a memo.
local queue = require("herdr-send-queue.queue")
local target = require("herdr-send-queue.core.target")
local config = require("herdr-send-queue.config")
local input = require("herdr-send-queue.view.input")

local M = {}

-- git short sha (nil if unavailable).
local function git_rev(dir)
  local res = vim.system({ "git", "-C", dir, "rev-parse", "--short", "HEAD" }, { text = true }):wait()
  if res.code ~= 0 then
    return nil
  end
  local rev = vim.trim(res.stdout or "")
  return rev ~= "" and rev or nil
end

-- Current branch name (nil if unavailable, e.g. detached HEAD).
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

-- Build a Location from the current buffer and line range.
-- Targets working-tree file buffers (including the right side of a fugitive diff).
---@param line1 integer
---@param line2 integer
---@return Location? location, string? err
local function build_location(line1, line2)
  local path = vim.api.nvim_buf_get_name(0)
  if path == nil or path == "" then
    return nil, "not a named file buffer"
  end
  -- Resolve pseudo-buffers (fugitive:// etc.) to the real path.
  -- FugitiveReal() gives the working-tree file path for fugitive diff/blob buffers.
  -- The line number is used as-is (it maps directly when the diff's right side is the working tree).
  if path:match("^%w+://") then
    local scheme = path:match("^(%w+)://")
    if path:match("^fugitive://") and vim.fn.exists("*FugitiveReal") == 1 then
      local real = vim.fn.FugitiveReal(path)
      if real and real ~= "" and not real:match("^%w+://") then
        path = real
      else
        return nil, "could not resolve the real path of the fugitive buffer (e.g. a status line)"
      end
    else
      return nil, "this buffer type (" .. scheme .. "://) is not supported"
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

-- Enqueue the current line / selection range plus a memo.
-- line1/line2 default to the current line. The memo is entered via vim.ui.input (async).
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

  -- Shared enqueue logic (independent of the input method).
  local function commit(text)
    queue.add({
      text = text,
      location = location,
      meta = { kind = "review" },
    })
    vim.notify("[herdr-send-queue] added to the queue: " .. label, vim.log.levels.INFO)
  end

  if config.get().review.input == "float" then
    -- Fetch the target code from the current buffer and show it above the input field
    local code = vim.api.nvim_buf_get_lines(0, line1 - 1, line2, false)
    input.open({
      title = "Comment",
      context = { title = label, lines = code, filetype = vim.bo[0].filetype },
      on_submit = commit,
    })
  else
    vim.ui.input({ prompt = "Review comment (" .. label .. "): " }, function(text)
      if text == nil or vim.trim(text) == "" then
        return -- do not enqueue on cancel / empty input
      end
      commit(vim.trim(text))
    end)
  end
end

return M
