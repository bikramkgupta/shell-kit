# git-tools.zsh - Git & Worktree power-user aliases
# Run 'ghelp' for available commands
# UX: worktree repo layout uses .bare/ at repo root

setopt NO_NOMATCH 2>/dev/null

# ============================================================================
# HELPERS
# ============================================================================

_git_tools_err() { print -r -- "git-tools: $*" >&2; }
_git_tools_ok()  { print -r -- "$*"; }

_git_tools_confirm() {
  local prompt="${1:-Continue?}"
  local reply
  read -r "reply?$prompt [y/N] "
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

_git_tools_in_git() { git rev-parse --is-inside-work-tree >/dev/null 2>&1; }

_git_tools_find_root() {
  local d="$PWD"
  while [[ "$d" != "/" ]]; do
    if [[ -d "$d/.bare" ]]; then
      (cd "$d" && pwd -P)
      return 0
    fi
    d="${d:h}"
  done
  return 1
}

_git_tools_root() {
  local root
  root="$(_git_tools_find_root)" && { print -r -- "$root"; return 0; }

  if _git_tools_in_git; then
    local common
    common="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1
    common="$(cd "$(dirname "$common")" 2>/dev/null && pwd -P)/$(basename "$common")"
    if [[ -d "$common" && -d "$(dirname "$common")/.bare" ]]; then
      print -r -- "$(cd "$(dirname "$common")" && pwd -P)"
      return 0
    fi
  fi

  _git_tools_err "could not find repo root with .bare/"
  return 1
}

_git_tools_dir_for_branch() {
  local b="$1"
  print -r -- "${b//\\//__}"
}

_git_tools_default_base() {
  if git show-ref --verify --quiet refs/remotes/origin/main; then print -r -- "origin/main"; return; fi
  if git show-ref --verify --quiet refs/remotes/origin/master; then print -r -- "origin/master"; return; fi
  if git show-ref --verify --quiet refs/heads/main; then print -r -- "main"; return; fi
  if git show-ref --verify --quiet refs/heads/master; then print -r -- "master"; return; fi
  print -r -- "HEAD"
}

_git_tools_dir_empty() {
  local d="$1"
  [[ -d "$d" ]] || return 0
  [[ -z "$(command ls -A "$d" 2>/dev/null)" ]]
}

_git_tools_parse_flags() {
  __GT_YES=0
  __GT_SAFE=1
  __GT_ARGS=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) __GT_YES=1; shift ;;
      --safe)   __GT_SAFE=1; shift ;;
      --unsafe) __GT_SAFE=0; shift ;;
      --) shift; __GT_ARGS+=("$@"); break ;;
      *)  __GT_ARGS+=("$1"); shift ;;
    esac
  done
}

# ============================================================================
# HELP SYSTEM
# ============================================================================

typeset -Ag __GHELP
__ghelp_add() { __GHELP["$1"]="$2"; }

