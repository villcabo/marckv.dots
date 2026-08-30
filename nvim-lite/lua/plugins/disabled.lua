-- What nvim-lite does NOT ship
--
-- This config exists to administer servers over SSH. Every plugin here is one
-- LazyVim would install by default, and each is turned off for a reason that
-- holds on a server rather than on a workstation. The full set lives in
-- `nvim/`, which runs where those reasons do not apply.
--
-- Measured: 116 MB and 50 s of `--sync` before this file grew; the plugin
-- clones are the whole cost. The 15 treesitter parsers are 1.1 MB together and
-- were never worth trimming — that was checked before assuming it.

return {
  -- --- heavy UI, and none of it survives a laggy SSH link well -------------
  { "akinsho/bufferline.nvim", enabled = false },
  { "folke/noice.nvim", enabled = false },
  { "rcarriga/nvim-notify", enabled = false },
  -- On 0.10+ snacks.dashboard covers this. On 0.9 snacks keeps running but its
  -- windows are closed (see ui.lua), so LazyVim v14's own dashboard is what is
  -- left there.
  { "nvimdev/dashboard-nvim", enabled = vim.fn.has("nvim-0.10") == 0 },
  { "b0o/incline.nvim", enabled = false },
  { "willothy/veil.nvim", enabled = false },

  -- Completion engine. Off since before this file was rewritten, and worth
  -- stating plainly because it decides the block below: without it there is no
  -- autocompletion, so an LSP client would only be delivering diagnostics.
  --
  -- TWO names, because two LazyVim generations are in play. Neovim 0.11+ gets
  -- LazyVim v15 and blink.cmp; Neovim 0.9/0.10 is pinned to v14, which used
  -- nvim-cmp and its sources instead. Naming only the first left Debian 10
  -- with the whole completion stack installed — nvim-cmp, four cmp sources,
  -- LuaSnip at 9 MB and friendly-snippets — while every other distro had none.
  -- A disable list written against one generation silently misses the other.
  { "saghen/blink.cmp", enabled = false },
  { "hrsh7th/nvim-cmp", enabled = false },
  { "hrsh7th/cmp-nvim-lsp", enabled = false },
  { "hrsh7th/cmp-buffer", enabled = false },
  { "hrsh7th/cmp-path", enabled = false },
  { "saadparwaiz1/cmp_luasnip", enabled = false },
  { "L3MON4D3/LuaSnip", enabled = false },
  { "rafamadriz/friendly-snippets", enabled = false },

  -- --- the LSP / format / lint stack: 22 MB ---------------------------------
  --
  -- With no completion engine, this delivered diagnostics and nothing else,
  -- while conform and nvim-lint need external binaries that were never
  -- installed on these hosts anyway. Treesitter is what actually produces the
  -- highlighting, and it stays.
  --
  -- NOTE: mason used to double as the fallback that installed the tree-sitter
  -- CLI. That is now `04-install-nvim-lite.sh --deps`, which pins the CLI to a
  -- build the machine's GLIBC can run — more deterministic than mason fetching
  -- the newest, which needs GLIBC 2.39 and cannot start on Debian 12 or
  -- Ubuntu 22.04. On Neovim 0.11+ that step is no longer optional.
  { "neovim/nvim-lspconfig", enabled = false },
  { "mason-org/mason.nvim", enabled = false },
  { "mason-org/mason-lspconfig.nvim", enabled = false },
  { "williamboman/mason.nvim", enabled = false },
  { "williamboman/mason-lspconfig.nvim", enabled = false },
  { "stevearc/conform.nvim", enabled = false },
  { "mfussenegger/nvim-lint", enabled = false },
  { "folke/lazydev.nvim", enabled = false },  -- Lua LSP helper, pointless with no LSP
  { "folke/neodev.nvim", enabled = false },  -- the same thing under LazyVim v14

  -- --- editing niceties that a server session never reaches for ------------
  { "MagicDuck/grug-far.nvim", enabled = false },  -- :%s, sed and rg already do this
  { "folke/trouble.nvim", enabled = false },       -- a diagnostics list, with no diagnostics
  { "folke/persistence.nvim", enabled = false },   -- restores sessions; you open one file
  { "windwp/nvim-ts-autotag", enabled = false },   -- closes JSX/HTML tags
  { "folke/zen-mode.nvim", enabled = false },      -- distraction-free, over SSH
}
