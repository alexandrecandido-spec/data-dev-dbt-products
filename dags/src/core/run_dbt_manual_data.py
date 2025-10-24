from __future__ import annotations

import csv
import os
import re
import tempfile
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Tuple

from airflow import DAG
from airflow.operators.python import PythonOperator, BranchPythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.operators.bash import BashOperator
from airflow.utils.dates import days_ago
from airflow.hooks.base import BaseHook
from airflow.providers.amazon.aws.hooks.s3 import S3Hook
from airflow.models import Variable  # Persistencia de estado

# Google API
from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

import yaml

# ==========================
# Configuración del DAG
# ==========================
DAG_ID = "sync_gdrive_manual_data_to_s3_and_seed"
DEFAULT_ARGS = {
    "owner": "data-platform",
    "retries": 1,
}
SCHEDULE_INTERVAL = "*/30 * * * *"

# Parámetros
BUCKET_NAME = "dn-dbtdp-artif-prd01"
S3_PREFIX = "dags/dbt/nubeproduct/seeds"  # sin slash inicial ni final
GOOGLE_CONN_ID = "google_drive_sheets_conn"
ROOT_FOLDER_ID = "1MOn5Z_9Lm4-bWixOmi81s2q-rIYLh6d8"

# Compatibilidad con lógica existente (solo usada en full scan)
RECENT_WINDOW_HOURS = 24
GENERATE_CSV_ONLY_IF_RECENT = False
WRITE_INVENTORY_CSV = True

# Variable de estado para Changes API
STATE_VAR = f"gdrive_sync_state__{DAG_ID}"

# Scopes de solo lectura
SCOPES = [
    "https://www.googleapis.com/auth/drive.readonly",
    "https://www.googleapis.com/auth/spreadsheets.readonly",
]

# MIME types
FOLDER_MIME = "application/vnd.google-apps.folder"
SHORTCUT_MIME = "application/vnd.google-apps.shortcut"
SPREADSHEET_MIME = "application/vnd.google-apps.spreadsheet"

# ==========================
# Utilidades generales
# ==========================

# --- Deprecated helpers ---
DEPRECATED_PATTERN = re.compile(r"\s*\[deprecated\]\s*$", re.IGNORECASE)

def is_deprecated_name(name: str) -> bool:
    return bool(DEPRECATED_PATTERN.search(name))

def strip_deprecated_suffix(name: str) -> str:
    # "Foo [deprecated]" -> "Foo"
    return DEPRECATED_PATTERN.sub("", name).strip()

def safe_filename(name: str) -> str:
    base = re.sub(r"[\\/*?\"<>|:#]", "", name).strip()
    base = re.sub(r"\s+", "_", base)
    return base

def _yaml_escape_double_quoted(s: str) -> str:
    if s is None:
        s = ""
    out = []
    for ch in str(s):
        oc = ord(ch)
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append('\\\\')
        elif ch == "\n":
            out.append('\\n')
        elif ch == "\r":
            out.append('\\r')
        elif ch == "\t":
            out.append('\\t')
        elif oc < 0x20:
            out.append(f"\\x{oc:02x}")
        else:
            out.append(ch)
    return '"' + ''.join(out) + '"'

def build_seed_yml(sheet_name: str, defs: Dict) -> str:
    desc = _yaml_escape_double_quoted(defs.get("description", ""))
    tech = _yaml_escape_double_quoted(defs.get("tech_steward", ""))
    domain = _yaml_escape_double_quoted(defs.get("domain", ""))
    owner = _yaml_escape_double_quoted(defs.get("business_owner", ""))

    lines: List[str] = []
    ap = lines.append
    ap("version: 2")
    ap("models:")
    ap("  - name: " + str(sheet_name))
    ap("    description: " + desc)
    ap("    config:")
    ap("      meta:")
    ap("        tech_steward: " + tech)
    ap("        domain: " + domain)
    ap("        business_owner: " + owner)
    ap("    columns:")
    for c in defs.get("columns", []):
        name = str(c.get("name", ""))
        cdesc = _yaml_escape_double_quoted(c.get("description", ""))
        ap("      - name: " + name)
        ap("        description: " + cdesc)
    return "\n".join(lines) + "\n"

def parse_rfc3339(ts: str) -> Optional[datetime]:
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except Exception:
        return None

def is_recent(modified_time_iso: str, window_hours: int = RECENT_WINDOW_HOURS) -> bool:
    dt = parse_rfc3339(modified_time_iso)
    if not dt:
        return False
    return (datetime.now(timezone.utc) - dt) <= timedelta(hours=window_hours)

# ==========================
# Google helpers
# ==========================

def build_services_from_conn(google_conn_id: str):
    conn = BaseHook.get_connection(google_conn_id)
    extra = conn.extra_dejson or {}
    sa_info = extra.get("service_account_json")
    if not sa_info:
        raise RuntimeError(
            f"La conexión {google_conn_id} no tiene 'service_account_json' en extra"
        )
    creds = Credentials.from_service_account_info(sa_info, scopes=SCOPES)
    drive = build("drive", "v3", credentials=creds)
    sheets = build("sheets", "v4", credentials=creds)
    return drive, sheets

