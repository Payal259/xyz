"""
aep_sync.py  -  Sync AEP Query Templates between GitHub and Adobe AEP
"""

import argparse
import hashlib
import json
import os
import sys
from pathlib import Path

import requests
from aep_auth import get_headers

REPO_ROOT     = Path(__file__).parent.parent
REGISTRY      = REPO_ROOT / "template_registry.json"
API_BASE      = os.getenv("AEP_API_BASE", "https://platform.adobe.io")


def load_registry():
    if REGISTRY.exists():
        return json.loads(REGISTRY.read_text(encoding="utf-8"))
    return {"templates": {}}


def save_registry(data):
    REGISTRY.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")


def list_aep_templates(sandbox=None):
    url  = f"{API_BASE}/data/foundation/query/query-templates"
    resp = requests.get(url, headers=get_headers(sandbox), timeout=30)
    resp.raise_for_status()
    return resp.json().get("templates", [])


def create_aep_template(name, sql, sandbox=None):
    url  = f"{API_BASE}/data/foundation/query/query-templates"
    body = {"name": name, "sql": sql}
    resp = requests.post(url, headers=get_headers(sandbox), json=body, timeout=30)
    resp.raise_for_status()
    return resp.json()


def update_aep_template(template_id, name, sql, sandbox=None):
    url  = f"{API_BASE}/data/foundation/query/query-templates/{template_id}"
    body = {"name": name, "sql": sql}
    resp = requests.put(url, headers=get_headers(sandbox), json=body, timeout=30)
    resp.raise_for_status()
    return resp.json()


def get_sandbox_for_file(file_path):
    """
    Determines which AEP sandbox to use based on the file's folder path.

    New structure folders (insurance, centerwell, brand_agnostic)
    → use BETA_FEATURES sandbox

    Old structure (templates/ folder)
    → use AEP_STAGING_SANDBOX

    When moving to client environment later, just add more
    folder mappings here with their respective sandbox secrets.
    """
    parts = [p.lower() for p in file_path.parts]

    new_structure_folders = ["insurance", "centerwell", "brand_agnostic"]
    for folder in new_structure_folders:
        if folder in parts:
            sandbox = os.getenv("BETA_FEATURES", "")
            if sandbox:
                return sandbox
            print("  WARN  BETA_FEATURES secret not set - skipping")
            return None

    # fallback for old templates/ folder
    return os.getenv("AEP_STAGING_SANDBOX", "")


def get_all_sql_files():
    """
    Gets all .sql files from the entire repo,
    excluding hidden folders like .github
    """
    return sorted(
        f for f in REPO_ROOT.glob("**/*.sql")
        if not any(part.startswith(".") for part in f.parts)
    )


def cmd_push(args):
    registry  = load_registry()
    sql_files = get_all_sql_files()

    if not sql_files:
        print("No .sql files found in repo")
        sys.exit(1)

    print("")
    print("Checking " + str(len(sql_files)) + " template(s) for changes...")
    print("")

    pushed  = 0
    skipped = 0

    for sql_file in sql_files:
        name     = sql_file.stem
        sql      = sql_file.read_text(encoding="utf-8")
        rel      = str(sql_file.relative_to(REPO_ROOT))
        new_hash = hashlib.md5(sql.strip().encode()).hexdigest()
        sandbox  = get_sandbox_for_file(sql_file)

        if not sandbox:
            print("  SKIP  " + name + " (no sandbox configured for: " + rel + ")")
            skipped += 1
            continue

        reg_entry = registry.get("templates", {}).get(name, {})
        last_hash = reg_entry.get("content_hash", "")

        if last_hash and new_hash == last_hash:
            print("  SKIP  " + name + " (no changes)")
            skipped += 1
            continue

        try:
            existing = {t["name"]: t for t in list_aep_templates(sandbox)}

            if name in existing:
                tid    = existing[name]["id"]
                update_aep_template(tid, name, sql, sandbox)
                action = "updated"
            else:
                result = create_aep_template(name, sql, sandbox)
                tid    = result.get("id", "unknown")
                action = "created"

            registry.setdefault("templates", {})[name] = {
                "id":           tid,
                "file":         rel,
                "sandbox":      sandbox,
                "action":       action,
                "content_hash": new_hash,
            }
            print("  OK  " + name + " (" + action + ") -> " + sandbox)
            pushed += 1

        except Exception as e:
            print("  FAIL  " + name + " - ERROR: " + str(e))

    save_registry(registry)
    print("")
    print("Done - pushed: " + str(pushed) + ", skipped: " + str(skipped))
    print("")


