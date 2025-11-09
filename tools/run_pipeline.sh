#!/usr/bin/env bash
set -euo pipefail
PROJECT="/data/data/com.termux/files/home/starlab2"
source /root/miniforge/etc/profile.d/conda.sh
conda activate starlab311
cd "$PROJECT"

# Dependencias suaves (pdf, excel, html→pdf opcional)
python - <<'PY'
import sys, subprocess
pkgs = ["pdfplumber","tabula-py","pandas","openpyxl","jinja2","xlrd","XlsxWriter"]
# instalación ligera y silenciosa
subprocess.run([sys.executable,"-m","pip","install","--quiet","--no-input","--disable-pip-version-check","--no-color","--no-python-version-warning",*pkgs], check=False)
PY

# wkhtmltopdf opcional (para PDF bonitos). Si no está, seguimos.
if ! command -v wkhtmltopdf >/dev/null 2>&1; then
  apt-get update -y >/dev/null 2>&1 || true
  apt-get install -y wkhtmltopdf >/dev/null 2>&1 || true
fi

python tools/pipeline_vtm_talixo.py
