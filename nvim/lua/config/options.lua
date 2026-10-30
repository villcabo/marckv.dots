-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- No tocar el final del archivo al guardar: ni agregar un newline final si
-- falta, ni quitar el que ya está. Preserva el archivo tal cual.
vim.opt.fixendofline = false

-- Detectar INI por contenido en archivos sin extensión (ej. ~/.oidc-sintesis).
-- Prioridad mínima: solo corre si nombre, extensión y shebang no dieron tipo.
-- Pide una sección [nombre] seguida de líneas clave=valor en las primeras 30.
-- Clave ".+" y no ".*": snacks.bigfile ya registra ".*" y la pisaría.
vim.filetype.add({
  pattern = {
    [".+"] = {
      function(_, bufnr)
        local section, pairs = false, 0
        for _, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, 30, false)) do
          if line:match("^%s*$") or line:match("^%s*[;#]") then
            -- vacía o comentario: se ignora
          elseif line:match("^%s*%[[^%]]+%]%s*$") then
            section = true
          elseif section and line:match("^%s*[%w_.-]+%s*=") then
            pairs = pairs + 1
          else
            return
          end
        end
        if section and pairs > 0 then
          return "dosini"
        end
      end,
      { priority = -math.huge },
    },
  },
})
