# DBT Core Project Setup (macOS)

This repository provides two convenience scripts to bootstrap a local environment for **dbt Core** with **Databricks** in the `nubeproduct` project. Each script is location‑independent: the project root is inferred as the parent directory of `.setup/`.

* **macOS/Linux:** `.setup/dbt-setup-macos.sh`

The script perform the same high‑level tasks:

1. Optionally run Git operations (`checkout`, `fetch`, `pull`).
2. Recreate the virtual environment at `<project-root>/.venv`.
3. Install `dbt-core==1.10.3` and `dbt-databricks==1.10.3` into the venv.
4. Optionally generate `~/.dbt/profiles.yml` when a Databricks token is provided (via flag/env or entered interactively).
5. Execute `dbt debug` and `dbt deps` inside `nubeproduct/`.

---

## Prerequisites

* **Git** available on PATH (unless Git steps are skipped).
* **Python 3** installed and available on PATH:

  * macOS/Linux: `python3.12`, `python3`, or `python`.

* The scripts will create the **dbt profiles directory** (`~/.dbt/`) when needed.

> **Security**: The Databricks token is written to `~/.dbt/profiles.yml` only if you provide one. Keep that file secure.

---

## Repository Layout

```
<project-root>/
├─ .setup/
│  ├─ dbt-setup-macos.sh
│  └─ dbt-setup-windows.cmd
├─ nubeproduct/
└─ ...
```

> The project root is discovered by resolving the parent of `.setup/`.

---

## Quick Start

1. Make the script executable (first run only):

```bash
chmod +x .setup/dbt-setup-macos.sh
```

2. Run (optional prompt for token; press **Enter** to skip):

```bash
./.setup/dbt-setup-macos.sh
```

---

## Usage & Options

### macOS/Linux script

```bash
./.setup/dbt-setup-macos.sh [options]
```

**Options**

* `--token=XXXX` — Databricks token (otherwise prompted optionally; input hidden).
* `--branch=main|master` — Git branch to checkout (default: `main`).
* `--skip-git` — Skip Git operations.
* `--schema=testing` — Schema to place in `profiles.yml` (default: `testing`).
* `--threads=3` — Thread count for `profiles.yml` (default: `3`).
* `-h`, `--help` — Print usage and exit.

**Environment overrides**

* `DBT_TOKEN`, `DBT_SCHEMA`, `DBT_THREADS`.

**Examples**

```bash
./.setup/dbt-setup-macos.sh
./.setup/dbt-setup-macos.sh --token=XXXX --schema=testing --threads=3
./.setup/dbt-setup-macos.sh --skip-git
```

## Maintenance

* **Upgrading dbt:** Update the pinned versions in both scripts; keep `dbt-core` and `dbt-databricks` aligned.
* **Changing defaults:** Override via env vars/flags or edit the defaults in each script.
* **Cleanup:** Remove `<project-root>/.venv` and/or `~/.dbt/profiles.yml` to reset the local setup.
