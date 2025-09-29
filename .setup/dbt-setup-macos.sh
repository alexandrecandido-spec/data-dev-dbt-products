#!/usr/bin/env bash
# macOS setup for dbt Core (Databricks) — asks token optionally
# Location: .setup/dbt-setup-macos.sh
# Safe for direct execution or "source" in bash/zsh

set -u

# ========= Utilities =========
SUMMARY=""
STEP_START=0
STEP_DESC=""

# log prints a timestamped message to stdout; accepts an optional message argument and prints the timestamp followed by the message.
log() {
  local msg="${1:-}"
  printf "[%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$msg"
}

# start_step records a step description, captures the current start time in SECONDS, and logs the step start message.
start_step() {
  STEP_DESC="${1:-}"
  STEP_START=$SECONDS
  log "$STEP_DESC..."
}

# end_step appends the current step description and its elapsed time in seconds to SUMMARY with a checkmark.
end_step() {
  local duration=$((SECONDS - STEP_START))
  SUMMARY="${SUMMARY}\n${STEP_DESC} ✅ (${duration}s)"
}

# Detect if sourced
__SOURCED=0
( return 0 2>/dev/null ) && __SOURCED=1

# die logs an error message and exits with status 1, or returns 1 when the script is sourced.
die() {
  log "❌ ${1:-Unknown error}"
  if [ "$__SOURCED" -eq 1 ]; then
    return 1
  else
    exit 1
  fi
}

# ========= Resolve project root based on this script location =========
# Expected structure: <project-root>/.setup/dbt-setup-macos.sh
SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

[ -d "$PROJECT_ROOT/.git" ] || log "ℹ️ Warning: .git not found at $PROJECT_ROOT (continuing)"
[ -d "$PROJECT_ROOT/nubeproduct" ] || log "ℹ️ Warning: nubeproduct/ not found at $PROJECT_ROOT (continuing)"

# ========= Defaults & CLI flags =========
DBT_TOKEN="${DBT_TOKEN:-}"       # may be set via env or --token
TARGET_BRANCH="main"             # override with --branch
SKIP_GIT=0                       # --skip-git
DBT_SCHEMA="${DBT_SCHEMA:-testing}"
DBT_THREADS="${DBT_THREADS:-3}"

# print_usage prints the usage help text and available CLI options for the dbt macOS setup script.
print_usage() {
  cat <<'USAGE'
Usage: ./.setup/dbt-setup-macos.sh [options]

Options:
  --token=XXXX           Databricks personal access token (or set DBT_TOKEN env)
  --branch=main|master   Git branch to checkout (default: main)
  --skip-git             Skip git checkout/fetch/pull
  --schema=testing       Schema for dbt profile (default: testing)
  --threads=3            Threads for dbt profile (default: 3)
  -h, --help             Show this help

Notes:
  • If no token is provided via flag/env, you'll be asked optionally at runtime.
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --token=*)     DBT_TOKEN="${arg#*=}";;
    --branch=*)    TARGET_BRANCH="${arg#*=}";;
    --skip-git)    SKIP_GIT=1;;
    --schema=*)    DBT_SCHEMA="${arg#*=}";;
    --threads=*)   DBT_THREADS="${arg#*=}";;
    -h|--help)     print_usage; exit 0;;
    *)             log "⚠️  Unknown option: $arg"; print_usage; die "Invalid option";;
  esac
done

# ========= Optional token prompt =========
# Only ask if not provided via flag/env. Input is hidden, ENTER to skip.
if [ -z "${DBT_TOKEN:-}" ]; then
  printf "🔑 Databricks personal access token (optional, leave blank to skip): "
  # read silently if supported; fall back to normal read
  if read -r -s _maybe_token; then
    echo
    DBT_TOKEN="$_maybe_token"
    unset _maybe_token
  else
    echo
  fi
fi

log "🚀 Starting project setup at $PROJECT_ROOT"

# ========= Git ops (optional) =========
if [ "$SKIP_GIT" -eq 0 ]; then
  start_step "🌿 Switching to branch '$TARGET_BRANCH'"
  cd "$PROJECT_ROOT" 2>/dev/null || die "Could not access $PROJECT_ROOT"
  git checkout "$TARGET_BRANCH" 2>/dev/null || die "Git: could not checkout $TARGET_BRANCH"
  end_step

  start_step "🔄 Fetching remote updates"
  git fetch origin || die "Git fetch failed"
  end_step

  start_step "⬇️ Pulling latest changes"
  git pull || die "Git pull failed"
  end_step
else
  log "⏭️  Skipping git operations (--skip-git)"
fi

# ========= Python / venv =========
start_step "🧹 Removing old virtual environment (.venv)"
rm -rf "$PROJECT_ROOT/.venv"
end_step

start_step "🐍 Creating new virtual environment"
PY_BIN="$(command -v python3.12 || command -v python3 || command -v python || true)"
[ -z "${PY_BIN:-}" ] && die "Python 3 not found."
"$PY_BIN" -m venv "$PROJECT_ROOT/.venv" || die "Failed to create virtual environment"
# shellcheck source=/dev/null
. "$PROJECT_ROOT/.venv/bin/activate" || die "Failed to activate virtual environment"
python -m pip install --upgrade pip >/dev/null 2>&1
end_step

start_step "📦 Installing dbt-core and dbt-databricks (Core only)"
python -m pip install "dbt-core==1.10.3" "dbt-databricks==1.10.3" || die "Pip install failed"
end_step

# ========= Force dbt from venv (avoid Fusion) =========
unalias dbt 2>/dev/null || true
hash -r 2>/dev/null || true
DBT="$PROJECT_ROOT/.venv/bin/dbt"

"$DBT" --version || die "dbt not found in venv (expected at $DBT)"

# ========= profiles.yml (created only if token is present) =========
if [ -n "${DBT_TOKEN:-}" ]; then
  start_step "📝 Creating dbt profile at ~/.dbt/profiles.yml"
  mkdir -p "$HOME/.dbt" || die "Could not create ~/.dbt directory"
  cat > "$HOME/.dbt/profiles.yml" <<EOL
nubeproduct:
  outputs:
    dev:
      catalog: hive_metastore
      host: dbc-dd2db5df-9953.cloud.databricks.com
      http_path: /sql/1.0/warehouses/fa8c9959249110a9
      schema: ${DBT_SCHEMA}
      threads: ${DBT_THREADS}
      token: ${DBT_TOKEN}
      type: databricks
  target: dev
EOL
  end_step
else
  SUMMARY="${SUMMARY}\n⚠️ No Databricks token provided → profiles.yml not created"
fi

# ========= dbt =========
start_step "🔍 Running dbt debug (Core)"
cd "$PROJECT_ROOT/nubeproduct" 2>/dev/null || die "Could not access $PROJECT_ROOT/nubeproduct"
"$DBT" debug || die "dbt debug failed"
end_step

start_step "📥 Running dbt deps (Core)"
"$DBT" deps || die "dbt deps failed"
end_step

# ========= Summary =========
log "✅ Setup completed successfully 🎉"

printf "\n\n================== SUMMARY ==================\n"
printf "%b\n" "$SUMMARY"
printf "=============================================\n\n"
printf "👉 Virtual env is ACTIVE in this shell.\n"
printf "   To deactivate later, run: deactivate\n"