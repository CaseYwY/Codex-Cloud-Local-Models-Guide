"""Validate documentation links, examples, snapshot hashes and publication exclusions."""
import ast
import hashlib
import json
from pathlib import Path
import re
import sys
import tomllib
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED = {".git", "reports", ".private", "backups", "__pycache__"}


def main():
    errors = []
    files = [p for p in ROOT.rglob("*") if p.is_file() and not (set(p.relative_to(ROOT).parts) & EXCLUDED)]
    forbidden_names = {"auth.json", "config.toml", "settings.json", "provider-test.toml", "catalog-cache.json"}
    secret_patterns = {
        "GitHub token": r"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{30,})",
        "API secret": r"\bsk-(?:proj-)?[A-Za-z0-9_-]{20,}",
        "JWT": r"\beyJ[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}\.[A-Za-z0-9_-]{12,}",
        "machine account SID": r"S-1-5-21-\d+-\d+-\d+-\d+",
        "origin username": r"\bsr_yf\b",
    }
    links = 0
    for path in files:
        relative = path.relative_to(ROOT).as_posix()
        if path.name in forbidden_names or path.suffix.lower() in {".exe", ".dll", ".log", ".gguf", ".ninfer"}:
            errors.append(relative + ": runtime/private artifact is not distributable")
            continue
        text = path.read_text(encoding="utf-8-sig")
        for label, pattern in secret_patterns.items():
            if re.search(pattern, text):
                errors.append(relative + ": matches " + label)
        if path.suffix == ".json":
            json.loads(text)
        if path.suffix == ".toml":
            tomllib.loads(text)
        if path.suffix == ".py":
            ast.parse(text, filename=relative)
        if path.suffix == ".md":
            for match in re.finditer(r"\[[^\]]*\]\(([^)]+)\)", text):
                target = match.group(1).strip().strip("<>")
                if re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith("#"):
                    continue
                links += 1
                destination = (path.parent / unquote(target.split("#", 1)[0])).resolve()
                if not destination.is_relative_to(ROOT) or not destination.exists():
                    errors.append(relative + ": broken local link: " + target)
    hash_count = 0
    for manifest_path in ROOT.rglob("source-manifest.json"):
        if set(manifest_path.relative_to(ROOT).parts) & EXCLUDED:
            continue
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        snapshot_root = manifest_path.parent.parent
        for item in manifest["files"]:
            path = (snapshot_root / item["path"]).resolve()
            if not path.is_relative_to(snapshot_root.resolve()) or not path.is_file():
                errors.append(item["path"] + ": missing or invalid snapshot path")
                continue
            hash_count += 1
            if hashlib.sha256(path.read_bytes()).hexdigest() != item["sha256"]:
                errors.append(path.relative_to(ROOT).as_posix() + ": snapshot hash differs")
    result = {"passed": not errors, "files_checked": len(files), "local_links_checked": links,
              "reference_hashes_checked": hash_count, "errors": errors}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if not errors else 1


if __name__ == "__main__":
    sys.exit(main())
