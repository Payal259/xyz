"""
validate_sql.py  –  Pre-push SQL Validation for AEP Query Templates
"""

import argparse
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent

REQUIRED_FIELDS = ["name", "description", "category", "owner"]

FORBIDDEN_PATTERNS = [
    (r"\bDROP\b",     "DROP statement detected – destructive operations not allowed"),
    (r"\bTRUNCATE\b", "TRUNCATE statement detected – destructive operations not allowed"),
    (r"\bDELETE\b",   "DELETE statement detected – use SELECT only"),
    (r"\bINSERT\b",   "INSERT statement detected – use SELECT only"),
    (r"\bCREATE\b",   "CREATE statement detected – DDL not allowed in query templates"),
    (r"\bALTER\b",    "ALTER statement detected – DDL not allowed in query templates"),
]

AEP_WARNINGS = [
    (
        r"FROM\s+experience_events",
        r"_acp_year",
        "WARNING: Querying experience_events without _acp_year partition filter "
        "may cause full table scans and high query costs.",
    ),
]


def parse_front_matter(content: str) -> dict:
    meta = {}
    in_header = False
    for line in content.splitlines():
        stripped