def cmd_pull(args):
    """
    Pulls templates from all configured sandboxes into GitHub.
    Saves content_hash so push won't re-push unchanged templates.
    """
    sandboxes = {}

    beta = os.getenv("BETA_FEATURES", "")
    staging = os.getenv("AEP_STAGING_SANDBOX", "")

    if beta:
        sandboxes["BETA_FEATURES"] = beta
    if staging:
        sandboxes["AEP_STAGING_SANDBOX"] = staging

    if not sandboxes:
        print("No sandbox secrets configured. Nothing to pull.")
        sys.exit(1)

    registry = load_registry()

    for secret_name, sandbox in sandboxes.items():
        templates = list_aep_templates(sandbox)

        print("")
        print("Pulling " + str(len(templates)) + " template(s) from: " + sandbox)
        print("")

        for t in templates:
            name = t.get("name", "unknown")
            sql  = t.get("sql", "")

            if not sql.strip():
                print("  SKIP  " + name + " (empty SQL)")
                continue

            # save pulled templates into shared folder
            out = REPO_ROOT / "templates" / "shared" / (name + ".sql")
            out.parent.mkdir(parents=True, exist_ok=True)
            out.write_text(sql, encoding="utf-8")

            # save hash so push won't re-push unchanged templates
            content_hash = hashlib.md5(sql.strip().encode()).hexdigest()

            registry["templates"][name] = {
                "id":           t.get("id"),
                "file":         str(out.relative_to(REPO_ROOT)),
                "sandbox":      sandbox,
                "content_hash": content_hash,
            }
            print("  OK  " + name)

    save_registry(registry)
    print("")
    print("Registry updated: " + str(REGISTRY))
    print("")


def cmd_diff(args):
    sandboxes = {}

    beta = os.getenv("BETA_FEATURES", "")
    staging = os.getenv("AEP_STAGING_SANDBOX", "")

    if beta:
        sandboxes["BETA_FEATURES"] = beta
    if staging:
        sandboxes["AEP_STAGING_SANDBOX"] = staging

    sql_files = get_all_sql_files()
    local     = set(f.stem for f in sql_files)

    for secret_name, sandbox in sandboxes.items():
        existing  = {t["name"]: t for t in list_aep_templates(sandbox)}

        only_local = local - set(existing.keys())
        only_aep   = set(existing.keys()) - local
        both       = local & set(existing.keys())

        print("")
        print("Diff - sandbox: " + sandbox)
        print("")
        for name in sorted(both):
            print("  MATCH    " + name + "  (in both GitHub and AEP)")
        for name in sorted(only_local):
            print("  NEW      " + name + "  (only in GitHub)")
        for name in sorted(only_aep):
            print("  MISSING  " + name + "  (only in AEP)")
        print("")


def main():
    parser = argparse.ArgumentParser(description="Sync AEP Query Templates")
    sub    = parser.add_subparsers(dest="command")

    push_p = sub.add_parser("push", help="Push local templates to AEP")
    push_p.add_argument("--all", action="store_true", help="Push all templates")

    sub.add_parser("pull", help="Pull templates from AEP to local")
    sub.add_parser("diff", help="Show diff between GitHub and AEP")

    args = parser.parse_args()

    if args.command == "push":
        cmd_push(args)
    elif args.command == "pull":
        cmd_pull(args)
    elif args.command == "diff":
        cmd_diff(args)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
