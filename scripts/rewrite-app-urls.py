#!/usr/bin/env python3
import re, sys, argparse, shutil
from pathlib import Path
from difflib import unified_diff

EXTS = {'.json', '.yml', '.yaml', '.conf', '.txt', '.env',
        '.html', '.js', '.ts', '.py', '.go', '.md', '.tf'}

def build_patterns(app, mode):
    try:
        if mode == 'domain':  # path-based -> domain-based
            pattern_str = (
                rf'(https?://)'
                rf'(?P<domain><[^>]+>|[^/\s"\',]+)'
                rf'/{re.escape(app)}(?P<rest>/[^\s\'\"",]*)?'
                rf'(?P<quote>[\'\"",]?)'
            )
        elif mode == 'path':  # domain-based -> path-based
            pattern_str = (
                rf'(https?://)'
                rf'(?P<subdomain>{app})\.'
                rf'(?P<domain><[^>]+>|[^/\s"\',]+)'
                rf'(?P<rest>/[^\s\'\"",]*)?'
                rf'(?P<quote>[\'\"",]?)'
            )
        else:
            raise ValueError(f"Invalid mode: {mode}")

        print(f"[DEBUG] Compiled regex for app '{app}' in mode '{mode}': {pattern_str}")
        return app, re.compile(pattern_str)
    except re.error as e:
        print(f"[ERROR] Failed to compile regex for app '{app}' in mode '{mode}': {e}")
        sys.exit(1)

def rewrite_url(m, app, mode):
    try:
        scheme = m.group(1)
        rest = m.group('rest') or ''
        quote = m.group('quote') or ''

        print(f"[DEBUG] scheme: {scheme}, app: {app}, rest: {rest}, quote: {quote}, mode: {mode}")

        if mode == 'domain':
            domain = m.group('domain')
            print(f"[DEBUG] matched domain (path-based): {domain}")
            return f"{scheme}{app}.{domain}{rest}{quote}"
        else:  # path
            domain = m.group('domain')
            print(f"[DEBUG] matched domain (domain-based): {domain}")
            return f"{scheme}{domain}/{app}{rest}{quote}"
    except Exception as e:
        print(f"[ERROR] Failed to rewrite URL: {e}")
        return m.group(0)  # Return the original match on failure

def process_file(path: Path, patterns, mode, dry_run=False, debug=False):
    try:
        text = path.read_text(encoding='utf-8', errors='ignore')
        new_text = text
        changed = False
        total_changes = 0

        for app, pattern in patterns.items():
            matches = list(pattern.finditer(text))
            if matches:
                if debug:
                    print(f"🧪 {len(matches)} matches found for '{app}' in {path}")
                    for i, m in enumerate(matches, 1):
                        print(f"   [{i}] Full match: {m.group(0)}")
                        for name in m.groupdict():
                            print(f"     - {name}: {m.group(name)}")

                def replacer(m): return rewrite_url(m, app, mode)
                new_text, count = pattern.subn(replacer, new_text)
                total_changes += count
                if count:
                    changed = True

        if changed:
            if dry_run:
                diff = unified_diff(
                    text.splitlines(keepends=True),
                    new_text.splitlines(keepends=True),
                    fromfile=str(path),
                    tofile=str(path) + ' (rewritten)',
                )
                sys.stdout.writelines(diff)
            else:
                bak = path.with_suffix(path.suffix + '.bak')
                shutil.copy(path, bak)
                path.write_text(new_text, encoding='utf-8')
                print(f"✔ Updated {path} (backup: {bak}) [🔧 {total_changes} changes]")
        return changed
    except Exception as e:
        print(f"[ERROR] Failed to process file {path}: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description="Rewrite URLs for app routing")
    parser.add_argument('--dry-run', action='store_true', help="Show changes without modifying files")
    parser.add_argument('--debug', action='store_true', help="Enable debug output")
    parser.add_argument('--mode', choices=['domain', 'path'], required=True, help="Rewrite mode: domain or path")
    parser.add_argument('apps', nargs='+', help="List of application names")
    args = parser.parse_args()

    try:
        patterns = dict(build_patterns(app, args.mode) for app in args.apps)
        any_changes = False

        for path in Path('.').rglob('*'):
            if path.is_file() and path.suffix in EXTS:
                if process_file(path, patterns, mode=args.mode, dry_run=args.dry_run, debug=args.debug):
                    any_changes = True

        if not any_changes:
            print("✅ No matching URLs found.")
        elif args.dry_run:
            print("✅ Dry-run complete. No files were modified.")
        else:
            print("✅ Rewrite complete. Backups saved as *.bak")
    except Exception as e:
        print(f"[ERROR] An error occurred: {e}")
        sys.exit(1)

if __name__ == '__main__':
    main()
