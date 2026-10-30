-- Side-by-side diffs with a file panel: whole MRs (rv review), branches, file history.
return {
  "sindrets/diffview.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<leader>gD", "<cmd>DiffviewOpen<cr>", desc = "Diffview: working tree" },
    { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: file history" },
  },
  opts = {},
}
