#!/usr/bin/env bash
# PostToolUse (Edit/Write): format the edited Python file with the repo's own ruff and
# report lint findings back to Claude. Never `--fix`: some repos forbid unattended autofix.
file=$(jq -r '.tool_input.file_path // empty')
[[ $file == *.py && -f $file ]] || exit 0

dir=$(dirname "$file")
while [[ $dir != / && ! -f $dir/pyproject.toml ]]; do dir=$(dirname "$dir"); done
grep -q '^\[tool\.ruff' "$dir/pyproject.toml" 2>/dev/null || exit 0
# The repo's own ruff: its venv, else the version pinned in pyproject.toml via uvx.
# Only a venv built here: a tracked or symlinked .venv is the repo's own code, so don't run it.
venv=$dir/.venv
if [[ -x $venv/bin/ruff && ! -L $venv ]] && git -C "$dir" rev-parse --git-dir &>/dev/null &&
  [[ -z $(git -C "$dir" ls-files -- .venv) && $(realpath "$venv/bin/ruff") == "$(realpath "$venv")"/* ]]; then
  ruff=("$dir/.venv/bin/ruff")
elif pin=$(grep -oP '"ruff==\K[0-9.]+' "$dir/pyproject.toml" | head -1) && [[ -n $pin ]]; then
  ruff=(uvx --quiet "ruff@$pin")
else
  exit 0
fi

cd "$dir" || exit 0
"${ruff[@]}" format --quiet "$file"
if ! out=$("${ruff[@]}" check --quiet "$file" 2>&1); then
  echo "ruff check found issues in $file (fix them by hand; don't run --fix blindly):" >&2
  echo "$out" >&2
  exit 2
fi
