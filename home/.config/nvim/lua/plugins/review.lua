-- `rv open` starts nvim on the MR branch with RV_IID, RV_FILE (AI findings), RV_PREV (head you last
-- opened, if the MR moved since) and RV_CTX (MR facts for Claude). gitlab.nvim does the review itself;
-- these <leader>r keys walk the AI findings inside its reviewer.
if not vim.env.RV_FILE then
  return {}
end

local iid, file, prev, ctx = vim.env.RV_IID, vim.env.RV_FILE, vim.env.RV_PREV, vim.env.RV_CTX
local cur = 0

-- Findings with their line in the review file, so accept/drop can rewrite it.
local function findings()
  local list = {}
  for n, l in ipairs(vim.fn.readfile(file)) do
    local path, line, text = l:match("^([^#%s:][^:]*):(%d+): (.*)$")
    if path then
      table.insert(list, { n = n, path = path, line = tonumber(line), text = text })
    end
  end
  return list
end

local function go(i)
  local list = findings()
  if #list == 0 then
    return vim.notify("No AI findings for !" .. iid .. " (<leader>rs runs a pass)")
  end
  cur = (i - 1) % #list + 1
  local f = list[cur]
  require("gitlab.reviewer").jump(f.path, f.path, f.line, true)
  vim.notify(("%d/%d  %s:%d\n%s"):format(cur, #list, f.path, f.line, f.text))
end

local function rewrite(fn)
  local f = findings()[cur]
  if not f then
    return vim.notify("Go to a finding first (<leader>rj)")
  end
  local lines = vim.fn.readfile(file)
  lines[f.n] = fn(lines[f.n])
  vim.fn.writefile(lines, file)
  return f
end

-- Accept: mark it, then open gitlab.nvim's comment popup at the cursor with the finding as the text.
local function accept()
  local f = rewrite(function(l) return (l:gsub(": %(ai%) ", ": ", 1)) end)
  if not f or f.text:match("^%[read%]") then
    return
  end
  local comment = require("gitlab.actions.comment")
  comment.create_comment()
  vim.schedule(function()
    if comment.comment_popup and comment.comment_popup.bufnr then
      vim.api.nvim_buf_set_lines(comment.comment_popup.bufnr, 0, -1, false, { (f.text:gsub("^%(ai%) ", "")) })
    end
  end)
end

local function to_quickfix()
  local items = {}
  for _, f in ipairs(findings()) do
    table.insert(items, { filename = f.path, lnum = f.line, text = f.text })
  end
  vim.fn.setqflist({}, " ", { title = "rv findings", items = items })
  vim.cmd("copen")
end

-- Runs `rv ...` in a terminal split.
local function rv(args)
  vim.cmd("botright 15new")
  vim.fn.jobstart(vim.list_extend({ "rv" }, args), { term = true })
  vim.cmd("startinsert")
end

local function map(lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { desc = "Review: " .. desc })
end

map("<leader>rj", function() go(cur + 1) end, "next AI finding")
map("<leader>rk", function() go(cur - 1) end, "previous AI finding")
map("<leader>ry", accept, "accept finding → draft comment here")
map("<leader>rn", function() if rewrite(function(l) return "# dropped: " .. l end) then go(cur) end end, "drop finding")
map("<leader>rq", to_quickfix, "findings list (<cr> jumps in the reviewer)")
map("<leader>rs", function()
  vim.ui.input({ prompt = "AI review focus (empty = whole MR): " }, function(focus)
    if focus then
      cur = 0
      rv({ "ai", iid, focus })
    end
  end)
end, "AI review pass")
map("<leader>ra", "<cmd>ClaudeCode<cr>", "ask Claude (knows the MR; visual <leader>as sends code)")
map("<leader>ri", function()
  if not prev or prev == "" then
    return vim.notify("No earlier look at !" .. iid .. " to compare with")
  end
  vim.cmd("DiffviewOpen " .. prev)
end, "changes since you last opened it")
map("glA", function() rv({ "approve", iid }) end, "approve, pinned to the commit you opened")

-- <cr> in the findings list jumps inside the reviewer instead of opening the plain file.
vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function(ev)
    if vim.fn.getqflist({ title = 0 }).title == "rv findings" then
      vim.keymap.set("n", "<cr>", function()
        local i = vim.fn.line(".")
        vim.cmd("cclose")
        go(i)
      end, { buffer = ev.buf })
    end
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      require("lazy").load({ plugins = { "gitlab.nvim" } })
      require("gitlab").review()
      local n = #findings()
      vim.notify(n > 0 and ("!%s: %d AI finding(s). <leader>rj walks them, <leader>ry accepts"):format(iid, n)
        or ("!%s: no AI findings yet; <leader>rs runs a pass"):format(iid))
    end)
  end,
})

return {
  -- Read-only Claude that knows the MR (findings included as of opening).
  { "coder/claudecode.nvim", opts = { terminal_cmd = "claude --setting-sources user --strict-mcp-config --permission-mode plan --append-system-prompt-file " .. vim.fn.shellescape(ctx) } },
  { "folke/which-key.nvim", opts = { spec = { { "<leader>r", group = "review !" .. iid } } } },
}
