#!/usr/bin/env python3
"""Summon ship script
Usage: python3 ship_summon.py [--version X.X.X] [--notes "release notes"] [--dry-run]
Builds, installs, tags, and pushes to GitHub.

Changelog: --notes if given, else the shared changelog.py helper's
auto-generation (commit subjects + working-tree diff since the last tag) —
same implementation every scotty ship pipeline uses (fleet parity). This
repo had NO changelog machinery at all before; CHANGELOG.md is created here.
"""
import subprocess, sys, re, os, argparse, tempfile
from pathlib import Path

SCOTTY_SCRIPTS = Path.home() / "Developer/scotty/scripts"
sys.path.insert(0, str(SCOTTY_SCRIPTS))
from changelog import ensure_changelog_entry, prepend_entry, last_tag as _shared_last_tag  # noqa: E402

SCRIPT_DIR = Path(__file__).parent.resolve()
APP_NAME   = "Summon"
REPO_SLUG  = "lswingrover/summon"


def run(cmd, capture=False, check=True):
    print(f"  $ {' '.join(cmd) if isinstance(cmd, list) else cmd}")
    if capture:
        r = subprocess.run(cmd, capture_output=True, text=True, check=check,
                           shell=isinstance(cmd, str))
        return r.stdout.strip()
    subprocess.run(cmd, check=check, shell=isinstance(cmd, str))
    return ""


def bump_plist_version(version: str, build: str):
    plist   = SCRIPT_DIR / "Info.plist"
    content = plist.read_text()
    content = re.sub(
        r'(<key>CFBundleShortVersionString</key>\s*<string>)[^<]*(</string>)',
        rf'\g<1>{version}\g<2>', content)
    content = re.sub(
        r'(<key>CFBundleVersion</key>\s*<string>)[^<]*(</string>)',
        rf'\g<1>{build}\g<2>', content)
    plist.write_text(content)


def bump_swift_version(version: str):
    """Keep AppVersion.swift in sync with Info.plist."""
    av = SCRIPT_DIR / "Sources" / "Summon" / "AppVersion.swift"
    if not av.exists():
        return
    content = av.read_text()
    content = re.sub(r'(static let current\s*=\s*")[^"]*(")', rf'\g<1>{version}\g<2>', content)
    av.write_text(content)


def current_version():
    plist = (SCRIPT_DIR / "Info.plist").read_text()
    m = re.search(r'<key>CFBundleShortVersionString</key>\s*<string>([^<]+)</string>', plist)
    return m.group(1) if m else "1.0.0"


def next_patch(version: str) -> str:
    parts     = version.split(".")
    parts[-1] = str(int(parts[-1]) + 1)
    return ".".join(parts)


def zip_app(version: str) -> Path:
    app_src  = Path(f"/Applications/{APP_NAME}.app")
    zip_path = Path(tempfile.gettempdir()) / f"{APP_NAME}-{version}.zip"
    if zip_path.exists():
        zip_path.unlink()
    subprocess.run(
        ["ditto", "-c", "-k", "--keepParent", str(app_src), str(zip_path)],
        check=True
    )
    size_mb = zip_path.stat().st_size / 1_048_576
    print(f"  ✓ zipped → {zip_path}  ({size_mb:.1f} MB)")
    return zip_path


def main():
    parser = argparse.ArgumentParser(description="Ship Summon")
    parser.add_argument("--version", help="Version string, e.g. 1.1.0. Defaults to auto-patch-bump.")
    parser.add_argument("--notes",   help="Release notes", default="")
    parser.add_argument("--dry-run", action="store_true", help="Build only; skip git tag + push")
    args = parser.parse_args()

    os.chdir(SCRIPT_DIR)

    # Dirty check
    dirty = run(["git", "status", "--porcelain"], capture=True)
    if dirty and not args.dry_run:
        print("⚠  Uncommitted changes — commit or stash first.")
        sys.exit(1)

    # Version
    old_ver = current_version()
    new_ver = args.version or (old_ver if args.dry_run else next_patch(old_ver))
    build   = run(["git", "rev-list", "--count", "HEAD"], capture=True, check=False) or "1"

    print(f"\n▶ Summon ship: {old_ver} → {new_ver}  (build {build})")

    # Capture the prior tag BEFORE we create the new one.
    prev_tag = _shared_last_tag(SCRIPT_DIR)

    # Bump version files
    bump_plist_version(new_ver, build)
    bump_swift_version(new_ver)
    print(f"  ✓ Info.plist + AppVersion.swift bumped to {new_ver}")

    # Build + install to /Applications
    print("\n── Build ──────────────────────────────────────────────────")
    run(["bash", "build_app.sh"])

    if args.dry_run:
        print("\n[dry-run] Skipping changelog, git commit, tag, push.")
        return

    # Changelog (committed together with the version bump). Explicit --notes
    # always wins and gets written directly; otherwise prefer a hand-written
    # entry if one already exists, else auto-generate (shared changelog.py).
    print("\n── Changelog ──────────────────────────────────────────────")
    if args.notes:
        notes = args.notes
        prepend_entry(SCRIPT_DIR / "CHANGELOG.md", new_ver, notes)
    else:
        notes = ensure_changelog_entry(SCRIPT_DIR, new_ver, since=prev_tag)
    print(f"  ✓ CHANGELOG.md updated for v{new_ver}")

    # Commit version bump + changelog
    print("\n── Git ────────────────────────────────────────────────────")
    run(["git", "add", "Info.plist", "Sources/Summon/AppVersion.swift", "CHANGELOG.md"])
    run(["git", "-c", "commit.gpgsign=false", "commit", "-m", f"chore: bump to v{new_ver}"])

    # Tag + push
    tag = f"v{new_ver}"
    run(["git", "tag", "-a", tag, "-m", f"Summon {tag}"])
    run(["git", "push", "origin", "main"])
    run(["git", "push", "origin", tag])

    # GitHub release
    zip_path = None
    try:
        print("\n── GitHub Release ─────────────────────────────────────────")
        zip_path = zip_app(new_ver)
        gh = "/opt/homebrew/bin/gh"
        run([gh, "release", "create", tag,
             str(zip_path),
             "--title", f"Summon {tag}",
             "--notes", notes])
        print(f"  ✓ GitHub release {tag} created")
    except Exception as e:
        print(f"  ⚠ GitHub release failed (create manually): {e}")
    finally:
        if zip_path and zip_path.exists():
            zip_path.unlink()

    print(f"\n✅  Summon {tag} shipped → https://github.com/{REPO_SLUG}/releases/tag/{tag}")


if __name__ == "__main__":
    main()
