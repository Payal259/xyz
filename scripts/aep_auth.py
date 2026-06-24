"""
aep_auth.py  –  Adobe IMS Authentication Helper
Handles token generation and refresh for AEP API calls.
"""

import os
import time
import requests
from dotenv import load_dotenv

load_dotenv()

_token_cache = {"access_token": None, "expires_at": 0}


def get_access_token() -> str:
    if _token_cache["access_token"] and time.time() < _token_cache["expires_at"] - 60:
        return _token_cache["access_token"]

    env_token = os.getenv("AEP_ACCESS_TOKEN")
    if env_token:
        return env_token

    client_id     = os.getenv("AEP_CLIENT_ID")
    client_secret = os.getenv("AEP_CLIENT_SECRET")
    ims_url       = os.getenv("AEP_IMS_URL", "https://ims-na1.adobelogin.com")

    if not client_id or not client_secret:
        raise EnvironmentError(
            "AEP_CLIENT_ID and AEP_CLIENT_SECRET must be set in your .env file."
        )

    url = f"{ims_url}/ims/token/v3"
    payload = {
        "grant_type":    "client_credentials",
        "client_id":     client_id,
        "client_secret": client_secret,
        "scope": (
            "AdobeID,openid,read_organizations,"
            "additional_info.projectedProductContext,"
            "additional_info.roles,adobeio_api,"
            "read_client_secret,manage_client_secrets"
        ),
    }

    resp = requests.post(url, data=payload, timeout=30)
    resp.raise_for_status()
    data = resp.json()

    _token_cache["access_token"] = data["access_token"]
    _token_cache["expires_at"]   = time.time() + data.get("expires_in", 3600)

    return _token_cache["access_token"]


def get_headers(sandbox_override: str | None = None) -> dict:
    sandbox = sandbox_override or os.getenv("AEP_SANDBOX_NAME", "prod")
    return {
        "Authorization":   f"Bearer {get_access_token()}",
        "x-api-key":       os.getenv("AEP_CLIENT_ID"),
        "x-gw-ims-org-id": os.getenv("AEP_ORG_ID"),
        "x-sandbox-name":  sandbox,
        "Content-Type":    "application/json",
    }