ghelp() {
  local topic="${1:-all}"

  case "$topic" in
    all)
      print -r -- "Git Tools - Power User Commands"
      print -r -- "================================"
      print -r -- "Run 'ghelp <topic>' for focused help."
      print -r -- "Topics: core, worktree, branch, stash, rebase, remote, workflows"
      print -r -- ""
      print -r -- "Core Aliases"
      print -r -- "------------"
      local k
      for k in ${(ok)__GHELP}; do
        [[ "$k" == a:* ]] && print -r -- "${k#a:}|${__GHELP[$k]}"
      done | column -t -s'|'
      print -r -- ""
      print -r -- "Functions (run 'ghelp <topic>' for details)"
      print -r -- "--------------------------------------------"
      print -r -- "gwt-*     Worktree operations"
      print -r -- "gbr-*     Branch operations"
      print -r -- "gremote-* Remote operations"
      print -r -- "gst-*     Stash operations"
      ;;

    core|git)
      print -r -- "Core Git Aliases"
      print -r -- "----------------"
      for k in ${(ok)__GHELP}; do
        [[ "$k" == a:* ]] && print -r -- "${k#a:}|${__GHELP[$k]}"
      done | column -t -s'|'
      ;;

    worktree|wt)
      print -r -- "Worktree Commands (gwt-*)"
      print -r -- "-------------------------"
      for k in ${(ok)__GHELP}; do
        [[ "$k" == f:gwt* ]] && print -r -- "${k#f:}|${__GHELP[$k]}"
      done | column -t -s'|'
      ;;

    branch|br)
      print -r -- "Branch Commands (gbr-*)"
      print -r -- "-----------------------"
      for k in ${(ok)__GHELP}; do
        [[ "$k" == f:gbr* ]] && print -r -- "${k#f:}|${__GHELP[$k]}"
      done | column -t -s'|'
      ;;

    stash|st)
      print -r -- "Stash Commands"
      print -r -- "--------------"
      print -r -- "gst       git stash"
      print -r -- "gstp      git stash pop"
      print -r -- "gst-ls    List stashes with details"
      print -r -- "gst-show  Show stash diff"
      print -r -- "gst-drop  Drop stash (with confirm)"
      print -r -- "gst-save  Save with message"
      ;;

    rebase|rb)
      print -r -- "Rebase Commands"
      print -r -- "---------------"
      print -r -- "grb       git rebase"
      print -r -- "grbi      Interactive rebase"
      print -r -- "grbia     Interactive rebase with autosquash"
      print -r -- "grbm      Rebase on main"
      print -r -- "grbc      Continue rebase"
      print -r -- "grba      Abort rebase"
      print -r -- "grbs      Skip commit in rebase"
      ;;

    remote|rm)
      print -r -- "Remote Commands (gremote-*)"
      print -r -- "---------------------------"
      for k in ${(ok)__GHELP}; do
        [[ "$k" == f:gremote* ]] && print -r -- "${k#f:}|${__GHELP[$k]}"
      done | column -t -s'|'
      ;;

    workflows|wf)
      cat <<'EOF'
Common Workflows
================

1. Start new feature (worktree):
   gwt-new feature/my-feat origin/main
   gwt-go feature/my-feat
   # work, commit
   gPu                    # push with upstream

2. Start new feature (same worktree):
   gswc feature/my-feat   # create & switch branch
   # work, commit
   gPu

3. Review a PR locally:
   gf                     # fetch all
   gwt-add pr-branch      # add worktree for branch
   gwt-go pr-branch       # cd into it

4. Interactive rebase before PR:
   gf && grb origin/main  # rebase on latest main
   # or
   grbi HEAD~5            # interactive rebase last 5

5. Quick hotfix:
   gwt-new hotfix/fix main
   # fix, commit, push
   gbr-nuke --yes hotfix/fix  # after merge

6. See all worktrees at once:
   gwt-status-all         # git status in each

7. Update all worktrees:
   gwt-sync               # fetch + show status
EOF
      ;;

    search)
      shift
      local query="$1"
      [[ -z "$query" ]] && { _git_tools_err "usage: ghelp search <term>"; return 2; }
      print -r -- "Searching for '$query'..."
      for k in ${(ok)__GHELP}; do
        if [[ "$k" == *"$query"* || "${__GHELP[$k]}" == *"$query"* ]]; then
          print -r -- "${k#[af]:}|${__GHELP[$k]}"
        fi
      done | column -t -s'|'
      ;;

    *)
      _git_tools_err "Unknown topic: $topic"
      print -r -- "Topics: all, core, worktree, branch, stash, rebase, remote, workflows"
      print -r -- "Or: ghelp search <term>"
      ;;
  esac
}

# ============================================================================
# CORE GIT ALIASES
# ============================================================================

alias g='git'
__ghelp_add "a:g" "Run git|g status"

alias gs='git status -sb'
__ghelp_add "a:gs" "Short status|gs"

alias gss='git status'
__ghelp_add "a:gss" "Full status|gss"

alias gl='git log --oneline --decorate --graph -n 30'
__ghelp_add "a:gl" "Graph log (30)|gl"

alias gll='git log --decorate --graph'
__ghelp_add "a:gll" "Full graph log|gll"

alias glo='git log --oneline -n 20'
__ghelp_add "a:glo" "Oneline log|glo"

alias ga='git add'
__ghelp_add "a:ga" "Stage files|ga ."

alias gaa='git add -A'
__ghelp_add "a:gaa" "Stage all|gaa"

alias gap='git add -p'
__ghelp_add "a:gap" "Stage interactively|gap"

alias gc='git commit'
__ghelp_add "a:gc" "Commit|gc"

