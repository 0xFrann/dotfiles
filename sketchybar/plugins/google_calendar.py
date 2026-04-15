#!/usr/bin/env python3
"""Fetch today's Google Calendar events (OAuth) and print the next-event line for SketchyBar.

SketchyBar runs this on a timer. One-time setup: ./scripts/setup-google-calendar.sh

Output: label, or label<TAB>count when there are remaining events today.
On errors, prints a short ⚠ label so the bar shows what went wrong."""

from __future__ import annotations

import json
import os
import sys
import traceback
from datetime import datetime, timedelta, timezone, tzinfo
from pathlib import Path
from zoneinfo import ZoneInfo

_CMD = sys.argv[1] if len(sys.argv) > 1 else ""
_AUTH_MODE = _CMD in ("--auth", "--login")
_LIST_MODE = _CMD == "--list-calendars"
_INSTALL_HINT = "Run ./scripts/setup-google-calendar.sh (see README)"

try:
    from google.auth.transport.requests import Request
    from google.oauth2.credentials import Credentials
    from google_auth_oauthlib.flow import InstalledAppFlow
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError
except ImportError:
    if _AUTH_MODE:
        print(_INSTALL_HINT, file=sys.stderr)
        sys.exit(1)
    print("⚠ deps not installed", end="")
    print(f"sketchybar-next-event: {_INSTALL_HINT}.", file=sys.stderr)
    sys.exit(0)

SCOPES = ["https://www.googleapis.com/auth/calendar.readonly"]


class _CalendarAPIError(Exception):
    """Carries a short user-visible label for the SketchyBar widget."""

    def __init__(self, label: str, detail: str = ""):
        self.label = label
        super().__init__(detail or label)


def _config_dir() -> Path:
    if d := os.environ.get("CONFIG_DIR"):
        return Path(d)
    return Path.home() / ".config" / "sketchybar"


def _cred_paths() -> tuple[Path, Path]:
    cfg = _config_dir()
    cred = Path(os.environ.get("GOOGLE_CALENDAR_CREDENTIALS_PATH", cfg / "google_calendar_credentials.json"))
    tok = Path(os.environ.get("GOOGLE_CALENDAR_TOKEN_PATH", cfg / "google_calendar_token.json"))
    return cred, tok


def _config_path() -> Path:
    return _config_dir() / "google_calendar_config.json"


def _load_exclude_set() -> set[str]:
    """Read the exclude list from config. Returns empty set if no config."""
    path = _config_path()
    if not path.is_file():
        return set()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return {name.lower() for name in data.get("exclude", [])}
    except Exception:
        return set()


def _load_exclude_event_prefixes() -> list[str]:
    """Read event title prefixes to hide from config. Case-insensitive."""
    path = _config_path()
    if not path.is_file():
        return []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return [p.lower() for p in data.get("exclude_events", [])]
    except Exception:
        return []


def run_oauth_login() -> None:
    """Open browser once; save refresh token. Called by setup-google-calendar.sh."""
    cred_path, token_path = _cred_paths()
    if not cred_path.is_file():
        print(f"Missing: {cred_path}", file=sys.stderr)
        print("Download it from Google Cloud Console (see README).", file=sys.stderr)
        sys.exit(1)
    flow = InstalledAppFlow.from_client_secrets_file(str(cred_path), SCOPES)
    creds = flow.run_local_server(port=0, open_browser=True)
    token_path.parent.mkdir(parents=True, exist_ok=True)
    token_path.write_text(creds.to_json(), encoding="utf-8")
    os.chmod(token_path, 0o600)
    print(f"Saved token to {token_path}\nRun: sketchybar --reload")


def list_calendars() -> None:
    """Print available calendars. Called by setup-google-calendar.sh."""
    creds = _load_credentials()
    if creds is None:
        print("No valid token. Run --auth first.", file=sys.stderr)
        sys.exit(1)
    service = build("calendar", "v3", credentials=creds, cache_discovery=False)
    exclude = _load_exclude_set()
    res = service.calendarList().list().execute()
    for cal in res.get("items", []):
        name = cal.get("summary", "(untitled)")
        primary = " (primary)" if cal.get("primary") else ""
        excluded = " [excluded]" if name.lower() in exclude else ""
        print(f"  - {name}{primary}{excluded}")


