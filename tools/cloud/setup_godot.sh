#!/usr/bin/env bash
# Installs Godot (headless-capable Linux build) for cloud sessions.
# Runs from the SessionStart hook; locally it does nothing unless FORCE_GODOT_SETUP=1.
set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.7-stable}"
INSTALL_DIR="${HOME}/.local/bin"
GODOT_BIN="${INSTALL_DIR}/godot"

if [[ "${CLAUDE_CODE_REMOTE:-}" != "true" && "${FORCE_GODOT_SETUP:-}" != "1" ]]; then
  exit 0
fi

if [[ ! -x "${GODOT_BIN}" ]]; then
  mkdir -p "${INSTALL_DIR}"
  tmp="$(mktemp -d)"
  url="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}/Godot_v${GODOT_VERSION}_linux.x86_64.zip"
  echo "Downloading Godot ${GODOT_VERSION}..." >&2
  curl -fsSL "${url}" -o "${tmp}/godot.zip"
  if command -v unzip >/dev/null 2>&1; then
    unzip -q "${tmp}/godot.zip" -d "${tmp}"
  else
    python3 -c "import sys, zipfile; zipfile.ZipFile(sys.argv[1]).extractall(sys.argv[2])" "${tmp}/godot.zip" "${tmp}"
  fi
  mv "${tmp}/Godot_v${GODOT_VERSION}_linux.x86_64" "${GODOT_BIN}"
  chmod +x "${GODOT_BIN}"
  rm -rf "${tmp}"
fi

# Persist PATH for the rest of the session's Bash calls.
if [[ -n "${CLAUDE_ENV_FILE:-}" ]]; then
  echo "export PATH=\"${INSTALL_DIR}:\$PATH\"" >> "${CLAUDE_ENV_FILE}"
fi

# Register class_names and import resources so scripts compile in tests.
project_dir="${CLAUDE_PROJECT_DIR:-$(pwd)}"
if [[ -f "${project_dir}/project.godot" ]]; then
  "${GODOT_BIN}" --headless --path "${project_dir}" --import >/dev/null 2>&1 || true
fi

echo "Godot ready: $("${GODOT_BIN}" --version)" >&2