alias gcm='git commit -m'
__ghelp_add "a:gcm" "Commit with msg|gcm \"fix: thing\""

alias gca='git commit --amend'
__ghelp_add "a:gca" "Amend commit|gca"

alias gcan='git commit --amend --no-edit'
__ghelp_add "a:gcan" "Amend no edit|gcan"

alias gco='git checkout'
__ghelp_add "a:gco" "Checkout|gco main"

alias gsw='git switch'
__ghelp_add "a:gsw" "Switch branch|gsw feature"

alias gswc='git switch -c'
__ghelp_add "a:gswc" "Create+switch|gswc feature"

alias gf='git fetch --all --prune'
__ghelp_add "a:gf" "Fetch all|gf"

alias gp='git pull --rebase'
__ghelp_add "a:gp" "Pull rebase|gp"

alias gP='git push'
__ghelp_add "a:gP" "Push|gP"

alias gPu='git push -u origin HEAD'
__ghelp_add "a:gPu" "Push+upstream|gPu"

alias gPf='git push --force-with-lease'
__ghelp_add "a:gPf" "Force push safe|gPf"

# Rebase
alias grb='git rebase'
__ghelp_add "a:grb" "Rebase|grb main"

alias grbi='git rebase -i'
__ghelp_add "a:grbi" "Interactive rebase|grbi HEAD~5"

alias grbia='git rebase -i --autosquash'
__ghelp_add "a:grbia" "Rebase autosquash|grbia HEAD~5"

alias grbc='git rebase --continue'
__ghelp_add "a:grbc" "Continue rebase|grbc"

alias grba='git rebase --abort'
__ghelp_add "a:grba" "Abort rebase|grba"

alias grbs='git rebase --skip'
__ghelp_add "a:grbs" "Skip in rebase|grbs"

# Rebase on main (auto-detect)
grbm() {
  local base="$(_git_tools_default_base)"
  git fetch origin --prune
  git rebase "$base"
}
__ghelp_add "f:grbm" "Rebase on main/master|grbm"

# Stash
alias gst='git stash'
__ghelp_add "a:gst" "Stash|gst"

alias gstp='git stash pop'
__ghelp_add "a:gstp" "Pop stash|gstp"

# Enhanced stash commands
alias gst-ls='git stash list --pretty=format:"%C(yellow)%gd%Creset %C(green)%cr%Creset %s"'
__ghelp_add "a:gst-ls" "List stashes|gst-ls"

gst-show() {
  local stash="${1:-stash@{0}}"
  git stash show -p "$stash"
}
__ghelp_add "f:gst-show" "Show stash diff|gst-show stash@{0}"

gst-drop() {
  local stash="${1:-stash@{0}}"
  _git_tools_confirm "Drop $stash?" || return 1
  git stash drop "$stash"
}
__ghelp_add "f:gst-drop" "Drop stash (confirm)|gst-drop stash@{0}"

gst-save() {
  local msg="$1"
  [[ -z "$msg" ]] && { _git_tools_err "usage: gst-save <message>"; return 2; }
  git stash push -m "$msg"
}
__ghelp_add "f:gst-save" "Stash with message|gst-save \"wip: thing\""

# Diff
alias gdf='git diff'
__ghelp_add "a:gdf" "Diff unstaged|gdf"

alias gds='git diff --staged'
__ghelp_add "a:gds" "Diff staged|gds"

alias gdn='git diff --name-only'
__ghelp_add "a:gdn" "Diff names only|gdn"

# Reset
alias grh='git reset --hard'
__ghelp_add "a:grh" "Hard reset|grh HEAD~1"

alias grs='git reset --soft'
__ghelp_add "a:grs" "Soft reset|grs HEAD~1"

alias gundo='git reset --soft HEAD~1'
__ghelp_add "a:gundo" "Undo last commit|gundo"

# Cherry-pick
alias gcp='git cherry-pick'
__ghelp_add "a:gcp" "Cherry-pick|gcp <sha>"

alias gcpc='git cherry-pick --continue'
__ghelp_add "a:gcpc" "Continue cherry-pick|gcpc"

alias gcpa='git cherry-pick --abort'
__ghelp_add "a:gcpa" "Abort cherry-pick|gcpa"

# Show/inspect
alias gsh='git show --stat'
__ghelp_add "a:gsh" "Show commit stat|gsh"

