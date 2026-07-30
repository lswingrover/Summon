#!/usr/bin/env python3
"""build.py — Build summon-companion.plugin from source skills.

Usage:
    python3 companion-plugin/build.py

Output:
    companion-plugin/summon-companion.plugin

Install:
    Claude → Settings → Capabilities → Plugins → Upload plugin
"""

import json
import os
import re
import subprocess
import sys
import zipfile
from pathlib import Path

HERE = Path(os.path.dirname(os.path.abspath(__file__)))
OUT  = HERE / 'summon-companion.plugin'

PLUGIN_META = {
    'name': 'summon-companion',
    'version': '1.0.1',
    'description': (
        'AI skills for Summon — list, add, and search text expansion snippets '
        'via conversation. Requires Summon running on this Mac (localhost:14732).'
    ),
    'author': {'name': 'Louis Swingrover'},
}

SKILLS = sorted(d.name for d in (HERE / 'skills').iterdir() if d.is_dir())

ALLOWED_FM_FIELDS = {'name', 'description', 'license'}

SECRET_PATTERNS = [
    r'RIKER_API_KEY\s*=\s*\S+',
    r'ANTHROPIC_API_KEY\s*=\s*\S+',
    r'sk-ant-[A-Za-z0-9\-_]{20,}',
]

# Validation comes from obrien-buildtools — the package that owns the plugin validator
# and the preflight scanner. It used to be a path into a laforge checkout, so this
# build depended on an AG-org repo existing on one Mac.
VALIDATE_CMD = [sys.executable, "-m", "obrien_buildtools.validate"]


def sanitize_skill_md(content: str) -> str:
    lines = content.splitlines(keepends=True)
    if not lines or lines[0].rstrip() != '---':
        return re.sub(r'(?m)^---\n', '', content)
    close_idx = None
    for i, line in enumerate(lines[1:], start=1):
        if line.rstrip() == '---':
            close_idx = i
            break
    if close_idx is None:
        return content
    fm_lines = ['---\n']
    skip_multiline = False
    for line in lines[1:close_idx]:
        stripped = line.rstrip()
        if skip_multiline:
            if stripped and not stripped[0].isspace():
                skip_multiline = False
            else:
                continue
        m = re.match(r'^(\w+)\s*:', stripped)
        if m:
            field = m.group(1)
            if field not in ALLOWED_FM_FIELDS:
                if stripped.endswith('|') or stripped.endswith('>'):
                    skip_multiline = True
                continue
        fm_lines.append(line)
    fm_lines.append('---\n')
    body_lines = []
    for line in lines[close_idx + 1:]:
        if line.rstrip() == '---':
            continue
        body_lines.append(line)
    return ''.join(fm_lines + body_lines)


def build():
    print('Scanning for secrets...')
    for skill in SKILLS:
        path = HERE / 'skills' / skill / 'SKILL.md'
        if path.exists():
            text = path.read_text(errors='replace')
            for pattern in SECRET_PATTERNS:
                if re.search(pattern, text):
                    print(f'SECURITY GATE FAILED — {skill}/SKILL.md matches: {pattern}')
                    sys.exit(1)
    print('  No secrets found.')

    with zipfile.ZipFile(str(OUT), 'w', zipfile.ZIP_DEFLATED) as zf:
        zf.writestr('.claude-plugin/plugin.json', json.dumps(PLUGIN_META, indent=2))
        for skill in SKILLS:
            path = HERE / 'skills' / skill / 'SKILL.md'
            if not path.exists():
                print(f'ERROR: missing {path}', file=sys.stderr)
                sys.exit(1)
            raw = path.read_text()
            sanitized = sanitize_skill_md(raw)
            if sanitized != raw:
                print(f'  Sanitized {skill}/SKILL.md')
            zf.writestr(f'skills/{skill}/SKILL.md', sanitized)

    size_kb = OUT.stat().st_size // 1024
    print(f'Built: {OUT}  ({size_kb} KB)')
    print('Install: Claude → Settings → Capabilities → Plugins → Upload plugin')

    # Fail closed: a missing validator is NOT a pass. This block used to print a WARN
    # and ship anyway, so losing the laforge checkout would have silently disabled
    # validation rather than failing loudly.
    print("\nRunning validator...")
    try:
        result = subprocess.run(VALIDATE_CMD + [str(OUT)])
    except FileNotFoundError as e:
        raise SystemExit(
            "FATAL: obrien-buildtools is not installed — refusing to ship an "
            "unvalidated plugin. Install it:\n"
            "  python3 -m pip install --break-system-packages -e ~/Developer/obrien-buildtools"
        ) from e
    if result.returncode == 1:
        print("FAILED validation — fix errors before installing.")
        sys.exit(1)


if __name__ == '__main__':
    build()
