#!/bin/sh
set -eu

LOG_FILE=""

log() {
  msg="$*"
  printf '%s\n' "$msg"
  if [ -n "${LOG_FILE:-}" ]; then
    ts="$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || true)"
    if [ -n "$ts" ]; then
      printf '%s %s\n' "$ts" "$msg" >>"$LOG_FILE" 2>/dev/null || true
    else
      printf '%s\n' "$msg" >>"$LOG_FILE" 2>/dev/null || true
    fi
  fi
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

npm_setup_user_global_prefix() {
  npm_global_prefix="/home/node/.npm-global"
  ensure_dir "$npm_global_prefix"

  npm config set prefix "$npm_global_prefix" >/dev/null 2>&1 || true

  ensure_path_line='export PATH="/home/node/.npm-global/bin:$PATH"'
  if [ -f /home/node/.profile ] && grep -F "$ensure_path_line" /home/node/.profile >/dev/null 2>&1; then
    :
  else
    printf '\n%s\n' "$ensure_path_line" >> /home/node/.profile
  fi

  if [ -f /home/node/.zshrc ] && grep -F "$ensure_path_line" /home/node/.zshrc >/dev/null 2>&1; then
    :
  else
    printf '\n%s\n' "$ensure_path_line" >> /home/node/.zshrc
  fi

  export PATH="/home/node/.npm-global/bin:$PATH"
}

shell_add_path_if_missing() {
  target_file="$1"
  path_line="$2"

  if [ -f "$target_file" ] && grep -F "$path_line" "$target_file" >/dev/null 2>&1; then
    return 0
  fi

  printf '\n%s\n' "$path_line" >> "$target_file"
}

workspace_setup_bin_path() {
  workspace_dir="$(pwd)"
  workspace_bin="$workspace_dir/bin"

  if [ ! -d "$workspace_bin" ]; then
    return 0
  fi

  path_line="export PATH=\"$workspace_bin:\$PATH\""
  shell_add_path_if_missing /home/node/.profile "$path_line"
  shell_add_path_if_missing /home/node/.zshrc "$path_line"

  export PATH="$workspace_bin:$PATH"
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

read_file() {
  file_path="$1"
  if [ -f "$file_path" ]; then
    cat "$file_path"
    return 0
  fi
  return 1
}

sha256_of_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
    return 0
  fi
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return 0
  fi
  return 1
}

init_bootstrap_logging() {
  if [ -n "${LOG_FILE:-}" ]; then
    return 0
  fi

  repo_root="$(pwd)"
  log_dir="${AI_CONTAINER_LOG_DIR:-$repo_root/.ai-container/logs}"

  ensure_dir "$log_dir"

  ts="$(date '+%Y%m%d-%H%M%S' 2>/dev/null || echo unknown)"
  LOG_FILE="$log_dir/bootstrap-$ts.log"
  : >"$LOG_FILE"
  chmod 600 "$LOG_FILE" 2>/dev/null || true

  log "Bootstrap log: $LOG_FILE"
}

run_and_tee() {
  if [ -z "${LOG_FILE:-}" ]; then
    "$@"
    return $?
  fi

  tmp_file="$(mktemp)"
  "$@" >"$tmp_file" 2>&1
  rc=$?
  cat "$tmp_file" | tee -a "$LOG_FILE"
  rm -f "$tmp_file"
  return $rc
}

codex_run_latest_bootstrap_prompt() {
  repo_root="$(pwd)"

  init_bootstrap_logging

  prompt=""
  prompt_source=""

  if [ -n "${AI_CONTAINER_BOOTSTRAP_PROMPT:-}" ]; then
    prompt="${AI_CONTAINER_BOOTSTRAP_PROMPT}"
    prompt_source="AI_CONTAINER_BOOTSTRAP_PROMPT"
  fi

  if [ -n "${AI_CONTAINER_BOOTSTRAP_PROMPT_FILE:-}" ] && [ -f "${AI_CONTAINER_BOOTSTRAP_PROMPT_FILE}" ]; then
    prompt="$(cat "${AI_CONTAINER_BOOTSTRAP_PROMPT_FILE}")"
    prompt_source="${AI_CONTAINER_BOOTSTRAP_PROMPT_FILE}"
  fi

  if [ -n "${AI_CONTAINER_BOOTSTRAP_PROFILE:-}" ] && [ -z "$prompt" ]; then
    profile_base="$repo_root/.devcontainer/prompts/${AI_CONTAINER_BOOTSTRAP_PROFILE}"
    profile_file="${profile_base}.md"
    if [ ! -f "$profile_file" ]; then
      log "Bootstrap profile not found: $profile_file"
      return 0
    fi
    prompt="$(cat "$profile_file")"
    prompt_source="$profile_file"
  fi

  if [ -z "$prompt" ]; then
    prompt_dir="$repo_root/.devcontainer/prompts"
    latest_file=""
    if [ -d "$prompt_dir" ]; then
      latest_file="$(
        for f in "$prompt_dir"/[0-9]*-task.md; do
          if [ -f "$f" ]; then
            printf '%s\n' "$f"
          fi
        done | sort | tail -n 1
      )"
      if [ -z "$latest_file" ]; then
        latest_file="$(ls -1t "$prompt_dir"/*-task.md 2>/dev/null | head -n 1 || true)"
      fi
    fi
    if [ -n "$latest_file" ] && [ -f "$latest_file" ]; then
      prompt="$(cat "$latest_file")"
      prompt_source="$latest_file"
    fi
  fi

  if [ -z "$prompt" ]; then
    log "No bootstrap prompt provided; skipping."
    return 0
  fi

  log "Selected bootstrap prompt: $prompt_source"

  if ! command -v codex >/dev/null 2>&1; then
    log "Codex not found; skipping bootstrap."
    return 0
  fi

  if [ -z "${CODEX_API_KEY:-}" ] && [ ! -s "/home/node/.codex/auth.json" ]; then
    log "No CODEX_API_KEY or /home/node/.codex/auth.json; skipping bootstrap."
    return 0
  fi

  if [ -z "${AI_CONTAINER_UNATTENDED:-}" ]; then
    log "AI_CONTAINER_UNATTENDED not set; skipping bootstrap."
    return 0
  fi

  prompt_hash=""
  prompt_hash="$(printf '%s' "$prompt" | sha256_of_stdin 2>/dev/null || true)"

  marker_dir="/home/node/.codex"
  marker_file="$marker_dir/bootstrap.last"
  ensure_dir "$marker_dir"
  ensure_owned_by_node "$marker_dir"

  if [ -n "$prompt_hash" ] && [ -f "$marker_file" ] && grep -F "$prompt_hash" "$marker_file" >/dev/null 2>&1; then
    log "Bootstrap prompt already applied; skipping. ($prompt_source)"
    return 0
  fi

  log "Running Codex bootstrap (unattended): $prompt_source"
  if ! run_and_tee codex exec --dangerously-bypass-approvals-and-sandbox -C "$repo_root" -- "$prompt"; then
    log "Codex bootstrap failed; continuing without blocking container startup."
    return 0
  fi

  if [ -n "$prompt_hash" ]; then
    printf '%s\t%s\n' "$prompt_hash" "$prompt_source" >"$marker_file"
  else
    printf '%s\n' "$prompt_source" >"$marker_file"
  fi
}

main() {
  ensure_dir /home/node/.codex
  ensure_dir /home/node/.gemini
  ensure_dir /home/node/.claude

  ensure_owned_by_node /home/node/.codex
  ensure_owned_by_node /home/node/.gemini
  ensure_owned_by_node /home/node/.claude

  npm_setup_user_global_prefix
  workspace_setup_bin_path

  npm_install_global @google/gemini-cli
  npm_install_global @openai/codex
  npm_install_global_optional @anthropic-ai/claude-code

  codex_run_latest_bootstrap_prompt
}

main "$@"
