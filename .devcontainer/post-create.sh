#!/bin/sh
set -eu

log() {
  printf '%s\n' "$*"
}

ensure_dir() {
  dir_path="$1"
  mkdir -p "$dir_path"
}

ensure_owned_by_node() {
  dir_path="$1"
  if command -v sudo >/dev/null 2>&1; then
    sudo chown -R node:node "$dir_path"
  else
    chown -R node:node "$dir_path"
  fi
}

npm_install_global() {
  package_name="$1"
  npm install -g "$package_name"
}

npm_install_global_optional() {
  package_name="$1"
  if npm install -g "$package_name"; then
    return 0
  fi
  log "Skipping optional install: $package_name"
}

main() {
  ensure_dir /home/node/.codex
  ensure_dir /home/node/.gemini
  ensure_dir /home/node/.claude

  ensure_owned_by_node /home/node/.codex
  ensure_owned_by_node /home/node/.gemini
  ensure_owned_by_node /home/node/.claude

  npm_install_global @google/gemini-cli
  npm_install_global @openai/codex
  npm_install_global_optional @anthropic-ai/claude-code
}

main "$@"
