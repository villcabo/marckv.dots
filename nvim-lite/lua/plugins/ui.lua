local mode = {
  "mode",
  fmt = function(s)
    local mode_map = {
      ["NORMAL"] = "N",
      ["O-PENDING"] = "N?",
      ["INSERT"] = "I",
      ["VISUAL"] = "V",
      ["V-BLOCK"] = "VB",
      ["V-LINE"] = "VL",
      ["V-REPLACE"] = "VR",
      ["REPLACE"] = "R",
      ["COMMAND"] = "!",
      ["SHELL"] = "SH",
      ["TERMINAL"] = "T",
      ["EX"] = "X",
      ["S-BLOCK"] = "SB",
      ["S-LINE"] = "SL",
      ["SELECT"] = "S",
      ["CONFIRM"] = "Y?",
      ["MORE"] = "M",
    }
    return mode_map[s] or s
  end,
}

return {
  -- todo-comments
  { "folke/todo-comments.nvim", version = "*" },

  -- which-key
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "classic",
      win = { border = "single" },
    },
  },

  -- lualine (simplified, no codecompanion extensions)
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    requires = { "nvim-tree/nvim-web-devicons", opt = true },
    opts = {
      options = {
        theme = "gentleman-kanagawa-blur",
        icons_enabled = true,
      },
      sections = {
        lualine_a = {
          {
            "mode",
            icon = "\u{f15de}", -- escaped for the same reason as the dashboard icons above
          },
        },
      },
      extensions = {
        "quickfix",
        {
          filetypes = { "oil" },
          sections = {
            lualine_a = { mode },
            lualine_b = {
              function()
                local ok, oil = pcall(require, "oil")
                if not ok then
                  return ""
                end
                ---@diagnostic disable-next-line: param-type-mismatch
                local path = vim.fn.fnamemodify(oil.get_current_dir(), ":~")
                return path .. " %m"
              end,
            },
          },
        },
      },
    },
  },

  -- fzf-lua: show hidden files
  {
    "ibhagwan/fzf-lua",
    opts = {
      files = { fd_opts = "--type f --hidden --exclude .git" },
      grep = { rg_opts = "--hidden --glob '!.git' --column --line-number --no-heading --color=always --smart-case" },
    },
  },

  -- snacks: dashboard with personal branding
  --
  -- On Neovim 0.9 only its WINDOWS are turned off, not the plugin.
  --
  -- snacks calls nvim_get_hl with the `create` option that Neovim 0.10
  -- introduced, and on 0.9 every window it opens ends in
  --     snacks/util/init.lua:73: invalid key: create
  -- flooding the screen. There is no older snacks to pin to: its first commit
  -- is from November 2024, six months after 0.10.
  --
  -- Disabling the whole plugin was the first attempt and it broke something
  -- else: LazyVim v14 sets
  --     opt.statuscolumn = [[%!v:lua.require'snacks.statuscolumn'.get()]]
  -- (config/options.lua:102), so the number column then failed to render on
  -- every redraw — an error a headless test never sees, because headless draws
  -- nothing. Keeping the library and closing only the window-opening parts
  -- leaves statuscolumn working and the screen quiet.
  {
    "folke/snacks.nvim",
    opts = {
      -- Only the two that OPEN WINDOWS are turned off on 0.9. The plugin
      -- itself stays, and that is not a compromise — it is the only thing that
      -- works.
      --
      -- Removing snacks entirely was tried and abandoned. LazyVim v14 reaches
      -- for the `Snacks` global 127 times: 53 Snacks.picker, 28 Snacks.toggle,
      -- 9 Snacks.words, 8 each of util and terminal, and on down. Every fix
      -- uncovered the next call site — statuscolumn, then news.lua, then
      -- gitsigns' own config at editor.lua:183 — and there was no end to it.
      --
      -- Keeping the library costs 33 MB on Debian 10. Correct beats smaller.
      notifier = { enabled = vim.fn.has("nvim-0.10") == 1 },
      dashboard = {
        enabled = vim.fn.has("nvim-0.10") == 1,
        sections = {
          { section = "header" },
          { icon = "\u{f11c} ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
          { icon = "\u{f0c5} ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
          { section = "startup" },
        },
        preset = {
          -- The banner lives in config/branding.lua, not inline here, because
          -- Neovim 0.9 needs the same thing drawn WITHOUT snacks (this whole
          -- dashboard is off there) and two copies of an ASCII logo drift.
          header = require("config.branding").header(),
          -- Icons as \u{} escapes, not literal glyphs.
          --
          -- Every one of these except Lazy's was a bare space in the file:
          -- eight Nerd Font glyphs silently emptied at some point, and a blank
          -- icon looks exactly like one the terminal cannot draw, so the
          -- dashboard had been shipping like that unnoticed. The codepoints
          -- are snacks' own, read out of its dashboard.lua rather than
          -- guessed. Verified on Neovim 0.9.5: LuaJIT handles \u{} fine.
          -- stylua: ignore
          ---@type snacks.dashboard.Item[]
          keys = {
            { icon = "\u{f002} ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = "\u{f15b} ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = "\u{f07b} ", key = "e", desc = "File Explorer", action = ":Oil" },
            { icon = "\u{f022} ", key = "g", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = "\u{f0c5} ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = "\u{f04b2} ", key = "l", desc = "Lazy", action = ":Lazy" },
            { icon = "\u{f426} ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
      },
    },
  },

}
