#!/usr/bin/env python3
"""Merge this repo's Claude Code settings into ~/.claude/settings.json without removing anything.

Objects merge key by key, lists gain the entries they lack, and a hook group is added only when
one of its commands isn't there yet. Settings that only exist locally (work plugins, MCP) stay.
"""
import json
from pathlib import Path
import sys

def merge(live, new):
    for key, value in new.items():
        old = live.get(key)
        if isinstance(value, dict) and isinstance(old, dict): merge(old, value)
        elif isinstance(value, list) and isinstance(old, list): old.extend(v for v in value if v not in old)
        else: live[key] = value
    return live

def main(fragment, target=Path.home()/'.claude/settings.json'):
    new = json.loads(Path(fragment).read_text())
    live = json.loads(target.read_text()) if target.exists() else {}
    hooks = new.pop('hooks', {})
    merge(live, new)
    have = {h['command'] for groups in live.get('hooks', {}).values() for g in groups for h in g['hooks']}
    for event, groups in hooks.items():
        for group in groups:
            if any(h['command'] not in have for h in group['hooks']):
                live.setdefault('hooks', {}).setdefault(event, []).append(group)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(live, indent=2) + '\n')

if __name__ == '__main__':
    main(*sys.argv[1:2], *[Path(p) for p in sys.argv[2:3]])
