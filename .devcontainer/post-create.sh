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

codex_scaffold_react_ts_vite() {
  repo_root="$(pwd)"
  example_dir="$repo_root/demo/react-ts-vite"

  if [ -f "$example_dir/package.json" ]; then
    log "Example already exists: demo/react-ts-vite"
    return 0
  fi

  if ! command -v codex >/dev/null 2>&1; then
    log "Codex not found; skipping example scaffold."
    return 0
  fi

  if [ -z "${CODEX_API_KEY:-}" ]; then
    log "CODEX_API_KEY not set; skipping Codex scaffold."
    return 0
  fi

  log "Scaffolding demo/react-ts-vite via Codex (unattended)..."
  codex exec --dangerously-bypass-approvals-and-sandbox -C "$repo_root" \
    "创建了reat+ts+vite的项目例子。\n\n请在仓库内创建示例项目目录：demo/react-ts-vite\n要求：\n- 使用命令：npm create vite@latest react-ts-vite -- --template react-ts --no-interactive（在 demo/ 目录执行）\n- 然后在 demo/react-ts-vite 下执行：npm install 与 npm run build\n- 不要修改 demo/react-ts-vite 之外的任何文件\n- 如果目录已存在则不重复创建" \
    "true"
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

  codex_scaffold_react_ts_vite
}

main "$@"
