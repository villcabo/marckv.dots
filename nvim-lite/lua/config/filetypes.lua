-- Custom filetype detection for server files
-- Uses the modern vim.filetype.add API (Neovim >= 0.7)
--
-- Loaded from init.lua so it runs before plugins resolve any filetype.

vim.filetype.add({
  -- Exact filename matches
  filename = {
    ["authorized_keys"] = "authorized_keys",
    ["authorized_keys2"] = "authorized_keys",
    ["nginx.conf"] = "nginx",

    -- The /etc files opened from their own directory rather than by path.
    ["passwd"] = "passwd",
    ["group"] = "passwd",
    ["fstab"] = "fstab",
    ["hosts"] = "conf",
    ["crontab"] = "crontab",
  },

  -- Glob patterns
  pattern = {
    -- SSH authorized_keys variants
    ["authorized_keys.*"] = "authorized_keys",
    [".*/authorized_keys"] = "authorized_keys",
    [".*/authorized_keys.*"] = "authorized_keys",

    -- Log files
    [".*%.log"] = "log",
    [".*%.log%..*"] = "log",
    ["/var/log/.*"] = "log",

    -- NOTE: .env files are detected natively as filetype "env" in modern Neovim
    -- with proper highlighting — no custom pattern needed.

    -- nginx configs anywhere under an nginx/ directory
    [".*/nginx/.*%.conf"] = "nginx",

    -- docker-compose variants → yaml puro (sin el sufijo .docker-compose,
    -- que sin yaml-language-server solo rompe el highlight de treesitter).
    ["docker%-compose.*%.ya?ml"] = "yaml",
    ["compose.*%.ya?ml"] = "yaml",

    -- systemd units, ANYWHERE.
    --
    -- Neovim ships syntax/systemd.vim but only detects units living under
    -- /etc/systemd, /usr/lib/systemd and friends. On a server you open copies,
    -- backups and staged files far more often than the installed path, and
    -- those came up with no filetype at all — measured, not assumed.
    [".*%.service"] = "systemd",
    [".*%.timer"] = "systemd",
    [".*%.socket"] = "systemd",
    [".*%.mount"] = "systemd",
    [".*%.target"] = "systemd",
    [".*%.path"] = "systemd",

    -- The /etc files, by name rather than by path, for the same reason.
    -- Neovim detects /etc/passwd and /etc/fstab; it does not detect a copy of
    -- either sitting anywhere else.
    [".*/passwd"] = "passwd",
    [".*/group"] = "passwd",
    [".*/shadow"] = "passwd",
    [".*/fstab"] = "fstab",

    -- /etc/hosts has no filetype in Neovim at all, not even at its own path.
    -- conf is not a parser, but it does give comments and structure, which is
    -- the whole difference when reading one.
    [".*/hosts"] = "conf",
  },

})