alias gshf='git show'
__ghelp_add "a:gshf" "Show full commit|gshf"

# Reflog
alias grl='git reflog --pretty=format:"%C(yellow)%h%Creset %C(green)%gd%Creset %gs %C(dim)%cr%Creset"'
__ghelp_add "a:grl" "Reflog pretty|grl"

alias grlp='git reflog show --pretty=short'
__ghelp_add "a:grlp" "Reflog short|grlp"

# Tags
alias gt='git tag'
__ghelp_add "a:gt" "List tags|gt"

alias gtl='git tag -l --sort=-v:refname'
__ghelp_add "a:gtl" "List tags sorted|gtl"

gta() {
  local tag="$1" msg="$2"
  [[ -z "$tag" ]] && { _git_tools_err "usage: gta <tag> [message]"; return 2; }
  if [[ -z "$msg" ]]; then
    git tag -a "$tag"
  else
    git tag -a "$tag" -m "$msg"
  fi
}
__ghelp_add "f:gta" "Create annotated tag|gta v1.0 \"Release\""

# Clean
gclean() {
  echo "Files to be removed:"
  git clean -dn
  _git_tools_confirm "Remove these files?" || return 1
  git clean -df
}
__ghelp_add "f:gclean" "Remove untracked (confirm)|gclean"

alias gclean-dry='git clean -dn'
__ghelp_add "a:gclean-dry" "Show what would clean|gclean-dry"

# ============================================================================
# BRANCH MANAGEMENT
# ============================================================================

alias gbr-ls='git branch -vv'
__ghelp_add "a:gbr-ls" "List branches verbose|gbr-ls"

alias gbr-merged='git branch --merged'
__ghelp_add "a:gbr-merged" "List merged branches|gbr-merged"

alias gbr-unmerged='git branch --no-merged'
__ghelp_add "a:gbr-unmerged" "List unmerged branches|gbr-unmerged"

alias gbr-remote='git branch -r'
__ghelp_add "a:gbr-remote" "List remote branches|gbr-remote"

gbr-newpush() {
  local branch="$1"
  local base="${2:-$(_git_tools_default_base)}"
  local remote="${3:-origin}"
  [[ -z "$branch" ]] && { _git_tools_err "usage: gbr-newpush <branch> [base] [remote]"; return 2; }

  _git_tools_in_git || { _git_tools_err "not in a git repo"; return 2; }

  git fetch --all --prune >/dev/null 2>&1 || true
  git switch -c "$branch" "$base" && git push -u "$remote" "$branch"
}
__ghelp_add "f:gbr-newpush" "New branch + push|gbr-newpush feat origin/main"

gbr-track() {
  local branch="$1" remote="${2:-origin}"
  [[ -z "$branch" ]] && { _git_tools_err "usage: gbr-track <branch> [remote]"; return 2; }
  _git_tools_in_git || { _git_tools_err "not in a git repo"; return 2; }

  git fetch "$remote" --prune || return 2

  if git show-ref --verify --quiet "refs/heads/$branch"; then
    git switch "$branch"
    return $?
  fi

  if git show-ref --verify --quiet "refs/remotes/$remote/$branch"; then
    git switch -c "$branch" --track "$remote/$branch"
    return $?
  fi

  _git_tools_err "remote branch not found: $remote/$branch"
  return 2
}
__ghelp_add "f:gbr-track" "Track remote branch|gbr-track feature origin"

