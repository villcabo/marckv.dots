return {
  "zbirenbaum/copilot.lua",
  optional = true,
  opts = function(_, opts)
    -- El server JS corre sobre Node 24 (única versión vía fnm) y falla con
    -- "Invalid GitHub server URL". El binario nativo no depende de Node.
    opts.server = { type = "binary" }
    require("copilot.api").status = require("copilot.status")
    require("copilot.api").filetypes = {
      filetypes = {
        yaml = false,
        markdown = false,
        help = false,
        gitcommit = false,
        gitrebase = false,
        hgcommit = false,
        svn = false,
        cvs = false,
        ["."] = false,
      },
    }
  end,
}
