from __future__ import annotations

import csv
import os
import re
import tempfile
import json
import hashlib
import time
from datetime import datetime, timezone, timedelta
from typing import Dict, List, Optional, Tuple, Set

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
DEFAULT_ARGS = {"owner": "data-platform", "retries": 1}
SCHEDULE_INTERVAL = "0 * * * *"

# Parámetros
BUCKET_NAME = "dn-dbtdp-artif-prd01"
S3_PREFIX = "dags/dbt/nubeproduct/seeds"  # sin slash inicial/final
GOOGLE_CONN_ID = "google_drive_sheets_conn"
ROOT_FOLDER_ID = "1MOn5Z_9Lm4-bWixOmi81s2q-rIYLh6d8"

# Lógica
WRITE_INVENTORY_CSV = True
STATE_VAR = f"gdrive_sync_state__{DAG_ID}"

# Scopes lectura
SCOPES = [
    "https://www.googleapis.com/auth/drive.readonly",
    "https://www.googleapis.com/auth/spreadsheets.readonly",
]

# MIME
FOLDER_MIME = "application/vnd.google-apps.folder"
SHORTCUT_MIME = "application/vnd.google-apps.shortcut"
SPREADSHEET_MIME = "application/vnd.google-apps.spreadsheet"

# ==========================
# Utilidades generales
# ==========================

DEPRECATED_PATTERN = re.compile(r"\s*\[deprecated\]\s*$", re.IGNORECASE)

def is_deprecated_name(name: str) -> bool:
    return bool(DEPRECATED_PATTERN.search(name))

def strip_deprecated_suffix(name: str) -> str:
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
    ap("seeds:")
    ap(f"  - name: {safe_filename(sheet_name)}")
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

# ==========================
# Rate limiter & retries
# ==========================

class QPM:
    """Limitar a N requests por minuto (mínimo seguro 50 para Sheets)."""
    def __init__(self, per_minute: int = 50):
        self.interval = 60.0 / max(1, per_minute)
        self.next_t = 0.0
    def wait(self):
        now = time.monotonic()
        if now < self.next_t:
            time.sleep(self.next_t - now)
        self.next_t = time.monotonic() + self.interval

SHEETS_QPM = QPM(50)

def sheets_call(fn, *args, **kwargs):
    """Envuelve llamadas a Google Sheets con rate limit y backoff ante 429."""
    backoff = 1.0
    for attempt in range(6):  # ~1+2+4+8+16+32 = 63s máx
        try:
            SHEETS_QPM.wait()
            return fn(*args, **kwargs).execute()
        except HttpError as e:
            if e.resp.status == 429:
                time.sleep(backoff)
                backoff *= 2
                continue
            raise
    # Último intento
    SHEETS_QPM.wait()
    return fn(*args, **kwargs).execute()

# ==========================
# Google helpers
# ==========================

def build_services_from_conn(google_conn_id: str):
    conn = BaseHook.get_connection(google_conn_id)
    extra = conn.extra_dejson or {}
    sa_info = extra.get("service_account_json")
    if not sa_info:
        raise RuntimeError(f"La conexión {google_conn_id} no tiene 'service_account_json' en extra")
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
                fields="nextPageToken, files(id, name, mimeType, createdTime, modifiedTime, shortcutDetails)",
            )
            .execute()
        )
        items.extend(resp.get("files", []))
        page_token = resp.get("nextPageToken")
        if not page_token:
            break
    return items

# ==========================
# Sheets light reads (no DATA)
# ==========================

def _find_sheet_title(sheets_service, spreadsheet_id: str, expected_title: str) -> Optional[str]:
    meta = sheets_call(
        sheets_service.spreadsheets().get,
        spreadsheetId=spreadsheet_id,
        fields="sheets(properties(title))",
    )
    for sh in meta.get("sheets", []):
        title = sh.get("properties", {}).get("title", "")
        if title.lower().strip() == expected_title.lower().strip():
            return title
    return None

def get_spreadsheet_approval(sheets_service, spreadsheet_id: str) -> Tuple[str, Optional[str]]:
    try:
        tab = _find_sheet_title(sheets_service, spreadsheet_id, "approval")
        if not tab:
            return "no_approval_tab", None
        resp = sheets_call(
            sheets_service.spreadsheets().values().get,
            spreadsheetId=spreadsheet_id,
            range=f"'{tab}'!B2",
            valueRenderOption="UNFORMATTED_VALUE",
        )
        values = resp.get("values", [])
        if not values or not values[0]:
            return "not_approved", None
        raw = values[0][0]
        if isinstance(raw, bool):
            return ("approved" if raw else "not_approved"), str(raw)
        raw_str = str(raw).strip().lower()
        if raw_str in ("true", "1", "sí", "si"): return "approved", str(raw)
        if raw_str in ("false", "0", "no"): return "not_approved", str(raw)
        return "not_approved", str(raw)
    except Exception:
        return "not_approved", None

