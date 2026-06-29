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

REPO_ROOT    = Path(__file__).parent.parent
REGISTRY     = REPO_ROOT / "template_registry.json"
TEMPLATES_DIR = REPO_ROOT / "templates"
API_BASE     = os.getenv("AEP_API_BASE", "https://platform.adobe.io")


# ── Registry helpers ────────────────────────────────────────

def load_registry() -> dict:
    if REGISTRY.exists():
        return json.loads(REGISTRY.read_text(encoding="utf-8"))
    return {"templates": {}}


def save_registry(data: dict):
    REGISTRY.write_text(
        json.dumps(data, indent=2) + "\n",
