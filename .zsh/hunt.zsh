# hunt.zsh - Fast repository search command
# Requires: fd (required), rg (required for content search)
# Optional: fzf (interactive mode), bat (file preview)

function hunt {
  setopt localoptions noglob 2>/dev/null

  local mode="name"
  local output="files"
  local interactive=0
  local all=0

  local EXCLUDES=(
    node_modules .git .venv venv __pycache__
    dist build .next .cache .idea .vscode coverage
    .mypy_cache .pytest_cache .tox .eggs *.egg-info
    .DS_Store Thumbs.db
  )

  while getopts "ncdfiagh" opt; do
    case "$opt" in
      n) mode="name" ;;
      c) mode="content" ;;
      d) output="dirs" ;;
      f) output="files" ;;
      i) interactive=1 ;;
      a) all=1 ;;
      g) ;;
      h)
        cat <<'EOF'
hunt - fast repo search

USAGE:
  hunt [flags] <pattern> [filter/path]

FLAGS:
  -n    Name search (default) - find files by name pattern
  -c    Content search - find files containing pattern
  -d    Directory mode - show parent directories of matches
  -f    File mode (default) - show matching files
  -i    Interactive - use fzf for selection
  -a    Include all files (no excludes, show hidden)
  -h    Show this help

EXAMPLES:
  # --- File Name Search ---
  hunt "*.py"              # Find all Python files
  hunt -n "*.json"         # Explicit name mode
  hunt "config*.yaml"      # Find config files
  hunt "*.ts" src          # Find .ts files ONLY in 'src' folder

  # --- Content Search ---
  hunt -c "password"       # Find "password" inside files
  hunt -c "API_KEY"        # Look for string "API_KEY"
  hunt -c "user_id ="      # Look for variable assignment
  hunt -c "_TOKEN" "*.env" # Search for token ONLY in .env files

  # --- Directory Mode ---
  hunt -d "*.py"           # List FOLDERS that contain Python files
  hunt -d "config"         # List FOLDERS containing a file named "config"

  # --- Interactive (FZF) ---
  hunt -i "*.tsx"          # Find React components -> select to open
  hunt -c "TODO" -i        # Find TODOs -> preview code snippet
  hunt -c error -i         # Find "error" -> preview code snippet

EXCLUDED DIRECTORIES:
  node_modules, .git, .venv, venv, __pycache__, dist, build,
  .next, .cache, .idea, .vscode, coverage, .mypy_cache, etc.

  Use -a flag to include all files (no excludes).

DEPENDENCIES:
  Required: fd (file finder), rg (content search)
  Optional: fzf (interactive), bat (preview highlighting)
EOF
        return
        ;;
    esac
  done
  shift $((OPTIND - 1))

  local pattern="$1"
  local filter="$2"

  [[ -z "$pattern" ]] && echo "Error: Pattern required. Use 'hunt -h' for help." && return 1

  # Check dependencies
  if [[ "$mode" == "name" ]] && ! command -v fd >/dev/null; then
    echo "Error: 'fd' is required for name search. Install with: brew install fd"
    return 1
  fi
  if [[ "$mode" == "content" ]] && ! command -v rg >/dev/null; then
    echo "Error: 'rg' (ripgrep) is required for content search. Install with: brew install ripgrep"
    return 1
  fi
  if [[ "$interactive" -eq 1 ]] && ! command -v fzf >/dev/null; then
    echo "Warning: 'fzf' not found. Install with: brew install fzf"
    echo "Falling back to non-interactive mode..."
    interactive=0
  fi

  local cmd=()

  # ---------- NAME SEARCH ----------
  if [[ "$mode" == "name" ]]; then
    cmd=(fd -g "$pattern")
    [[ "$all" -eq 1 ]] && cmd+=(--no-ignore --hidden)
    for e in "${EXCLUDES[@]}"; do
      cmd+=(--exclude "$e")
    done

    # Use 2nd arg as search path (e.g., hunt *.py src)
    if [[ -n "$filter" ]]; then
      cmd+=("$filter")
    fi
  fi

  # ---------- CONTENT SEARCH ----------
  if [[ "$mode" == "content" ]]; then
    cmd=(rg -i --files-with-matches --no-messages "$pattern")
    [[ "$all" -eq 1 ]] && cmd+=(--no-ignore --hidden)

    for e in "${EXCLUDES[@]}"; do
      cmd+=(--glob "!$e")
    done

    # Use 2nd arg as file glob (e.g., hunt -c TOKEN *.env)
    if [[ -n "$filter" ]]; then
      cmd+=(--glob "$filter")
    fi
  fi

  # ---------- OUTPUT ----------
  local dir_filter="sed 's|/[^/]*$||' | sort -u"

  if [[ "$output" == "dirs" ]]; then
    if [[ "$interactive" -eq 1 ]]; then
      "${cmd[@]}" | eval "$dir_filter" | fzf --preview 'ls -la {}'
    else
      "${cmd[@]}" | eval "$dir_filter"
    fi
    return
  fi

  if [[ "$interactive" -eq 1 ]]; then
    local preview_cmd
    if [[ "$mode" == "content" ]]; then
      # Show matching lines with context
      if command -v bat >/dev/null; then
        preview_cmd="rg -i --color=always -C 3 '$pattern' {} | head -50"
      else
        preview_cmd="rg -i --color=always -C 3 '$pattern' {}"
      fi
    else
      # Show file contents
      if command -v bat >/dev/null; then
        preview_cmd='bat --style=numbers --color=always --line-range=:100 {}'
      else
        preview_cmd='head -100 {}'
      fi
    fi
    "${cmd[@]}" | fzf --preview "$preview_cmd" --preview-window=right:60%
  else
    "${cmd[@]}"
  fi
}

# Alias to handle glob patterns without quoting
alias hunt='noglob hunt'

# Quick shortcuts
alias hc='hunt -c'   # Content search
alias hi='hunt -i'   # Interactive name search
alias hci='hunt -c -i'  # Interactive content search