def get_checksum_value(sheets_service, spreadsheet_id: str) -> Optional[str]:
    try:
        tab = _find_sheet_title(sheets_service, spreadsheet_id, "checksum")
        if not tab:
            return None
        resp = sheets_call(
            sheets_service.spreadsheets().values().get,
            spreadsheetId=spreadsheet_id,
            range=f"'{tab}'!A2",
            valueRenderOption="UNFORMATTED_VALUE",
        )
        vals = resp.get("values", [])
        if not vals or not vals[0]:
            return None
        return str(vals[0][0])
    except Exception:
        return None

# ==========================
# S3 helpers
# ==========================

def safe_delete_key(s3: S3Hook, key: str, log) -> bool:
    try:
        if not s3.check_for_key(key=key, bucket_name=BUCKET_NAME):
            log.info("S3 delete noop (no existe): s3://%s/%s", BUCKET_NAME, key)
            return False
        s3.delete_objects(bucket=BUCKET_NAME, keys=[key])
        log.info("S3 deleted: s3://%s/%s", BUCKET_NAME, key)
        return True
    except Exception as e:
        log.warning("S3 delete error para %s: %s (continuo)", key, e)
        return False

def s3_key_for_csv(sheet_name: str) -> str:
    return f"{S3_PREFIX}/{safe_filename(sheet_name)}.csv"

def s3_key_for_yml(sheet_name: str) -> str:
    return f"{S3_PREFIX}/{safe_filename(sheet_name)}_seeds.yml"

def s3_key_inventory() -> str:
    return f"{S3_PREFIX}/drive_inventory.csv"

CHECKSUM_S3_KEY = f"{S3_PREFIX}/seeds_checksum.json"

def _read_checksums_from_s3(s3: S3Hook) -> Dict[str, str]:
    try:
        if not s3.check_for_key(key=CHECKSUM_S3_KEY, bucket_name=BUCKET_NAME):
            return {}
        with tempfile.NamedTemporaryFile("w+b", delete=False) as tf:
            tmp = tf.name
        s3.get_conn().download_file(BUCKET_NAME, CHECKSUM_S3_KEY, tmp)
        with open(tmp, "r", encoding="utf-8") as f:
            data = json.load(f)
        os.unlink(tmp)
        if isinstance(data, dict):
            return {str(k): str(v) for k, v in data.items()}
        return {}
    except Exception:
        return {}

def _write_checksums_to_s3(s3: S3Hook, mapping: Dict[str, str]) -> str:
    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as tf:
        json.dump(mapping, tf, ensure_ascii=False, indent=2)
        tmp_path = tf.name
    s3.load_file(filename=tmp_path, key=CHECKSUM_S3_KEY, bucket_name=BUCKET_NAME, replace=True)
    os.unlink(tmp_path)
    return f"s3://{BUCKET_NAME}/{CHECKSUM_S3_KEY}"

# ==========================
# Inventario (opcional)
# ==========================

