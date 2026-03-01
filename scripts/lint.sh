#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )/.." &> /dev/null && pwd )"
BIN_DIR="${HOME}/.local/bin"

PATH="${BIN_DIR}:${PATH}"

if ! command -v ruff >/dev/null; then
  echo "Ruff não encontrado. Instale com 'python3 -m pip install --user ruff' ou 'pip install -r requirements-dev.txt'." >&2
  exit 1
fi

echo "== Ruff =="
ruff check "${ROOT_DIR}/lambda_src" "${ROOT_DIR}/tests"

echo "== Ruff Format (check mode) =="
ruff format --check "${ROOT_DIR}/lambda_src" "${ROOT_DIR}/tests"

