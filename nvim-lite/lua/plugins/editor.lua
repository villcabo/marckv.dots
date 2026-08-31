return {
  -- Oil.nvim: Edit your filesystem like a buffer
  --
  -- Pinned to the nvim-0.9 branch on Neovim 0.9. Master's setup() starts with
  --     if vim.fn.has("nvim-0.10") == 0 then ... return end
  -- so on Debian 10 it prints an error and NEVER INITIALISES. The `-` keymap
  -- still shows up under :map, because this spec defines it — but there is no
  -- :Oil behind it. Checking that the mapping exists says nothing about
  -- whether the plugin does.
  --
  -- The error it prints names the wrong plugin ("aerial is deprecated"),
  -- shared boilerplate from the same author, which is why it took a while to
  -- trace back here.
  {
    "stevearc/oil.nvim",
    branch = vim.fn.has("nvim-0.10") == 0 and "nvim-0.9" or nil,
    lazy = false,
    keys = {
      { "-", "<CMD>Oil<CR>", desc = "Open Oil (parent dir)" },
      { "<leader>E", "<CMD>Oil --float<CR>", desc = "Open Oil (floating)" },
      -- Inherited from neo-tree, which is disabled in plugins/disabled.lua.
      -- Pointing the key at oil means dropping that plugin costs nothing in
      -- muscle memory: <leader>e still opens a file explorer, just the one
      -- already in use.
      { "<leader>e", "<CMD>Oil<CR>", desc = "Explorer (Oil)" },
    },
    opts = {
      default_file_explorer = true,
      restore_win_options = true,
      skip_confirm_for_simple_edits = false,
      prompt_save_on_select_new_entry = true,
      keymaps = {
        ["g?"] = "actions.show_help",
        ["<CR>"] = "actions.select",
        ["<C-s>"] = { "actions.select", opts = { vertical = true }, desc = "Open in vertical split" },
        ["<C-v>"] = { "actions.select", opts = { horizontal = true }, desc = "Open in horizontal split" },
        ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open in new tab" },
        ["<C-p>"] = "actions.preview",
        ["<C-c>"] = "actions.close",
        ["<C-r>"] = "actions.refresh",
        ["-"] = "actions.parent",
        ["_"] = "actions.open_cwd",
        ["`"] = "actions.cd",
        ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
        ["gs"] = "actions.change_sort",
        ["gx"] = "actions.open_external",
        ["g."] = "actions.toggle_hidden",
        ["g\\"] = "actions.toggle_trash",
        ["q"] = "actions.close",
      },
      use_default_keymaps = false,
      view_options = {
        show_hidden = true,
        is_hidden_file = function(name, bufnr)
          return vim.startswith(name, ".")
        end,
        is_always_hidden = function(name, bufnr)
          return name == ".." or name == ".git"
        end,
        natural_order = true,
        case_insensitive = false,
        sort = {
          { "type", "asc" },
          { "name", "asc" },
        },
      },
      float = {
        padding = 2,
        max_width = 100,
        max_height = 30,
        border = "rounded",
        win_options = { winblend = 0 },
        preview_split = "auto",
      },
    },
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function(_, opts)
      require("oil").setup(opts)

      vim.api.nvim_create_autocmd("FileType", {
        pattern = "oil",
        callback = function()
          vim.opt_local.colorcolumn = ""
          vim.opt_local.signcolumn = "no"
        end,
      })

      vim.keymap.set("n", "<leader>-", function()
        local oil = require("oil")
        local current_file = vim.api.nvim_buf_get_name(0)
        if current_file and current_file ~= "" then
          oil.open(vim.fn.fnamemodify(current_file, ":h"))
        else
          oil.open()
        end
      end, { desc = "Open Oil in current file's directory" })
    end,
  },


}
