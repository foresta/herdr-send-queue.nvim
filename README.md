# herdr-send-queue.nvim

Queue up review comments in Neovim and send them to a coding agent (Claude Code, etc.)
running on [herdr](https://herdr.dev/) — as a single batched prompt.

The intended workflow: let an agent write code in `auto` mode, review the diff with
[vim-fugitive](https://github.com/tpope/vim-fugitive), stack a comment on each line you
care about, then flush the whole queue to the agent as one prompt.

## Concept

Two layers: a generic core plus a review preset.

- **Generic core** — a thin transport (`nvim → queue → herdr`) that sends text to any
  pane/agent. The same core backs a general "send selection to a pane" preset (shell / REPL).
- **Flagship feature** — a queue of line-anchored review comments and a one-shot flush.

Sending uses herdr's terminal input injection (`herdr agent prompt`). This plugin never
touches the Anthropic API or the pty directly — it hands herdr a logical `pane_id` and lets
herdr resolve and write to the terminal.

## Requirements

- Neovim >= 0.10 (uses `vim.system`, extmarks, `vim.json`)
- [herdr](https://herdr.dev/) CLI on your `PATH`, and Neovim running inside a herdr pane
- [vim-fugitive](https://github.com/tpope/vim-fugitive) (optional) for the diff-review
  workflow; also enables commenting from `fugitive://` diff buffers

## Installation

Call `setup()` once. Keymaps are wired by default (disable with `set_keymaps = false`).

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "foresta/herdr-send-queue.nvim",
  config = function()
    require("herdr-send-queue").setup({})
  end,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use({
  "foresta/herdr-send-queue.nvim",
  config = function()
    require("herdr-send-queue").setup({})
  end,
})
```

### [dein.vim](https://github.com/Shougo/dein.vim)

```toml
[[plugins]]
repo = 'foresta/herdr-send-queue.nvim'
hook_add = '''
lua require('herdr-send-queue').setup({})
'''
```

> For a non-lazy dein plugin, use `hook_add` (not `hook_post_source`) so `setup()` runs at
> startup.

## Usage

1. Run a coding agent in a herdr pane in `auto` mode; open Neovim in another pane.
2. Review the diff with vim-fugitive.
3. On a line (or a visual selection), press `<leader>ac` and type a comment. The input is a
   floating window that shows the target code above it.
4. Review the queue with `<leader>al` (or the right-split panel via `:HerdrSendQueuePanel`).
5. Press `<leader>aS` to flush: the queue is formatted into one prompt and sent to the
   agent whose working directory matches your git root.

Queued comments also show inline on their source lines (a signcolumn marker + an
end-of-line badge), toggled with `<leader>at`.

## Commands

| Command | Description |
|---|---|
| `:HerdrSendQueueComment` | Enqueue the current line / selection plus a comment (supports a range) |
| `:HerdrSendQueueList` | Open the queue list (floating window or panel, per `view.list`) |
| `:HerdrSendQueueFlush[!]` | Send the queue as one prompt; `!` picks the target pane |
| `:HerdrSendQueuePanel` | Toggle the right-split list panel |
| `:HerdrSendQueueAnnotate` | Toggle inline annotations |
| `:HerdrSendText[!]` | Send the current line / selection to any pane; `!` re-picks the pane |
| `:HerdrRead[!]` | Read and display the target agent's screen text; `!` picks the pane |

## Default keymaps

| Key | Action |
|---|---|
| `<leader>ac` | Comment on the current line / selection (normal & visual) |
| `<leader>al` | Open the queue list |
| `<leader>aS` | Flush the queue |
| `<leader>ap` | Toggle the list panel |
| `<leader>at` | Toggle inline annotations |

`:HerdrSendText` and `:HerdrRead` have no default keymap; map them yourself or use the
commands. Set `set_keymaps = false` to manage all keymaps yourself.

## Configuration

These are the defaults; pass only what you want to override to `setup()`.

```lua
require("herdr-send-queue").setup({
  set_keymaps = true, -- false: do not wire any keymaps (map them yourself)
  keymaps = {
    comment = "<leader>ac",
    list = "<leader>al",
    flush = "<leader>aS",
    panel = "<leader>ap",
    annotate = "<leader>at",
  },
  view = {
    list = "float", -- target of the list keymap/command: "float" or "panel"
    annotate = true, -- enable inline annotations on setup
  },
  annotate = {
    sign_text = "▌", -- signcolumn marker
    icon = " 💬 ", -- end-of-line badge icon
    line_highlight = true, -- highlight the commented line's background
  },
  herdr = {
    cmd = "herdr", -- herdr binary on PATH
  },
  target = {
    match_foreground_cwd = true, -- also match an agent by its foreground_cwd
  },
  review = {
    input = "float", -- comment input: "float" (multi-line) or "prompt" (one line)
  },
  format = {
    agent_type = "claude", -- file-reference format: "claude" (@path#L..) or "plain" (path:line)
    header = "Please address the following review comments.",
  },
  send = {
    submit = true, -- when flushing, also press Enter (false = stage without submitting)
  },
  send_text = {
    submit = true, -- :HerdrSendText presses Enter (REPL-friendly)
    remember_target = false, -- false = pick a pane every time; true = remember within the session
  },
  persist = {
    enabled = false, -- persist the queue across sessions
    path = nil, -- nil = stdpath("state")/herdr-send-queue/queue.json
  },
  read = {
    source = "recent", -- agent read source: visible / recent / recent-unwrapped / detection
    lines = nil, -- number of lines to read (nil = herdr default)
  },
})
```

### Highlights

Inline-annotation colors come from highlight groups you can override after `setup()`:

```lua
vim.api.nvim_set_hl(0, "HerdrSendQueueText", { fg = "#1a1a1a", bg = "#ffd866", bold = true })
vim.api.nvim_set_hl(0, "HerdrSendQueueLine", { bg = "#2d2a1f" })
```

Available: `HerdrSendQueueSign`, `HerdrSendQueueIcon`, `HerdrSendQueueText`,
`HerdrSendQueueLine`.

## License

[MIT](./LICENSE)