def export_inventory_to_s3(s3: S3Hook, rows: List[Dict]):
    key = s3_key_inventory()
    # 🔧 Fieldnames incluye display_name
    fieldnames = [
        "path","id","type","createdTime","modifiedTime",
        "approval_status","approval_value",
        "checksum","seed_name","display_name",  # <- agregado
    ]
    # 🔧 Normalizamos filas para evitar claves extra
    normalized = [{k: r.get(k) for k in fieldnames} for r in rows]

    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8", newline="") as tf:
        writer = csv.DictWriter(tf, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(normalized)
        tmp_path = tf.name
    s3.load_file(filename=tmp_path, key=key, bucket_name=BUCKET_NAME, replace=True)
    os.unlink(tmp_path)
    return f"s3://{BUCKET_NAME}/{key}"


# ==========================
# Descubrimiento LIVIANO de aprobados
# ==========================

def discover_approved_seeds(drive, sheets, log) -> List[Dict]:
    """Recorre Drive y devuelve filas SOLO con info mínima (approval+checksum). No lee DATA."""
    def walk(parent_id: str, path_parts: List[str], out_rows: List[Dict], indent: int = 0):
        children = list_children(drive, parent_id)
        children.sort(key=lambda it: (0 if it["mimeType"] == FOLDER_MIME else 1, it["name"].lower()))
        for item in children:
            name = item["name"]; mime = item["mimeType"]; item_id = item["id"]
            created = item.get("createdTime", ""); modified = item.get("modifiedTime", "")

            if mime == FOLDER_MIME:
                log.info("%s📁 %s/", "  " * indent, name)
                walk(item_id, path_parts + [name], out_rows, indent + 1)
                continue

            if mime == SHORTCUT_MIME:
                sd = item.get("shortcutDetails") or {}
                target_id = sd.get("targetId"); target_mime = sd.get("targetMimeType")
                if target_id and target_mime == SPREADSHEET_MIME:
                    display = name
                    if is_deprecated_name(display):
                        continue
                    approval_status, approval_value = get_spreadsheet_approval(sheets, target_id)
                    checksum_value = get_checksum_value(sheets, target_id)
                    out_rows.append({
                        "path": "/".join(path_parts + [display]),
                        "id": target_id,
                        "type": SPREADSHEET_MIME,
                        "createdTime": created,
                        "modifiedTime": modified,
                        "approval_status": approval_status,
                        "approval_value": approval_value,
                        "checksum": checksum_value,
                        "seed_name": safe_filename(display),
                        "display_name": display,
                    })
                continue

            if mime == SPREADSHEET_MIME:
                display = name
                if is_deprecated_name(display):
                    continue
                approval_status, approval_value = get_spreadsheet_approval(sheets, item_id)
                checksum_value = get_checksum_value(sheets, item_id)
                out_rows.append({
                    "path": "/".join(path_parts + [display]),
                    "id": item_id,
                    "type": SPREADSHEET_MIME,
                    "createdTime": created,
                    "modifiedTime": modified,
                    "approval_status": approval_status,
                    "approval_value": approval_value,
                    "checksum": checksum_value,
                    "seed_name": safe_filename(display),
                    "display_name": display,
                })
            else:
                # ignorar otros tipos
                pass

    rows: List[Dict] = []
    walk(ROOT_FOLDER_ID, [], rows, 0)
    return rows

# ==========================
# Materialización (solo seleccionados)
# ==========================

def read_definitions(sheets_service, spreadsheet_id: str) -> Optional[Dict]:
    tab_title = _find_sheet_title(sheets_service, spreadsheet_id, "definitions")
    if not tab_title:
        return None
    def get_cell(rng):
        resp = sheets_call(
            sheets_service.spreadsheets().values().get,
            spreadsheetId=spreadsheet_id,
            range=rng,
            valueRenderOption="UNFORMATTED_VALUE",
        )
        vals = resp.get("values", [])
        return (vals[0][0] if vals and vals[0] else "")
    out: Dict[str, object] = {}
    for key, rng in {
        "domain": f"'{tab_title}'!B1",
        "business_owner": f"'{tab_title}'!B3",
        "tech_steward": f"'{tab_title}'!B4",
        "description": f"'{tab_title}'!B7",
    }.items():
        try:
            out[key] = get_cell(rng)
        except Exception:
            out[key] = ""
    try:
        resp_cols = sheets_call(
            sheets_service.spreadsheets().values().get,
            spreadsheetId=spreadsheet_id,
            range=f"'{tab_title}'!A10:B",
            valueRenderOption="UNFORMATTED_VALUE",
        )
        rows = resp_cols.get("values", [])
    except Exception:
        rows = []
    columns = []
    for r in rows:
        col_name = (r[0].strip() if len(r) >= 1 and isinstance(r[0], str) else r[0] if len(r) >= 1 else "")
        col_desc = (r[1] if len(r) >= 2 else "")
        if col_name is None or str(col_name).strip() == "":
            break
        columns.append({"name": str(col_name).strip(), "description": "" if col_desc is None else str(col_desc)})
    out["columns"] = columns
    return out

def find_data_tab_and_range(sheets_service, spreadsheet_id: str) -> Tuple[Optional[str], Optional[str]]:
    meta = sheets_call(
        sheets_service.spreadsheets().get,
        spreadsheetId=spreadsheet_id,
        fields="sheets(properties(title,gridProperties(rowCount,columnCount)))",
    )
    data_title = None; row_count = None; col_count = None
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
    # Acotá: no bajes todas las columnas gigantes si no hace falta; Z col típico
    last_col_letter = "Z" if col_count > 26 else chr(64 + col_count)
    full_range = f"'{data_title}'!A1:{last_col_letter}{row_count}"
    return data_title, full_range

def download_data_sheet_to_csv(sheets_service, spreadsheet_id: str, data_range: str, out_csv_path: str) -> None:
    resp = sheets_call(
        sheets_service.spreadsheets().values().get,
        spreadsheetId=spreadsheet_id,
        range=data_range,
        valueRenderOption="UNFORMATTED_VALUE",
        dateTimeRenderOption="FORMATTED_STRING",
    )
    values = resp.get("values", [])
    max_cols = max((len(r) for r in values), default=0)
    with open(out_csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        for row in values:
            padded = row + [""] * (max_cols - len(row))
            writer.writerow(padded)

def materialize_one_seed(sheets, s3: S3Hook, file_id: str, display_name: str, log) -> Tuple[str, str, str]:
    """
    Devuelve (seed_name, checksum_final, s3_csv_uri). Calcula MD5 si faltaba checksum.
    """
    seed_name = safe_filename(display_name)

    defs = read_definitions(sheets, file_id) or {"columns": []}
    yml_content = build_seed_yml(display_name, defs)
    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8") as tf:
        tf.write(yml_content)
        tmp_yml_path = tf.name
    key_yml = s3_key_for_yml(display_name)
    s3.load_file(filename=tmp_yml_path, key=key_yml, bucket_name=BUCKET_NAME, replace=True)
    os.unlink(tmp_yml_path)

    data_title, data_range = find_data_tab_and_range(sheets, file_id)
    if not (data_title and data_range):
        # Subí igual el YML; CSV inexistente
        return seed_name, "", f"s3://{BUCKET_NAME}/{key_yml}"

    with tempfile.NamedTemporaryFile("w", delete=False, encoding="utf-8", newline="") as tf:
        tmp_csv_path = tf.name
    download_data_sheet_to_csv(sheets, file_id, data_range, tmp_csv_path)

    # MD5 para fallback (y dejar checksum estable si hoja no lo trae)
    with open(tmp_csv_path, "rb") as fh:
        file_md5 = hashlib.md5(fh.read()).hexdigest()

    key_csv = s3_key_for_csv(display_name)
    s3.load_file(filename=tmp_csv_path, key=key_csv, bucket_name=BUCKET_NAME, replace=True)
    os.unlink(tmp_csv_path)

    return seed_name, file_md5, f"s3://{BUCKET_NAME}/{key_csv}"

# ==========================
# Estado (page token)
# ==========================

def _load_state() -> dict:
    try:
        return Variable.get(STATE_VAR, deserialize_json=True)
    except Exception:
        return {}

def _save_state(state: dict):
    Variable.set(STATE_VAR, state, serialize_json=True)

def _get_start_page_token(drive):
    resp = drive.changes().getStartPageToken(supportsAllDrives=True).execute()
    return resp["startPageToken"]

def _iter_changes(drive, page_token: str):
    all_changes = []
    next_token = page_token
    new_start = None
    while True:
        resp = drive.changes().list(
            pageToken=next_token,
            pageSize=1000,
            includeItemsFromAllDrives=True,
            supportsAllDrives=True,
            fields=("nextPageToken,newStartPageToken,changes(removed,fileId,file(id,name,mimeType,modifiedTime,shortcutDetails/targetId,shortcutDetails/targetMimeType))"),
        ).execute()
        all_changes.extend(resp.get("changes", []))
        new_start = resp.get("newStartPageToken", new_start)
        next_token = resp.get("nextPageToken")
        if not next_token:
            break
    return all_changes, new_start

# ==========================
# Tarea principal
# ==========================

def _task_sync(**context):
    log = context["ti"].log
    s3 = S3Hook()
    drive, sheets = build_services_from_conn(GOOGLE_CONN_ID)

    state = _load_state()
    prev_token = state.get("page_token")

    # 1) Descubrimiento LIVIANO (approval + checksum)
    rows = discover_approved_seeds(drive, sheets, log)

    # 2) Inventario para auditoría (opcional)
    if WRITE_INVENTORY_CSV:
        inv_uri = export_inventory_to_s3(s3, rows)
        log.info("Inventario exportado en: %s", inv_uri)

    # 3) Selección por JSON (faltantes + cambiados; si JSON vacío -> todos)
    prev_checksums = _read_checksums_from_s3(s3)  # {seed_name: checksum}
    approved = [r for r in rows if r.get("approval_status") == "approved" and r.get("seed_name")]
    approved_names: Set[str] = {r["seed_name"] for r in approved}
    curr_checksums_light: Dict[str, str] = {}
    for r in approved:
        if r.get("checksum") is not None:
            curr_checksums_light[r["seed_name"]] = str(r["checksum"])

    if not prev_checksums:
        selected = sorted(approved_names)
    else:
        missing = [sn for sn in approved_names if sn not in prev_checksums]
        changed = [sn for sn, chk in curr_checksums_light.items() if prev_checksums.get(sn) != chk]
        selected = sorted(set(missing) | set(changed))

    log.info("Seleccionados (previo a materializar): %s", " ".join(selected))

    # 4) Materialización SOLO de seleccionados (YML + CSV + MD5 fallback)
    #    Y actualizar JSON con los nuevos checksums (MD5 si faltaba).
    #    Mapeo seed_name -> row
    idx = {r["seed_name"]: r for r in approved}
    new_checksums = dict(prev_checksums)  # copia para actualizar

    for sn in selected:
        r = idx.get(sn)
        if not r:
            continue
        file_id = r["id"]; display = r.get("display_name") or r.get("seed_name")
        try:
            seed_name, md5, _csv_uri = materialize_one_seed(sheets, s3, file_id, display, log)
            # Si la hoja traía checksum, preferilo. Si no, usa MD5 calculado.
            final_checksum = r.get("checksum") or md5 or ""
            if final_checksum:
                new_checksums[seed_name] = final_checksum
        except HttpError as e:
            if e.resp.status == 429:
                log.warning("RATE LIMIT al materializar %s. Reintentará en próximo run. Detalle: %s", sn, e)
                # No abortamos todo; seguimos con los demás
                continue
            raise

    uri_checksums = _write_checksums_to_s3(s3, new_checksums)
    log.info("Checksums guardados en: %s", uri_checksums)

    # 5) Actualizar page token de Drive (para futuras incrementales)
    if not prev_token:
        new_token = _get_start_page_token(drive)
        state.update({"page_token": new_token, "last_run_utc": datetime.now(timezone.utc).isoformat()})
        _save_state(state)
    else:
        _, new_start_token = _iter_changes(drive, prev_token)
        if new_start_token:
            state.update({"page_token": new_start_token, "last_run_utc": datetime.now(timezone.utc).isoformat()})
            _save_state(state)

    return {
        "has_changes": len(selected) > 0,
        "changed_count": len(selected),
        "seed_selection": " ".join(selected),
        "checksums_s3_uri": uri_checksums,
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
                    "threads": 15,
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
    Baja todos los CSV/YML desde S3 al proyecto local,
    EXCEPTUANDO drive_inventory.csv y [deprecated].
    """
    os.makedirs(local_seeds_dir, exist_ok=True)
    s3 = S3Hook()
    keys = s3.list_keys(bucket_name=BUCKET_NAME, prefix=S3_PREFIX) or []
    for k in keys:
        fname = os.path.basename(k)
        name_wo_ext, ext = os.path.splitext(fname)
        if fname == "drive_inventory.csv":
            continue
        if DEPRECATED_PATTERN.search(name_wo_ext):
            continue
        if not (fname.endswith(".csv") or fname.endswith("_seeds.yml")):
            continue
        local_file = os.path.join(local_seeds_dir, fname)
        s3.get_conn().download_file(BUCKET_NAME, k, local_file)

def branch_on_changes(ti):
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

    sync = PythonOperator(
        task_id="sync_gdrive_to_s3",
        python_callable=_task_sync,
    )

    decide = BranchPythonOperator(
        task_id="decide_has_changes",
        python_callable=branch_on_changes,
    )

    no_changes = EmptyOperator(task_id="no_changes")

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
            set -e
            source /usr/local/airflow/python3-virtualenv/dbt-env/bin/activate;
            cd /tmp/dbt/workdir/nubeproduct;
            dbt deps;

            SEED_SELECTION="{{ ti.xcom_pull(task_ids='sync_gdrive_to_s3')['seed_selection'] | default('', true) }}"

            if [ -z "$SEED_SELECTION" ]; then
            echo "No hay seeds a ejecutar (nada faltante ni cambiado).";
            exit 0
            fi

            echo "Ejecutando: dbt seed --full-refresh --select $SEED_SELECTION"
            dbt seed --project-dir . --profiles-dir /tmp/dbt --full-refresh --select $SEED_SELECTION
        """,
    )

    sync >> decide
    decide >> no_changes
    decide >> setup_project
    setup_project >> create_profiles >> pull_seeds >> run_dbt_seeds
