import argparse
import json
from pathlib import Path
from urllib.parse import quote

from google.auth.transport.requests import AuthorizedSession
from google.oauth2 import service_account


SCOPE = "https://www.googleapis.com/auth/androidpublisher"
API_ROOT = "https://androidpublisher.googleapis.com/androidpublisher/v3"
UPLOAD_ROOT = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Publish an AAB to a Google Play testing track.")
    parser.add_argument("--service-account", required=True, type=Path)
    parser.add_argument("--bundle", required=True, type=Path)
    parser.add_argument("--package", required=True)
    parser.add_argument("--track", default="internal")
    parser.add_argument("--release-name", required=True)
    parser.add_argument("--release-notes", default="Automated Battle Mahjong device-testing build.")
    return parser.parse_args()


def checked(response, action: str):
    if response.ok:
        return response.json() if response.content else {}
    detail = response.text[:2000]
    if action == "Create Play edit" and response.status_code == 403:
        detail += (
            "\nVerify that the service-account email appears as Active under Play Console "
            "Users and permissions, with access to this app and testing-track releases."
        )
    raise RuntimeError(f"{action} failed with HTTP {response.status_code}: {detail}")


def main() -> int:
    args = parse_args()
    if not args.service_account.is_file():
        raise FileNotFoundError(f"Service-account key not found: {args.service_account}")
    if not args.bundle.is_file():
        raise FileNotFoundError(f"Android App Bundle not found: {args.bundle}")

    credentials = service_account.Credentials.from_service_account_file(
        args.service_account,
        scopes=[SCOPE],
    )
    session = AuthorizedSession(credentials)
    package = quote(args.package, safe="")
    edit_id = None
    committed = False

    try:
        edit = checked(
            session.post(f"{API_ROOT}/applications/{package}/edits", json={}),
            "Create Play edit",
        )
        edit_id = edit["id"]

        with args.bundle.open("rb") as bundle_file:
            bundle = checked(
                session.post(
                    f"{UPLOAD_ROOT}/applications/{package}/edits/{edit_id}/bundles",
                    params={"uploadType": "media"},
                    headers={"Content-Type": "application/octet-stream"},
                    data=bundle_file,
                ),
                "Upload app bundle",
            )

        version_code = str(bundle["versionCode"])
        track_name = quote(args.track, safe="")
        track_body = {
            "track": args.track,
            "releases": [
                {
                    "name": args.release_name,
                    "versionCodes": [version_code],
                    "status": "completed",
                    "releaseNotes": [
                        {"language": "en-US", "text": args.release_notes[:500]}
                    ],
                }
            ],
        }
        checked(
            session.put(
                f"{API_ROOT}/applications/{package}/edits/{edit_id}/tracks/{track_name}",
                json=track_body,
            ),
            "Update testing track",
        )
        checked(
            session.post(f"{API_ROOT}/applications/{package}/edits/{edit_id}:commit"),
            "Commit Play edit",
        )
        committed = True
        print(f"Published version code {version_code} to the {args.track} track.")
        return 0
    finally:
        if edit_id and not committed:
            session.delete(f"{API_ROOT}/applications/{package}/edits/{edit_id}")


if __name__ == "__main__":
    raise SystemExit(main())
