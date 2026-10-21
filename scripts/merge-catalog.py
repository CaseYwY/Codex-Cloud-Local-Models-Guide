"""Merge full cloud metadata with local aliases. No network or credential access."""
import argparse
import json
import os
from pathlib import Path
import tempfile


def merge(cloud, local, default_model, replace_local_aliases=()):
    if not isinstance(cloud, dict) or not isinstance(cloud.get("models"), list):
        raise ValueError("Cloud input must be a full Codex catalog with a models array.")
    if not isinstance(local, dict) or not isinstance(local.get("models"), list):
        raise ValueError("Local input must have a models array.")
    for label, entries in [("cloud", cloud["models"]), ("local", local["models"])]:
        slugs = []
        for entry in entries:
            if not isinstance(entry, dict) or not isinstance(entry.get("slug"), str) or not entry["slug"]:
                raise ValueError(label + " has an invalid model slug.")
            for field in ("display_name", "supported_reasoning_levels", "context_window", "base_instructions"):
                if field not in entry:
                    raise ValueError(label + " entry lacks full metadata: " + entry["slug"] + "/" + field)
            slugs.append(entry["slug"])
        if len(slugs) != len(set(slugs)):
            raise ValueError(label + " has duplicate slugs.")
    local_ids = {m["slug"] for m in local["models"]}
    cloud_ids = {m["slug"] for m in cloud["models"]}
    replacements = set(replace_local_aliases)
    if not replacements.issubset(local_ids):
        raise ValueError("Replacement aliases must be present in the incoming local catalog.")
    if default_model in local_ids:
        raise ValueError("A local alias must not replace the existing cloud default.")
    collisions = cloud_ids & local_ids
    if collisions - replacements:
        raise ValueError("Local aliases collide with cloud entries; use distinct aliases. "
                         "Only explicitly verified prior local entries may be replaced.")
    kept = [m for m in cloud["models"] if m["slug"] not in replacements]
    if default_model not in {m["slug"] for m in kept}:
        raise ValueError("The existing cloud default is missing from the cloud catalog.")
    highest = max([0] + [float(m.get("priority") or 0) for m in kept])
    added = [{**m, "priority": highest + 100 + index} for index, m in enumerate(local["models"])]
    return {**cloud, "models": kept + added}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("cloud", "locals", "output", "default-model"):
        parser.add_argument("--" + flag, required=True)
    parser.add_argument("--replace-local-alias", action="append", default=[],
                        help="Explicitly replace a known prior local alias, never an official cloud entry.")
    args = parser.parse_args()
    cloud = json.loads(Path(args.cloud).read_text(encoding="utf-8-sig"))
    local = json.loads(Path(args.locals).read_text(encoding="utf-8-sig"))
    result = merge(cloud, local, args.default_model, args.replace_local_alias)
    output = Path(args.output).resolve()
    if output in (Path(args.cloud).resolve(), Path(args.locals).resolve()):
        raise ValueError("Output must be separate from both input files.")
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=output.parent,
                                         prefix=output.name + ".", suffix=".tmp", delete=False) as handle:
            temporary = Path(handle.name)
            json.dump(result, handle, ensure_ascii=False, indent=2)
            handle.flush()
            os.fsync(handle.fileno())
        json.loads(temporary.read_text(encoding="utf-8"))
        os.replace(temporary, output)
        print(json.dumps({"written": str(output), "cloud_entries": len(cloud["models"]),
                          "local_entries": len(local["models"]), "total_entries": len(result["models"])}))
    finally:
        if temporary is not None and temporary.exists():
            temporary.unlink()


if __name__ == "__main__":
    main()