def _local_tz() -> tzinfo:
    """System local timezone; not always zoneinfo.ZoneInfo (PEP 615 vs fixed offset)."""
    if (n := os.environ.get("TZ")):
        try:
            return ZoneInfo(n)
        except Exception:
            pass
    tz = datetime.now().astimezone().tzinfo
    if tz is None:
        return timezone.utc
    if isinstance(tz, ZoneInfo):
        return tz
    # e.g. datetime.timezone(fixed offset): still valid for combine() / bounds
    return tz


def _fmt_clock(dt: datetime) -> str:
    h = dt.hour % 12 or 12
    return f"{h}:{dt.strftime('%M')} {dt.strftime('%p')}"


def _parse_rfc3339(s: str, local_tz: tzinfo) -> datetime:
    if s.endswith("Z"):
        s = s[:-1] + "+00:00"
    dt = datetime.fromisoformat(s)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=local_tz)
    return dt.astimezone(local_tz)


def _event_from_api_item(raw: dict, local_tz: tzinfo) -> tuple[datetime, datetime, str, bool] | None:
    if raw.get("status") == "cancelled":
        return None
    start = raw.get("start") or {}
    end = raw.get("end") or {}
    summary = raw.get("summary") or "(no title)"
    if "date" in start:
        ds = datetime.strptime(start["date"], "%Y-%m-%d").date()
        start_dt = datetime.combine(ds, datetime.min.time(), tzinfo=local_tz)
        end_s = end.get("date")
        if end_s:
            de = datetime.strptime(end_s, "%Y-%m-%d").date()
            end_dt = datetime.combine(de, datetime.min.time(), tzinfo=local_tz)
        else:
            end_dt = start_dt + timedelta(days=1)
        return start_dt, end_dt, summary, True
    st = start.get("dateTime")
    if not st:
        return None
    start_dt = _parse_rfc3339(st, local_tz)
    et = end.get("dateTime")
    if et:
        end_dt = _parse_rfc3339(et, local_tz)
    else:
        end_dt = start_dt + timedelta(hours=1)
    return start_dt, end_dt, summary, False


def _load_credentials() -> Credentials | None:
    _, token_path = _cred_paths()
    if not token_path.is_file():
        return None
    try:
        creds = Credentials.from_authorized_user_file(str(token_path), SCOPES)
    except Exception:
        return None
    if not creds.valid:
        if creds.expired and creds.refresh_token:
            try:
                creds.refresh(Request())
            except Exception:
                return None
            try:
                token_path.write_text(creds.to_json(), encoding="utf-8")
            except OSError:
                pass
        else:
            return None
    return creds


def _api_error_from_http(e: HttpError, context: str) -> _CalendarAPIError:
    """Classify an HttpError into a short bar-friendly label."""
    status = int(e.resp.status) if e.resp else 0
    body = str(e)
    print(f"sketchybar-next-event: {context} failed ({status}): {body}", file=sys.stderr)
    if status == 403 and "accessNotConfigured" in body:
        return _CalendarAPIError("⚠ enable Calendar API", body)
    if status == 401:
        return _CalendarAPIError("⚠ token expired", body)
    if status == 403:
        return _CalendarAPIError("⚠ access denied", body)
    return _CalendarAPIError(f"⚠ API error ({status})", body)


