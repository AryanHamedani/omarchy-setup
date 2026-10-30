-- mise puts a bare Python on PATH, so point pyright at the project's uv .venv when it has one.
return {
  "neovim/nvim-lspconfig",
  opts = {
    servers = {
      pyright = {
        before_init = function(_, config)
          local python = (config.root_dir or vim.uv.cwd()) .. "/.venv/bin/python"
          if vim.uv.fs_stat(python) then
            config.settings = vim.tbl_deep_extend("force", config.settings or {}, { python = { pythonPath = python } })
          end
        end,
      },
    },
  },
}