gbr-nuke() {
  _git_tools_parse_flags "$@"
  local branch="${__GT_ARGS[1]}" remote="${__GT_ARGS[2]:-origin}"
  [[ -z "$branch" ]] && { _git_tools_err "usage: gbr-nuke [--yes] [--safe|--unsafe] <branch> [remote]"; return 2; }

  local root="$(_git_tools_root)" || return
  local wt_dir="$root/$(_git_tools_dir_for_branch "$branch")"

  if (( __GT_SAFE )); then
    if [[ "$branch" == "main" || "$branch" == "master" || "$branch" == "develop" ]]; then
      _git_tools_err "safe mode: refusing to delete protected branch: $branch (use --unsafe)"
      return 2
    fi
  fi

  print -r -- "About to delete branch:"
  print -r -- "  local : $branch"
  print -r -- "  remote: $remote/$branch"
  [[ -d "$wt_dir" ]] && print -r -- "  worktree: $wt_dir"

  if (( ! __GT_YES )); then
    _git_tools_confirm "Proceed?" || return 1
  fi

  if _git_tools_in_git; then
    local cur
    cur="$(git branch --show-current 2>/dev/null)"
    if [[ "$cur" == "$branch" ]]; then
      git switch "$(_git_tools_default_base)" || return 2
    fi
  fi

  (cd "$root" || return
    [[ -d "$wt_dir" ]] && git worktree remove "$wt_dir" >/dev/null 2>&1 || true
    git branch -D "$branch" >/dev/null 2>&1 || true
    git push "$remote" --delete "$branch" >/dev/null 2>&1 || true
    _git_tools_ok "deleted: $branch (local + $remote)"
  )
}
__ghelp_add "f:gbr-nuke" "Delete branch everywhere|gbr-nuke --yes feat origin"

# ============================================================================
# REMOTES
# ============================================================================

gremote-ls() { git remote -v; }
__ghelp_add "f:gremote-ls" "List remotes|gremote-ls"

gremote-add() {
  local name="$1" url="$2"
  [[ -z "$name" || -z "$url" ]] && { _git_tools_err "usage: gremote-add <name> <url>"; return 2; }
  git remote get-url "$name" >/dev/null 2>&1 && {
    _git_tools_err "remote '$name' already exists"; return 2
  }
  git remote add "$name" "$url" && _git_tools_ok "added remote '$name'"
}
__ghelp_add "f:gremote-add" "Add remote|gremote-add upstream git@..."

gremote-gh() {
  local name="$1" repo="$2"
  [[ -z "$name" || -z "$repo" ]] && { _git_tools_err "usage: gremote-gh <name> <owner/repo>"; return 2; }
  command -v gh >/dev/null 2>&1 || { _git_tools_err "gh not found"; return 2; }
  local url
  url="$(gh repo view "$repo" --json sshUrl -q .sshUrl 2>/dev/null)" || {
    _git_tools_err "could not resolve $repo via gh"; return 2
  }
  gremote-add "$name" "$url"
}
__ghelp_add "f:gremote-gh" "Add remote via GH|gremote-gh upstream org/repo"

# ============================================================================
# WORKTREE OPERATIONS
# ============================================================================

gwt-ls() {
  local root="$(_git_tools_root)" || return
  (cd "$root" && git worktree list)
}
__ghelp_add "f:gwt-ls" "List worktrees|gwt-ls"

gwt-prune() {
  local root="$(_git_tools_root)" || return
  (cd "$root" && git worktree prune && git worktree list)
}
__ghelp_add "f:gwt-prune" "Prune stale worktrees|gwt-prune"

gwt-add() {
  local branch="$1"
  [[ -z "$branch" ]] && { _git_tools_err "usage: gwt-add <branch>"; return 2; }

  local root="$(_git_tools_root)" || return
  local dir="$root/$(_git_tools_dir_for_branch "$branch")"

  (cd "$root" || return
    if [[ -e "$dir" ]]; then _git_tools_err "path exists: $dir"; return 2; fi

    if git show-ref --verify --quiet "refs/heads/$branch"; then
      git worktree add "$dir" "$branch"
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      git worktree add -b "$branch" "$dir" "origin/$branch"
    else
      _git_tools_err "branch not found locally or in origin: $branch"
      return 2
    fi
  )
}
__ghelp_add "f:gwt-add" "Add worktree for branch|gwt-add feature"

gwt-new() {
  local branch="$1"
  local base="${2:-$(_git_tools_default_base)}"
  [[ -z "$branch" ]] && { _git_tools_err "usage: gwt-new <branch> [base]"; return 2; }

  local root="$(_git_tools_root)" || return
  local dir="$root/$(_git_tools_dir_for_branch "$branch")"

  (cd "$root" || return
    [[ -e "$dir" ]] && { _git_tools_err "path exists: $dir"; return 2; }
    git worktree add -b "$branch" "$dir" "$base"
  )
}
__ghelp_add "f:gwt-new" "New branch + worktree|gwt-new feature origin/main"

