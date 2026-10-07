-- Module that centralizes default settings. Other modules read config.get().
local M = {}

M.defaults = {
  -- Set to false to make setup() skip keymap wiring (user wires their own).
  set_keymaps = true,
  keymaps = {
    comment = "<leader>ac", -- add current line/selection + note to the queue
    list = "<leader>al", -- queue list (shown via view.list)
    flush = "<leader>aS", -- flush the queue and clear
    panel = "<leader>ap", -- toggle the list panel
    annotate = "<leader>at", -- toggle inline line annotations
  },
  view = {
    -- Where the list keymap/command shows. "float"=centered floating window, "panel"=right split.
    list = "float",
    -- Whether to enable inline line annotations automatically on setup().
    annotate = true,
  },
  annotate = {
    sign_text = "▌", -- signcolumn marker (max 2 cells)
    icon = " 💬 ", -- leading icon for the end-of-line badge
    line_highlight = true, -- whether to highlight the background of the line
    -- Highlights are defined via HerdrSendQueue{Sign,Icon,Text,Line} as default links.
    -- To change colors, override them with vim.api.nvim_set_hl after setup.
  },
  herdr = {
    cmd = "herdr", -- binary name to run (on PATH)
  },
  target = {
    -- cwd->agent resolution is done in core/target.lua by matching the git root against the agent's cwd.
    -- Whether a match on either cwd or foreground_cwd is acceptable.
    match_foreground_cwd = true,
  },
  review = {
    -- Comment input method. "float"=multi-line floating input, "prompt"=single-line vim.ui.input.
    input = "float",
  },
  format = {
    -- Agent type that decides the file reference format. "claude" uses @relpath#L.., "plain" uses relpath:lnum.
    agent_type = "claude",
    header = "Please address the following review comments.",
  },
  send = {
    submit = true, -- when flushing, also press Enter (false = stage without submitting)
  },
  send_text = {
    -- Whether the generic send preset (:HerdrSendText) also presses Enter. Default true since REPLs want execution.
    submit = true,
    -- Whether to remember the target and resend to it. Default false = show the picker every time (avoid misfires).
    -- Set true to remember within the session; use :HerdrSendText! to pick again.
    remember_target = false,
  },
  persist = {
    -- Whether to save/restore the queue across sessions (default OFF).
    enabled = false,
    -- If nil, uses stdpath("state")/herdr-send-queue/queue.json.
    path = nil,
  },
  read = {
    -- agent read source for response capture (:HerdrRead): visible / recent / recent-unwrapped / detection
    source = "recent",
    -- Number of lines to read (nil = herdr default).
    lines = nil,
  },
}

local options = nil

-- Deep merge user opts into the defaults and keep the result.
function M.setup(opts)
  options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  return options
end

-- Return the current settings. Works with defaults even before setup().
function M.get()
  if not options then
    options = vim.deepcopy(M.defaults)
  end
  return options
end

return M
