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

    -- docker-compose variants
    ["docker%-compose.*%.ya?ml"] = "yaml.docker-compose",
    ["compose.*%.ya?ml"] = "yaml.docker-compose",
  },
})