gwt-newpush() {
  local branch="$1"
  local base="${2:-$(_git_tools_default_base)}"
  local remote="${3:-origin}"
  [[ -z "$branch" ]] && { _git_tools_err "usage: gwt-newpush <branch> [base] [remote]"; return 2; }

  gwt-new "$branch" "$base" || return
  local root="$(_git_tools_root)" || return
  local dir="$root/$(_git_tools_dir_for_branch "$branch")"
  git -C "$dir" push -u "$remote" "$branch"
}
__ghelp_add "f:gwt-newpush" "New worktree + push|gwt-newpush feature origin/main"

gwt-rm() {
  local target="$1"
  [[ -z "$target" ]] && { _git_tools_err "usage: gwt-rm <worktree-path>"; return 2; }

  local root="$(_git_tools_root)" || return
  local path="$target"
  [[ "$path" != /* ]] && path="$root/$target"

  (cd "$root" || return
    git worktree remove "$path"
  )
}
__ghelp_add "f:gwt-rm" "Remove worktree|gwt-rm feature__foo"

gwt-go() {
  local branch="$1"
  [[ -z "$branch" ]] && { _git_tools_err "usage: gwt-go <branch>"; return 2; }
  local root="$(_git_tools_root)" || return
  local dir="$root/$(_git_tools_dir_for_branch "$branch")"
  [[ -d "$dir" ]] || { _git_tools_err "not found: $dir"; return 2; }
  cd "$dir"
}
__ghelp_add "f:gwt-go" "cd to worktree|gwt-go feature/foo"

gwt-repair() {
  local root="$(_git_tools_root)" || return
  (cd "$root" && git worktree repair)
}
__ghelp_add "f:gwt-repair" "Repair worktrees|gwt-repair"

gwt-lock() {
  local target="$1"
  [[ -z "$target" ]] && { _git_tools_err "usage: gwt-lock <worktree>"; return 2; }
  local root="$(_git_tools_root)" || return
  local path="$target"
  [[ "$path" != /* ]] && path="$root/$target"
  git worktree lock "$path"
}
__ghelp_add "f:gwt-lock" "Lock worktree|gwt-lock feature__foo"

gwt-unlock() {
  local target="$1"
  [[ -z "$target" ]] && { _git_tools_err "usage: gwt-unlock <worktree>"; return 2; }
  local root="$(_git_tools_root)" || return
  local path="$target"
  [[ "$path" != /* ]] && path="$root/$target"
  git worktree unlock "$path"
}
__ghelp_add "f:gwt-unlock" "Unlock worktree|gwt-unlock feature__foo"

gwt-sync() {
  local root="$(_git_tools_root)" || return
  echo "Fetching all remotes..."
  git -C "$root/.bare" fetch --all --prune
  echo ""
  echo "Worktree status:"
  gwt-status-all
}
__ghelp_add "f:gwt-sync" "Fetch + status all|gwt-sync"

gwt-status-all() {
  local root="$(_git_tools_root)" || return
  git -C "$root" worktree list --porcelain | grep '^worktree' | cut -d' ' -f2 | while read wt; do
    echo "=== ${wt##*/} ==="
    git -C "$wt" status -sb 2>/dev/null || echo "(not accessible)"
    echo ""
  done
}
__ghelp_add "f:gwt-status-all" "Status all worktrees|gwt-status-all"

# FZF integration for worktrees
if command -v fzf >/dev/null 2>&1; then
  gwt-fzf() {
    local root="$(_git_tools_root)" || return
    local selection
    selection=$(git -C "$root" worktree list --porcelain | \
      grep '^worktree' | cut -d' ' -f2 | \
      fzf --height=40% --reverse --preview 'git -C {} status -sb') || return
    cd "$selection"
  }
  __ghelp_add "f:gwt-fzf" "Fuzzy find worktree|gwt-fzf"
  alias gwf='gwt-fzf'
fi

# ============================================================================
# REPO INIT (bare layout)
# ============================================================================

gwt-init-bare() {
  local url="$1"
  local dir="${2:-}"
  [[ -z "$url" ]] && { _git_tools_err "usage: gwt-init-bare <git-url> [dir]"; return 2; }

  if [[ -z "$dir" ]]; then
    dir="${${url:t}%.git}"
  fi

  mkdir -p "$dir" || return 2
  (cd "$dir" || return
    git clone --bare "$url" .bare || return 2
    print -r -- "gitdir: ./.bare" > .git
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
    git fetch origin
    local first="main"
    if git show-ref --verify --quiet refs/remotes/origin/main; then first="main"
    elif git show-ref --verify --quiet refs/remotes/origin/master; then first="master"
    fi
    git worktree add "$first" "origin/$first" 2>/dev/null || git worktree add "$first" "$first"
    _git_tools_ok "ready: $dir/$first"
  )
}
__ghelp_add "f:gwt-init-bare" "Clone as bare + worktree|gwt-init-bare git@... repo"

gwt-init-empty() {
  _git_tools_parse_flags "$@"
  local dir="${__GT_ARGS[1]}" branch="${__GT_ARGS[2]:-main}"
  [[ -z "$dir" ]] && { _git_tools_err "usage: gwt-init-empty [--yes] <dir> [branch]"; return 2; }

  mkdir -p "$dir" || return 2

  if (( __GT_SAFE )); then
    _git_tools_dir_empty "$dir" || { _git_tools_err "safe mode: directory not empty: $dir"; return 2; }
  fi

  if (( ! __GT_YES )); then
    _git_tools_confirm "Initialize .bare repo in '$dir'?" || return 1
  fi

  cd "$dir" || return 2
  [[ -d .bare || -e .git ]] && { _git_tools_err "already initialized here"; return 2; }

  git init || return 2
  git branch -M "$branch" || return 2
  [[ -f README.md ]] || print -r -- "# ${dir:t}" > README.md
  git add -A && git commit -m "chore: initial commit" || return 2

  git clone --bare . .bare || return 2
  rm -rf .git
  print -r -- "gitdir: ./.bare" > .git
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git worktree add "$branch" "$branch" || return 2

  _git_tools_ok "ready: $(pwd)/$branch"
}
__ghelp_add "f:gwt-init-empty" "Init new bare repo|gwt-init-empty --yes myrepo"

gwt-clone-bare() {
  _git_tools_parse_flags "$@"
  local url="${__GT_ARGS[1]}" dir="${__GT_ARGS[2]}" branch="${__GT_ARGS[3]:-main}"
  [[ -z "$url" ]] && { _git_tools_err "usage: gwt-clone-bare [--yes] <url> [dir] [branch]"; return 2; }

  if [[ -n "$dir" ]]; then
    mkdir -p "$dir" || return 2
    if (( __GT_SAFE )); then
      _git_tools_dir_empty "$dir" || { _git_tools_err "safe mode: directory not empty: $dir"; return 2; }
    fi
    if (( ! __GT_YES )); then
      _git_tools_confirm "Clone into '$dir'?" || return 1
    fi
    cd "$dir" || return 2
  else
    if (( __GT_SAFE )); then
      _git_tools_dir_empty "$PWD" || { _git_tools_err "safe mode: current directory not empty"; return 2; }
    fi
    if (( ! __GT_YES )); then
      _git_tools_confirm "Clone into '$PWD'?" || return 1
    fi
  fi

  [[ -d .bare || -e .git ]] && { _git_tools_err "already initialized here"; return 2; }

  git clone --bare "$url" .bare || return 2
  print -r -- "gitdir: ./.bare" > .git
  git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
  git fetch origin || return 2

  if git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git worktree add "$branch" "origin/$branch" || return 2
  elif git show-ref --verify --quiet "refs/remotes/origin/master"; then
    git worktree add master origin/master || return 2
    branch="master"
  else
    _git_tools_err "could not find origin/$branch or origin/master"
    return 2
  fi

  _git_tools_ok "ready: $(pwd)/$branch"
}
__ghelp_add "f:gwt-clone-bare" "Clone existing repo as bare|gwt-clone-bare --yes git@..."

# ============================================================================
# SEARCH HELPERS
# ============================================================================

ghelp-grep() {
  local pat="$1"
  [[ -z "$pat" ]] && { _git_tools_err "usage: ghelp-grep <pattern>"; return 2; }
  ghelp | command grep -i -- "$pat"
}
__ghelp_add "f:ghelp-grep" "Search help|ghelp-grep worktree"

galiases() {
  alias | command grep -E '^(g|gs|gl|ga|gc|gco|gsw|gf|gp|gP|grb|gst|gdf|gds|grh|gcp)='
}
__ghelp_add "f:galiases" "List git aliases|galiases"
