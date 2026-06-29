"""
aep_sync.py  -  Sync AEP Query Templates between GitHub and Adobe AEP
"""

import argparse
import json
import os
import sys
from pathlib import Path

import requests
from aep_auth import get_headers

REPO_ROOT     = Path(__file__).parent.parent
REGISTRY      = REPO_ROOT / "template_registry.json"
TEMPLATES_DIR = REPO_ROOT / "templates"
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


def cmd_push(args):
    sandbox   = os.getenv("AEP_SANDBOX_NAME", "prod")
    registry  = load_registry()
    existing  = {t["name"]: t for t in list_aep_templates(sandbox)}
    sql_files = sorted(TEMPLATES_DIR.glob("**/*.sql"))

    if not sql_files:
        print("No .sql files found under templates/")
        sys.exit(1)

    print(f"\nPushing {len(sql_files)} template(s) to AEP sandbox: {sandbox}\n")

    for sql_file in sql_files:
        name = sql_file.stem
        sql  = sql_file.read_text(encoding="utf-8")
        rel  = str(sql_file.relative_to(REPO_ROOT))

        try:
            if name in existing:
                tid    = existing[name]["id"]
                update_aep_template(tid, name, sql, sandbox)
                action = "updated"
            else:
                result = create_aep_template(name, sql, sandbox)
                tid    = result.get("id", "unknown")
                action = "created"

            registry["templates"][name] = {
                "id":      tid,
                "file":    rel,
                "sandbox": sandbox,
                "action":  action,
            }
            print(f"  ✔  {name} ({action})")

        except Exception as e:
            print(f"  ✘  {name} — ERROR: {e}")

    save_registry(registry)
    print(f"\nRegistry updated: {REGISTRY}\n")


def cmd_pull(args):
    sandbox   = os.getenv("AEP_SANDBOX_NAME", "prod")
    registry  = load_registry()
    templates = list_aep_templates(sandbox)

    print(f"\nPulling {len(templates)} template(s) from AEP sandbox: {sandbox}\n")

    for t in templates:
        name = t.get("name", "unknown")
        sql  = t.get("sql", "")
        out  = TEMPLATES_DIR / "shared" / f"{name}.sql"
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(sql, encoding="utf-8")
        registry["templates"][name] = {
            "id":      t.get("id"),
            "file":    str(out.relative_to(REPO_ROOT)),
            "sandbox": sandbox,
        }
        print(f"  ✔  {name}")

    save_registry(registry)
    print(f"\nRegistry updated: {REGISTRY}\n")


def cmd_diff(args):
    sandbox   = os.getenv("AEP_SANDBOX_NAME", "prod")
    existing  = {t["name"]: t for t in list_aep_templates(sandbox)}
    sql_files = sorted(TEMPLATES_DIR.glob("**/*.sql"))
    local     = {f.stem for f in sql_files}

    only_local = local - existing.keys()
    only_aep   = existing.keys() - local
    both       = local & existing.keys()

    print(f"\nDiff — sandbox: {sandbox}\n")
    for name in sorted(both):
        print(f"  ✔  {name}  (in both GitHub and AEP)")
    for name in sorted(only_local):
        print(f"  +  {name}  (only in GitHub — will be created on push)")
    for name in sorted(only_aep):
        print(f"  -  {name}  (only in AEP — not in GitHub)")
    print()


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