def _fetch_events_today(
    service, local_tz: tzinfo, exclude: set[str],
    exclude_prefixes: list[str] | None = None,
) -> list[tuple[datetime, datetime, str, bool]]:
    now = datetime.now(local_tz)
    day_start = datetime.combine(now.date(), datetime.min.time(), tzinfo=local_tz)
    day_end = day_start + timedelta(days=1)
    time_min = day_start.isoformat()
    time_max = day_end.isoformat()

    merged: list[tuple[datetime, datetime, str, bool]] = []

    cal_page = None
    while True:
        try:
            cal_res = service.calendarList().list(pageToken=cal_page).execute()
        except HttpError as e:
            raise _api_error_from_http(e, "calendarList") from e
        for cal in cal_res.get("items", []):
            cal_name = cal.get("summary", "")
            if cal_name.lower() in exclude:
                continue
            cal_id = cal.get("id")
            if not cal_id:
                continue
            ev_page = None
            while True:
                try:
                    ev_res = (
                        service.events()
                        .list(
                            calendarId=cal_id,
                            timeMin=time_min,
                            timeMax=time_max,
                            singleEvents=True,
                            orderBy="startTime",
                            pageToken=ev_page,
                        )
                        .execute()
                    )
                except HttpError as e:
                    status = int(e.resp.status) if e.resp else 0
                    if status in (403, 404):
                        break
                    raise
                for item in ev_res.get("items", []):
                    parsed = _event_from_api_item(item, local_tz)
                    if parsed:
                        if exclude_prefixes:
                            title_lower = parsed[2].strip().lower()
                            if any(title_lower.startswith(p) for p in exclude_prefixes):
                                continue
                        merged.append(parsed)
                ev_page = ev_res.get("nextPageToken")
                if not ev_page:
                    break
        cal_page = cal_res.get("nextPageToken")
        if not cal_page:
            break

    return merged


def _pick_label(
    events: list[tuple[datetime, datetime, str, bool]],
    now: datetime,
) -> tuple[str, int | None]:
    """Return (label_text, remaining_count_today). count is None when no events."""
    local_tz = now.tzinfo
    if local_tz is None:
        local_tz = _local_tz()
        now = now.replace(tzinfo=local_tz)
    today = now.date()
    tomorrow = today + timedelta(days=1)
    day_start = datetime.combine(today, datetime.min.time(), tzinfo=local_tz)
    day_end = datetime.combine(tomorrow, datetime.min.time(), tzinfo=local_tz)

    candidates: list[tuple[datetime, datetime, str, bool]] = []
    for start, end, title, _ad in events:
        if end <= day_start or start >= day_end:
            continue
        if end <= now:
            continue
        candidates.append((start, end, title, _ad))

    if not candidates:
        return "—", None

    candidates.sort(key=lambda x: x[0])

    # If the first candidate already started and something else starts within
    # 15 minutes, show the upcoming one so the user gets a heads-up.
    pick = candidates[0]
    if pick[0] <= now and len(candidates) > 1:
        next_up = candidates[1]
        if not next_up[3] and next_up[0] - now <= timedelta(minutes=15):
            pick = next_up

    start, _end, title, all_day = pick
    remaining = len(candidates)

    if all_day:
        prefix = "All day · "
    else:
        prefix = _fmt_clock(start) + " · "

    title = title.replace("\n", " ").replace("\t", " ").strip()
    max_label = 44
    max_title = max(6, max_label - len(prefix))
    if len(title) > max_title:
        title = title[: max_title - 1] + "…"
    return prefix + title, remaining


def main() -> None:
    cred_path, token_path = _cred_paths()
    if not token_path.is_file():
        if not cred_path.is_file():
            print("⚠ no credentials file", end="")
            print(f"sketchybar-next-event: {_INSTALL_HINT}", file=sys.stderr)
        else:
            print("⚠ run --auth first", end="")
            print(f"sketchybar-next-event: {_INSTALL_HINT}", file=sys.stderr)
        return

    creds = _load_credentials()
    if creds is None:
        print("⚠ token expired", end="")
        print(f"sketchybar-next-event: token invalid; re-run setup-google-calendar.sh", file=sys.stderr)
        return

    exclude = _load_exclude_set()
    exclude_prefixes = _load_exclude_event_prefixes()
    local_tz = _local_tz()
    now = datetime.now(local_tz)
    try:
        service = build("calendar", "v3", credentials=creds, cache_discovery=False)
        events = _fetch_events_today(service, local_tz, exclude, exclude_prefixes)
        label, count = _pick_label(events, now)
        if count is None:
            print(label, end="")
        else:
            print(f"{label}\t{count}", end="")
    except _CalendarAPIError as e:
        print(e.label, end="")
    except Exception:
        print("sketchybar-next-event: fetch failed:", file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        print("⚠ calendar error", end="")


if __name__ == "__main__":
    if _AUTH_MODE:
        run_oauth_login()
    elif _LIST_MODE:
        list_calendars()
    else:
        main()
    sys.exit(0)
