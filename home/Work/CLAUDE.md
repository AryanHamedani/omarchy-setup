# ~/Work

## Worktrees

Task work (anything that becomes a branch/MR) happens in a worktree, not a repo's main checkout.
The main checkout is fine when Aryan asks for it, for gitignored local files, or for work that isn't branch work.
`~/.claude/hooks/worktree-guard.sh` bounces the first main-checkout edit per repo per session as a reminder;
retrying the edit goes through. Worktree layout matches `claude -w`:

```bash
git -C <repo> fetch origin
git -C <repo> worktree add <repo>/.claude/worktrees/<slug> -b <type>/<task> origin/HEAD
```

- Name the branch by the repo's own convention (its CLAUDE.md/AGENTS.md); `<slug>` is the branch with `/` → `-`.
- One worktree per repo per task. If one already exists for the task (`git -C <repo> worktree list`), reuse it.
- Do every edit, test and commit inside the worktree path, and `cd` there for commands.
- A new worktree has no untracked files: run `uv sync` / `npm ci`, and copy what you need from the main
  checkout (e.g. `mise.local.toml`, `.env`).
- Share the main checkout's docker compose stack instead of starting a second one (ports clash).
- After the MR is merged: `git -C <repo> worktree remove <path>` and delete the branch.