def list_children(drive, parent_id: str) -> List[Dict]:
    items: List[Dict] = []
    page_token = None
    query = f"'{parent_id}' in parents and trashed = false"
    while True:
        resp = (
            drive.files()
            .list(
                q=query,
                pageSize=1000,
                pageToken=page_token,
                includeItemsFromAllDrives=True,
                supportsAllDrives=True,
                corpora="allDrives",
                fields="nextPageToken, files(id, name, mimeType, createdTime, modifiedTime)",
            )
            .execute()
        )
        items.extend(resp.get("files", []))
        page_token = resp.get("nextPageToken")
        if not page_token:
            break
    return items

def get_file_meta(drive, file_id: str, fields: str = "id, name, mimeType, createdTime, modifiedTime"):
    return (
        drive.files()
        .get(fileId=file_id, fields=fields, supportsAllDrives=True)
        .execute()
    )

def resolve_shortcut_target(drive, shortcut_file: Dict) -> Tuple[Optional[str], Optional[str]]:
    try:
        resp = (
            drive.files()
            .get(
                fileId=shortcut_file["id"],
                fields="id, name, mimeType, shortcutDetails",
                supportsAllDrives=True,
            )
            .execute()
        )
        details = resp.get("shortcutDetails")
        if details:
            return details.get("targetId"), details.get("targetMimeType")
    except HttpError:
        pass
    return None, None

# ==========================
# Sheets helpers
# ==========================

def _find_sheet_title(sheets_service, spreadsheet_id: str, expected_title: str) -> Optional[str]:
    meta = (
        sheets_service.spreadsheets()
        .get(spreadsheetId=spreadsheet_id, fields="sheets(properties(title))")
        .execute()
    )
    for sh in meta.get("sheets", []):
        title = sh.get("properties", {}).get("title", "")
        if title.lower().strip() == expected_title.lower().strip():
            return title
    return None

def get_spreadsheet_approval(sheets_service, spreadsheet_id: str) -> Tuple[str, Optional[str]]:
    try:
        tab_title = _find_sheet_title(sheets_service, spreadsheet_id, "approval")
        if not tab_title:
            return "no_approval_tab", None
        resp = (
            sheets_service.spreadsheets()
            .values()
            .get(
                spreadsheetId=spreadsheet_id,
                range=f"'{tab_title}'!B2",
                valueRenderOption="UNFORMATTED_VALUE",
            )
            .execute()
        )
        values = resp.get("values", [])
        if not values or not values[0]:
            return "not_approved", None
        raw = values[0][0]
        if isinstance(raw, bool):
            return ("approved" if raw else "not_approved"), str(raw)
        raw_str = str(raw).strip().lower()
        if raw_str in ("true", "1", "sí", "si"):
            return "approved", str(raw)
        if raw_str in ("false", "0", "no"):
            return "not_approved", str(raw)
        return "not_approved", str(raw)
    except Exception:
        return "not_approved", None

def read_definitions(sheets_service, spreadsheet_id: str) -> Optional[Dict]:
    tab_title = _find_sheet_title(sheets_service, spreadsheet_id, "definitions")
    if not tab_title:
        return None

    single_ranges = {
        "domain": f"'{tab_title}'!B1",
        "business_owner": f"'{tab_title}'!B3",
        "tech_steward": f"'{tab_title}'!B4",
        "description": f"'{tab_title}'!B7",
    }
    out: Dict[str, object] = {}
    for key, rng in single_ranges.items():
        try:
            resp = (
                sheets_service.spreadsheets()
                .values()
                .get(
                    spreadsheetId=spreadsheet_id,
                    range=rng,
                    valueRenderOption="UNFORMATTED_VALUE",
                )
                .execute()
            )
            vals = resp.get("values", [])
            out[key] = (vals[0][0] if vals and vals[0] else "")
        except Exception:
            out[key] = ""

    try:
        resp_cols = (
            sheets_service.spreadsheets()
            .values()
            .get(
                spreadsheetId=spreadsheet_id,
                range=f"'{tab_title}'!A10:B",
                valueRenderOption="UNFORMATTED_VALUE",
            )
            .execute()
        )
        rows = resp_cols.get("values", [])
    except Exception:
        rows = []

    columns = []
    for r in rows:
        col_name = (
            r[0].strip() if len(r) >= 1 and isinstance(r[0], str) else r[0] if len(r) >= 1 else ""
        )
        # col_desc puede ser None
        col_desc = (r[1] if len(r) >= 2 else "")
        if col_name is None or str(col_name).strip() == "":
            break
        columns.append({
            "name": str(col_name).strip(),
            "description": "" if col_desc is None else str(col_desc),
        })

    out["columns"] = columns
    return out

def _column_index_to_letter(idx: int) -> str:
    letters = ""
    while idx > 0:
        idx, rem = divmod(idx - 1, 26)
        letters = chr(65 + rem) + letters
    return letters

