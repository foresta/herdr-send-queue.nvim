-- Generic staging. Just keeps an ordered array of id'd fragments in memory.
-- Depends on neither the agent nor comments (presets other than review can build on the same base).
--
---@class Location
---@field path     string   -- absolute path
---@field relpath  string   -- repo-relative (for @path#L..)
---@field lnum     integer  -- 1-based start line
---@field end_lnum integer  -- end line (inclusive)
---@field branch?  string
---@field rev?     string   -- short sha
--
---@class Fragment
---@field id       string    -- stable id (for editing/removal)
---@field text     string    -- content the user wrote (note/code)
---@field location? Location
---@field meta?    table     -- free-form (e.g. kind="review")

local M = {}

---@type Fragment[]
local items = {}
local seq = 0

-- Notify the view of a change. The view can redraw by reading queue.list() alone (loosely coupled).
local function notify()
  vim.api.nvim_exec_autocmds("User", { pattern = "HerdrSendQueueChanged" })
end

-- Append a fragment. Assigns an id and returns it.
---@param fragment Fragment
---@return string id
function M.add(fragment)
  seq = seq + 1
  fragment.id = tostring(seq)
  table.insert(items, fragment)
  notify()
  return fragment.id
end

-- Return the current queue (a copy) in order.
---@return Fragment[]
function M.list()
  return vim.deepcopy(items)
end

-- Get one item by id.
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

-- Remove one item by id. Returns true if removed.
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

-- Clear everything.
function M.clear()
  if #items == 0 then
    return
  end
  items = {}
  notify()
end

-- Count.
---@return integer
function M.count()
  return #items
end

return M
