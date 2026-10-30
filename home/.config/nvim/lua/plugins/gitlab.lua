-- GitLab MRs in Neovim: diffview reviewer, inline and draft comments, threads, pipeline. `gl` prefix, g? for help.
-- Host and token come from $GITLAB_URL and $GITLAB_TOKEN (~/.zshenv).
return {
  "harrisoncramer/gitlab.nvim",
  dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim", "sindrets/diffview.nvim" },
  build = function()
    require("gitlab.server").build(true)
  end,
  event = "VeryLazy",
  opts = {
    -- Comments start as drafts; publish them together with glP once you've read them.
    discussion_tree = { draft_mode = true },
    -- Its approve isn't pinned to the commit you read; `rv approve` (glA during an rv review) is.
    keymaps = { global = { approve = false } },
  },
}