def find_data_tab_and_range(sheets_service, spreadsheet_id: str) -> Tuple[Optional[str], Optional[str]]:
    meta = (
        sheets_service.spreadsheets()
        .get(
            spreadsheetId=spreadsheet_id,
            fields="sheets(properties(title,gridProperties(rowCount,columnCount)))",
        )
        .execute()
    )
    data_title = None
    row_count = None
    col_count = None
    for sh in meta.get("sheets", []):
        title = sh.get("properties", {}).get("title", "")
        if title.lower().strip() == "data":
            data_title = title
            gp = sh.get("properties", {}).get("gridProperties", {})
            row_count = gp.get("rowCount", 0)
            col_count = gp.get("columnCount", 0)
            break
    if not data_title or not row_count or not col_count:
        return None, None
    last_col_letter = _column_index_to_letter(col_count)
    full_range = f"'{data_title}'!A1:{last_col_letter}{row_count}"
    return data_title, full_range

def download_data_sheet_to_csv(sheets_service, spreadsheet_id: str, data_range: str, out_csv_path: str) -> None:
    resp = (
        sheets_service.spreadsheets()
        .values()
        .get(
            spreadsheetId=spreadsheet_id,
            range=data_range,
            valueRenderOption="UNFORMATTED_VALUE",
            dateTimeRenderOption="FORMATTED_STRING",
        )
        .execute()
    )
    values = resp.get("values", [])
    max_cols = max((len(r) for r in values), default=0)
    with open(out_csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        for row in values:
            padded = row + [""] * (max_cols - len(row))
            writer.writerow(padded)

# ==========================
# S3 helpers
# ==========================

def safe_delete_key(s3: S3Hook, key: str, log) -> bool:
    try:
        if not s3.check_for_key(key=key, bucket_name=BUCKET_NAME):
            log.info("S3 delete noop (no existe): s3://%s/%s", BUCKET_NAME, key)
            return False
        try:
            s3.delete_objects(bucket=BUCKET_NAME, keys=[key])
            log.info("S3 deleted: s3://%s/%s", BUCKET_NAME, key)
            return True
        except Exception as e:
            log.warning("S3 delete error para %s: %s (continuo)", key, e)
            return False
    except Exception as e:
        log.warning("S3 head/check error para %s: %s (continuo)", key, e)
        return False

def s3_key_for_csv(sheet_name: str) -> str:
    return f"{S3_PREFIX}/{safe_filename(sheet_name)}.csv"

def s3_key_for_yml(sheet_name: str) -> str:
    return f"{S3_PREFIX}/{safe_filename(sheet_name)}_seeds.yml"

def s3_key_inventory() -> str:
    return f"{S3_PREFIX}/drive_inventory.csv"

def delete_seed_pair_for_base_name(s3: S3Hook, base_sheet_name: str, log) -> Tuple[bool, bool]:
    """
    Borra en S3 el par CSV/YML correspondientes al 'base_sheet_name' (sin [deprecated]).
    Devuelve (csv_deleted, yml_deleted).
    """
    key_csv = s3_key_for_csv(base_sheet_name)
    key_yml = s3_key_for_yml(base_sheet_name)
    csv_deleted = safe_delete_key(s3, key_csv, log)
    yml_deleted = safe_delete_key(s3, key_yml, log)
    return csv_deleted, yml_deleted

# ==========================
# Persistencia de estado (Changes API)
# ==========================

def _load_state() -> dict:
    try:
        return Variable.get(STATE_VAR, deserialize_json=True)
    except Exception:
        return {}

def _save_state(state: dict):
    Variable.set(STATE_VAR, state, serialize_json=True)

def _get_start_page_token(drive):
    resp = drive.changes().getStartPageToken(
        supportsAllDrives=True
    ).execute()
    return resp["startPageToken"]

def _iter_changes(drive, page_token: str):
    """
    Itera cambios desde page_token.
    Devuelve (changes, newStartPageToken)
    """
    all_changes = []
    next_token = page_token
    new_start = None

    while True:
        resp = drive.changes().list(
            pageToken=next_token,
            pageSize=1000,
            includeItemsFromAllDrives=True,
            supportsAllDrives=True,
            fields=(
                "nextPageToken,newStartPageToken,"
                "changes(removed,fileId,file(id,name,mimeType,modifiedTime,"
                "shortcutDetails/targetId,shortcutDetails/targetMimeType))"
            ),
        ).execute()

        all_changes.extend(resp.get("changes", []))
        new_start = resp.get("newStartPageToken", new_start)
        next_token = resp.get("nextPageToken")
        if not next_token:
            break

    return all_changes, new_start

def _read_prev_inventory_from_s3(s3: S3Hook) -> dict:
    """
    Carga el inventario anterior (si existe) y arma un map id->name
    para poder borrar seeds cuando se elimina un archivo en Drive.
    """
    key = s3_key_inventory()
    mapping = {}
    try:
        if s3.check_for_key(key=key, bucket_name=BUCKET_NAME):
            with tempfile.NamedTemporaryFile("w+b", delete=False) as tf:
                tmp = tf.name
            s3.get_conn().download_file(BUCKET_NAME, key, tmp)
            with open(tmp, "r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    fid = row.get("id")
                    path = row.get("path", "")
                    name = os.path.basename(path).replace("/", "")
                    if fid:
                        mapping[fid] = name
            os.unlink(tmp)
    except Exception:
        pass
    return mapping

# ==========================
# Núcleo de sincronización (full scan existente)
# ==========================

def walk_and_process(drive, sheets, s3: S3Hook, parent_id: str, path_parts: List[Dict], out_rows: List[Dict], log, indent: int = 0):
    try:
        children = list_children(drive, parent_id)
    except HttpError as e:
        log.error("Error al listar hijos de %s -> %s", parent_id, e)
        return

    children.sort(key=lambda it: (0 if it["mimeType"] == FOLDER_MIME else 1, it["name"].lower()))

    for item in children:
        name = item["name"]
        mime = item["mimeType"]
        item_id = item["id"]
        created = item.get("createdTime", "")
        modified = item.get("modifiedTime", "")

        approval_status = "not_a_spreadsheet"
        approval_value = None
        action_yml = None
        action_yml_path = None
        definitions_ok = None
        action_csv = None
        action_csv_path = None

        if mime == SHORTCUT_MIME:
            target_id, target_mime = resolve_shortcut_target(drive, item)
            log.info("%s- %s [shortcut]", "  " * indent, name)
            if target_id and target_mime == SPREADSHEET_MIME:
                try:
                    target_meta = get_file_meta(drive, target_id, fields="id,name,mimeType,modifiedTime")
                    target_modified = target_meta.get("modifiedTime", "")
                except Exception:
                    target_modified = ""

                # manejar [deprecated] por nombre del atajo
                if is_deprecated_name(name):
                    base_name = strip_deprecated_suffix(name)
                    csv_deleted, yml_deleted = delete_seed_pair_for_base_name(s3, base_name, log)
                    out_rows.append({
                        "path": "/".join(path_parts + [name]),
                        "id": target_id,
                        "type": SPREADSHEET_MIME,
                        "createdTime": created,
                        "modifiedTime": modified,
                        "approval_status": "skipped_deprecated",
                        "approval_value": None,
                        "action_yml": "deleted_yaml_due_to_deprecated" if yml_deleted else "noop_base_yaml_missing_due_to_deprecated",
                        "action_yml_path": f"s3://{BUCKET_NAME}/{s3_key_for_yml(base_name)}" if yml_deleted else None,
                        "definitions_ok": None,
                        "action_csv": "deleted_csv_due_to_deprecated" if csv_deleted else "noop_base_csv_missing_due_to_deprecated",
                        "action_csv_path": f"s3://{BUCKET_NAME}/{s3_key_for_csv(base_name)}" if csv_deleted else None,
                    })
                    continue

                recent = is_recent(target_modified)
                approval_status, approval_value = get_spreadsheet_approval(sheets, target_id)

                if approval_status == "approved":
                    defs = read_definitions(sheets, target_id)
                    if defs and defs.get("columns"):
                        yml_content = build_seed_yml(name, defs)
                        key_yml = s3_key_for_yml(name)
                        with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as tf:
                            tf.write(yml_content)
                            tmp_yml_path = tf.name
                        s3.load_file(filename=tmp_yml_path, key=key_yml, bucket_name=BUCKET_NAME, replace=True)
                        os.unlink(tmp_yml_path)
                        action_yml = "uploaded_yaml"
                        action_yml_path = f"s3://{BUCKET_NAME}/{key_yml}"
                        definitions_ok = True
                    else:
                        action_yml = "skipped_missing_definitions"
                        definitions_ok = False

                    if (not GENERATE_CSV_ONLY_IF_RECENT) or recent:
                        data_title, data_range = find_data_tab_and_range(sheets, target_id)
                        if data_title and data_range:
                            with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8", newline="") as tf:
                                tmp_csv_path = tf.name
                            download_data_sheet_to_csv(sheets, target_id, data_range, tmp_csv_path)
                            key_csv = s3_key_for_csv(name)
                            s3.load_file(filename=tmp_csv_path, key=key_csv, bucket_name=BUCKET_NAME, replace=True)
                            os.unlink(tmp_csv_path)
                            action_csv = "uploaded_csv"
                            action_csv_path = f"s3://{BUCKET_NAME}/{key_csv}"
                        else:
                            action_csv = "skipped_no_data_tab"
                    else:
                        action_csv = "noop_not_recent"
                else:
                    key_yml = s3_key_for_yml(name)
                    if safe_delete_key(s3, key_yml, log):
                        action_yml = "deleted_yaml"
                        action_yml_path = f"s3://{BUCKET_NAME}/{key_yml}"
                    else:
                        action_yml = "noop_unapproved"
                    if is_recent(target_modified):
                        key_csv = s3_key_for_csv(name)
                        if safe_delete_key(s3, key_csv, log):
                            action_csv = "deleted_csv"
                            action_csv_path = f"s3://{BUCKET_NAME}/{key_csv}"
                        else:
                            action_csv = "noop_unapproved_not_recent_or_missing"
                    else:
                        action_csv = "noop_not_recent"

        elif mime == FOLDER_MIME:
            log.info("%s📁 %s/", "  " * indent, name)
            out_rows.append({
                "path": "/".join(path_parts + [name]) + "/",
                "id": item_id,
                "type": "folder",
                "createdTime": created,
                "modifiedTime": modified,
                "approval_status": approval_status,
                "approval_value": approval_value,
                "action_yml": action_yml,
                "action_yml_path": action_yml_path,
                "definitions_ok": definitions_ok,
                "action_csv": action_csv,
                "action_csv_path": action_csv_path,
            })
            walk_and_process(drive, sheets, s3, item_id, path_parts + [name], out_rows, log, indent + 1)
            continue

        else:
            if mime == SPREADSHEET_MIME:
                # manejar [deprecated] por nombre de hoja
                if is_deprecated_name(name):
                    base_name = strip_deprecated_suffix(name)
                    csv_deleted, yml_deleted = delete_seed_pair_for_base_name(s3, base_name, log)
                    out_rows.append({
                        "path": "/".join(path_parts + [name]),
                        "id": item_id,
                        "type": mime,
                        "createdTime": created,
                        "modifiedTime": modified,
                        "approval_status": "skipped_deprecated",
                        "approval_value": None,
                        "action_yml": "deleted_yaml_due_to_deprecated" if yml_deleted else "noop_base_yaml_missing_due_to_deprecated",
                        "action_yml_path": f"s3://{BUCKET_NAME}/{s3_key_for_yml(base_name)}" if yml_deleted else None,
                        "definitions_ok": None,
                        "action_csv": "deleted_csv_due_to_deprecated" if csv_deleted else "noop_base_csv_missing_due_to_deprecated",
                        "action_csv_path": f"s3://{BUCKET_NAME}/{s3_key_for_csv(base_name)}" if csv_deleted else None,
                    })
                    continue

                recent = is_recent(modified)
                approval_status, approval_value = get_spreadsheet_approval(sheets, item_id)

                if approval_status == "approved":
                    defs = read_definitions(sheets, item_id)
                    if defs and defs.get("columns"):
                        yml_content = build_seed_yml(name, defs)
                        key_yml = s3_key_for_yml(name)
                        with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as tf:
                            tf.write(yml_content)
                            tmp_yml_path = tf.name
                        s3.load_file(filename=tmp_yml_path, key=key_yml, bucket_name=BUCKET_NAME, replace=True)
                        os.unlink(tmp_yml_path)
                        action_yml = "uploaded_yaml"
                        action_yml_path = f"s3://{BUCKET_NAME}/{key_yml}"
                        definitions_ok = True
                    else:
                        action_yml = "skipped_missing_definitions"
                        definitions_ok = False

                    if (not GENERATE_CSV_ONLY_IF_RECENT) or recent:
                        data_title, data_range = find_data_tab_and_range(sheets, item_id)
                        if data_title and data_range:
                            with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8", newline="") as tf:
                                tmp_csv_path = tf.name
                            download_data_sheet_to_csv(sheets, item_id, data_range, tmp_csv_path)
                            key_csv = s3_key_for_csv(name)
                            s3.load_file(filename=tmp_csv_path, key=key_csv, bucket_name=BUCKET_NAME, replace=True)
                            os.unlink(tmp_csv_path)
                            action_csv = "uploaded_csv"
                            action_csv_path = f"s3://{BUCKET_NAME}/{key_csv}"
                        else:
                            action_csv = "skipped_no_data_tab"
                    else:
                        action_csv = "noop_not_recent"
                else:
                    key_yml = s3_key_for_yml(name)
                    if s3.check_for_key(key=key_yml, bucket_name=BUCKET_NAME):
                        s3.delete_objects(bucket=BUCKET_NAME, keys=[key_yml])
                        action_yml = "deleted_yaml"
                        action_yml_path = f"s3://{BUCKET_NAME}/{key_yml}"
                    else:
                        action_yml = "noop_unapproved"

                    if recent:
                        key_csv = s3_key_for_csv(name)
                        if safe_delete_key(s3, key_csv, log):
                            action_csv = "deleted_csv"
                            action_csv_path = f"s3://{BUCKET_NAME}/{key_csv}"
                        else:
                            action_csv = "noop_unapproved_not_recent_or_missing"
                    else:
                        action_csv = "noop_not_recent"

            log.info("%s📄 %s", "  " * indent, name)

        out_rows.append({
            "path": "/".join(path_parts + [name]),
            "id": item_id,
            "type": mime,
            "createdTime": created,
            "modifiedTime": modified,
            "approval_status": approval_status,
            "approval_value": approval_value,
            "action_yml": action_yml,
            "action_yml_path": action_yml_path,
            "definitions_ok": definitions_ok,
            "action_csv": action_csv,
            "action_csv_path": action_csv_path,
        })

# ==========================
# Export inventario
# ==========================

def export_inventory_to_s3(s3: S3Hook, rows: List[Dict]):
    key = s3_key_inventory()
    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8", newline="") as tf:
        writer = csv.DictWriter(
            tf,
            fieldnames=[
                "path",
                "id",
                "type",
                "createdTime",
                "modifiedTime",
                "approval_status",
                "approval_value",
                "action_yml",
                "action_yml_path",
                "definitions_ok",
                "action_csv",
                "action_csv_path",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)
        tmp_path = tf.name
    s3.load_file(filename=tmp_path, key=key, bucket_name=BUCKET_NAME, replace=True)
    os.unlink(tmp_path)
    return f"s3://{BUCKET_NAME}/{key}"

# ==========================
# Utilitario para procesar spreadsheets (reuso)
# ==========================

def _process_spreadsheet_like(sheets, s3: S3Hook, file_id: str, display_name: str,
                              approval_status: str, approval_value: Optional[str],
                              out_rows: List[Dict], log):

    action_yml = None
    action_yml_path = None
    definitions_ok = None
    action_csv = None
    action_csv_path = None

    if is_deprecated_name(display_name):
        base_name = strip_deprecated_suffix(display_name)
        csv_deleted, yml_deleted = delete_seed_pair_for_base_name(s3, base_name, log)
        out_rows.append({
            "path": display_name,
            "id": file_id,
            "type": SPREADSHEET_MIME,
            "createdTime": "",
            "modifiedTime": "",
            "approval_status": "skipped_deprecated",
            "approval_value": None,
            "action_yml": "deleted_yaml_due_to_deprecated" if yml_deleted else "noop_base_yaml_missing_due_to_deprecated",
            "action_yml_path": f"s3://{BUCKET_NAME}/{s3_key_for_yml(base_name)}" if yml_deleted else None,
            "definitions_ok": None,
            "action_csv": "deleted_csv_due_to_deprecated" if csv_deleted else "noop_base_csv_missing_due_to_deprecated",
            "action_csv_path": f"s3://{BUCKET_NAME}/{s3_key_for_csv(base_name)}" if csv_deleted else None,
        })
        return

    if approval_status == "approved":
        defs = read_definitions(sheets, file_id)
        if defs and defs.get("columns"):
            yml_content = build_seed_yml(display_name, defs)
            key_yml = s3_key_for_yml(display_name)
            with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as tf:
                tf.write(yml_content)
                tmp_yml_path = tf.name
            s3.load_file(filename=tmp_yml_path, key=key_yml, bucket_name=BUCKET_NAME, replace=True)
            os.unlink(tmp_yml_path)
            action_yml = "uploaded_yaml"
            action_yml_path = f"s3://{BUCKET_NAME}/{key_yml}"
            definitions_ok = True
        else:
            action_yml = "skipped_missing_definitions"
            definitions_ok = False

        data_title, data_range = find_data_tab_and_range(sheets, file_id)
        if data_title and data_range:
            with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8", newline="") as tf:
                tmp_csv_path = tf.name
            download_data_sheet_to_csv(sheets, file_id, data_range, tmp_csv_path)
            key_csv = s3_key_for_csv(display_name)
            s3.load_file(filename=tmp_csv_path, key=key_csv, bucket_name=BUCKET_NAME, replace=True)
            os.unlink(tmp_csv_path)
            action_csv = "uploaded_csv"
            action_csv_path = f"s3://{BUCKET_NAME}/{key_csv}"
        else:
            action_csv = "skipped_no_data_tab"
    else:
        key_yml = s3_key_for_yml(display_name)
        if safe_delete_key(s3, key_yml, log):
            action_yml = "deleted_yaml"
            action_yml_path = f"s3://{BUCKET_NAME}/{key_yml}"
        else:
            action_yml = "noop_unapproved"

        key_csv = s3_key_for_csv(display_name)
        if safe_delete_key(s3, key_csv, log):
            action_csv = "deleted_csv"
            action_csv_path = f"s3://{BUCKET_NAME}/{key_csv}"
        else:
            action_csv = "noop_unapproved_not_recent_or_missing"

    out_rows.append({
        "path": display_name,
        "id": file_id,
        "type": SPREADSHEET_MIME,
        "createdTime": "",
        "modifiedTime": "",
        "approval_status": approval_status,
        "approval_value": approval_value,
        "action_yml": action_yml,
        "action_yml_path": action_yml_path,
        "definitions_ok": definitions_ok,
        "action_csv": action_csv,
        "action_csv_path": action_csv_path,
    })

# ==========================
# Tarea principal (sync) — Changes API + logs “desde cuándo”
# ==========================

def _task_sync(**context):
    log = context["ti"].log
    s3 = S3Hook()
    drive, sheets = build_services_from_conn(GOOGLE_CONN_ID)

    state = _load_state()
    prev_token = state.get("page_token")
    last_run_utc_iso = state.get("last_run_utc")

    # Logs claros sobre "desde cuándo"
    if not prev_token:
        log.info("Primera ejecución: escaneo completo y seteo de startPageToken (no hay 'desde cuándo').")
    else:
        log.info("Ejecución incremental desde page_token=%s", prev_token)
        if last_run_utc_iso:
            try:
                last_run_dt = parse_rfc3339(last_run_utc_iso)
            except Exception:
                last_run_dt = None
            if last_run_dt:
                overlap_dt = last_run_dt - timedelta(minutes=15)
                log.info("Última ejecución registrada (UTC): %s", last_run_dt.isoformat())
                log.info("Tomando novedades ocurridas >= %s (UTC) (referencia: última ejecución - 15m).", overlap_dt.isoformat())
            else:
                log.info("No se pudo parsear last_run_utc guardado (%s); se continúa solo con pageToken.", last_run_utc_iso)
        else:
            log.info("No hay last_run_utc guardado; se continúa solo con pageToken.")

    rows: List[Dict] = []

    if not prev_token:
        # Primera ejecución: escaneo completo y seteo token para la próxima
        walk_and_process(
            drive=drive,
            sheets=sheets,
            s3=s3,
            parent_id=ROOT_FOLDER_ID,
            path_parts=[],
            out_rows=rows,
            log=log,
            indent=0,
        )
        new_token = _get_start_page_token(drive)
        log.info("Inicializando page_token=%s", new_token)
        state.update({
            "page_token": new_token,
            "last_run_utc": datetime.now(timezone.utc).isoformat(),
        })
        _save_state(state)
    else:
        # Corrida incremental: solo cambios desde prev_token (creación/modificación/eliminación)
        changes, new_start_token = _iter_changes(drive, prev_token)

        # Mapa id->nombre previo (para deletions)
        prev_inventory_map = _read_prev_inventory_from_s3(s3)

        for ch in changes:
            removed = ch.get("removed", False)
            file_obj = ch.get("file") or {}
            fid = ch.get("fileId") or file_obj.get("id")

            if removed:
                # Buscar nombre previo para borrar seeds en S3
                name = prev_inventory_map.get(fid)
                if name:
                    base_name = strip_deprecated_suffix(name)
                    csv_deleted, yml_deleted = delete_seed_pair_for_base_name(s3, base_name, log)
                    rows.append({
                        "path": f"(deleted)/{name}",
                        "id": fid,
                        "type": "deleted",
                        "createdTime": "",
                        "modifiedTime": "",
                        "approval_status": "n/a",
                        "approval_value": None,
                        "action_yml": "deleted_yaml" if yml_deleted else "noop_unapproved_not_recent_or_missing",
                        "action_yml_path": f"s3://{BUCKET_NAME}/{s3_key_for_yml(base_name)}" if yml_deleted else None,
                        "definitions_ok": None,
                        "action_csv": "deleted_csv" if csv_deleted else "noop_unapproved_not_recent_or_missing",
                        "action_csv_path": f"s3://{BUCKET_NAME}/{s3_key_for_csv(base_name)}" if csv_deleted else None,
                    })
                else:
                    log.info("Archivo eliminado (id=%s) sin nombre previo en inventario; no se pudo mapear seeds.", fid)
                continue

            # No eliminado: procesar el cambio según tipo
            mime = file_obj.get("mimeType", "")
            name = file_obj.get("name", "")

            # Shortcut apuntando a spreadsheet
            if mime == SHORTCUT_MIME:
                sd = (file_obj.get("shortcutDetails") or {})
                target_id = sd.get("targetId")
                target_mime = sd.get("targetMimeType")
                if target_id and target_mime == SPREADSHEET_MIME:
                    approval_status, approval_value = get_spreadsheet_approval(sheets, target_id)
                    _process_spreadsheet_like(
                        sheets=sheets, s3=s3, file_id=target_id, display_name=name,
                        approval_status=approval_status, approval_value=approval_value,
                        out_rows=rows, log=log
                    )
                else:
                    rows.append({
                        "path": name,
                        "id": fid,
                        "type": mime,
                        "createdTime": "",
                        "modifiedTime": file_obj.get("modifiedTime", ""),
                        "approval_status": "not_a_spreadsheet",
                        "approval_value": None,
                        "action_yml": None,
                        "action_yml_path": None,
                        "definitions_ok": None,
                        "action_csv": None,
                        "action_csv_path": None,
                    })
                continue

            if mime == SPREADSHEET_MIME:
                approval_status, approval_value = get_spreadsheet_approval(sheets, file_obj["id"])
                _process_spreadsheet_like(
                    sheets=sheets, s3=s3, file_id=file_obj["id"], display_name=name,
                    approval_status=approval_status, approval_value=approval_value,
                    out_rows=rows, log=log
                )
                continue

            # Otros tipos: solo loguear
            rows.append({
                "path": name,
                "id": fid,
                "type": mime,
                "createdTime": "",
                "modifiedTime": file_obj.get("modifiedTime", ""),
                "approval_status": "not_a_spreadsheet",
                "approval_value": None,
                "action_yml": None,
                "action_yml_path": None,
                "definitions_ok": None,
                "action_csv": None,
                "action_csv_path": None,
            })

        # Al finalizar cambios, actualizar token y loguear el cambio
        if new_start_token:
            log.info("Actualizando page_token: %s -> %s", prev_token, new_start_token)
            state.update({
                "page_token": new_start_token,
                "last_run_utc": datetime.now(timezone.utc).isoformat(),
            })
            _save_state(state)

    # Inventario actualizado y detección de novedades
    if WRITE_INVENTORY_CSV:
        inv_uri = export_inventory_to_s3(s3, rows)
        log.info("Inventario exportado en: %s", inv_uri)

    change_actions = {
        "uploaded_csv", "deleted_csv",
        "uploaded_yaml", "deleted_yaml",
        "deleted_csv_due_to_deprecated", "deleted_yaml_due_to_deprecated",
    }
    changed_rows = [r for r in rows if (r.get("action_csv") in change_actions) or (r.get("action_yml") in change_actions)]
    has_changes = len(changed_rows) > 0
    log.info("Novedades detectadas: %s (registros cambiados: %d)", has_changes, len(changed_rows))

    return {
        "has_changes": has_changes,
        "changed_count": len(changed_rows),
    }

# ==========================
# Helpers para la parte dbt
# ==========================

def create_profiles_yml():
    dbt_conn = BaseHook.get_connection("dbt_profiles")
    profiles_config = {
        "nubeproduct": {
            "outputs": {
                "prod": {
                    "catalog": "data_products_prd",
                    "host": dbt_conn.host,
                    "http_path": "/sql/1.0/warehouses/2f8b52bf3d2088a2",
                    "schema": "data",
                    "threads": 4,
                    "token": dbt_conn.password,
                    "type": "databricks",
                }
            },
            "target": "prod",
        }
    }
    os.makedirs("/tmp/dbt", exist_ok=True)
    with open("/tmp/dbt/profiles.yml", "w") as f:
        yaml.dump(profiles_config, f, default_flow_style=False)

def download_seeds_from_s3(local_seeds_dir: str = "/tmp/dbt/workdir/nubeproduct/seeds"):
    """
    Baja todos los CSV/YML de seeds desde S3 al proyecto local,
    EXCEPTUANDO drive_inventory.csv y cualquier nombre marcado como [deprecated].
    """
    os.makedirs(local_seeds_dir, exist_ok=True)
    s3 = S3Hook()

    keys = s3.list_keys(bucket_name=BUCKET_NAME, prefix=S3_PREFIX) or []
    for k in keys:
        fname = os.path.basename(k)
        name_wo_ext, ext = os.path.splitext(fname)

        # Excluir inventario y deprecated
        if fname == "drive_inventory.csv":
            continue
        if DEPRECATED_PATTERN.search(name_wo_ext):
            continue

        # Solo seeds válidos
        if not (fname.endswith(".csv") or fname.endswith("_seeds.yml")):
            continue

        local_file = os.path.join(local_seeds_dir, fname)
        s3.get_conn().download_file(BUCKET_NAME, k, local_file)

def branch_on_changes(ti):
    """
    Lee XCom de sync_gdrive_to_s3 y decide a dónde ir.
    """
    x = ti.xcom_pull(task_ids="sync_gdrive_to_s3")
    has_changes = bool(x and x.get("has_changes"))
    return "prepare_seed_chain" if has_changes else "no_changes"

# ==========================
# Definición del DAG y dependencias
# ==========================

with DAG(
    dag_id=DAG_ID,
    default_args=DEFAULT_ARGS,
    schedule_interval=SCHEDULE_INTERVAL,
    start_date=days_ago(1),
    catchup=False,
    tags=["gdrive", "manual-data", "s3", "dbt", "seeds"],
) as dag:

    # 1) Sync GDrive -> S3 (ahora con Changes API + logs “desde cuándo”)
    sync = PythonOperator(
        task_id="sync_gdrive_to_s3",
        python_callable=_task_sync,
    )

    # 2) Branch según novedades
    decide = BranchPythonOperator(
        task_id="decide_has_changes",
        python_callable=branch_on_changes,
    )

    no_changes = EmptyOperator(task_id="no_changes")

    # Cadena de preparación para correr dbt seeds
    setup_project = BashOperator(
        task_id="prepare_seed_chain",
        bash_command="""
            rm -rf /tmp/dbt/workdir/nubeproduct;
            mkdir -p /tmp/dbt/workdir/nubeproduct;
            cp -R /usr/local/airflow/dags/dbt/nubeproduct/* /tmp/dbt/workdir/nubeproduct/;
        """,
    )

    create_profiles = PythonOperator(
        task_id="create_profiles",
        python_callable=create_profiles_yml,
    )

    pull_seeds = PythonOperator(
        task_id="pull_seeds_from_s3",
        python_callable=download_seeds_from_s3,
    )

    run_dbt_seeds = BashOperator(
        task_id="run_dbt_seeds",
        bash_command="""
            source /usr/local/airflow/python3-virtualenv/dbt-env/bin/activate;
            cd /tmp/dbt/workdir/nubeproduct;
            dbt deps;
            dbt seed --project-dir . --profiles-dir /tmp/dbt;
        """,
    )

    # Dependencias
    sync >> decide
    decide >> no_changes
    decide >> setup_project
    setup_project >> create_profiles >> pull_seeds >> run_dbt_seeds
