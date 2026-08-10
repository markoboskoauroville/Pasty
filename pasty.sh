#!/usr/bin/env bash
# Pasty, single file installer. Install, dependencies, uninstall, offline rebuild.
# No command line switches. One keypress, one action.
set -uo pipefail

REPO_URL="https://github.com/markoboskoauroville/Pasty.git"
SRC="$HOME/.pasty-src"
APP_DIR="$HOME/Applications"
APP="$APP_DIR/Pasty.app"

if [ -t 1 ]; then
  N=$(tput colors 2>/dev/null || echo 0)
  if [ "$N" -ge 256 ]; then
    G=$'\033[38;5;179m'; R=$'\033[38;5;131m'; W=$'\033[38;5;252m'
    D=$'\033[38;5;244m'; OK=$'\033[38;5;71m'; Z=$'\033[0m'
  else
    G=$'\033[1;33m'; R=$'\033[0;31m'; W=$'\033[0;37m'
    D=$'\033[0;37m'; OK=$'\033[0;32m'; Z=$'\033[0m'
  fi
else
  G=""; R=""; W=""; D=""; OK=""; Z=""
fi

banner() {
  printf '\n'
  printf '  %s██████╗  █████╗ ███████╗████████╗██╗   ██╗%s\n' "$G" "$Z"
  printf '  %s██╔══██╗██╔══██╗██╔════╝╚══██╔══╝╚██╗ ██╔╝%s\n' "$G" "$Z"
  printf '  %s██████╔╝███████║███████╗   ██║    ╚████╔╝ %s\n' "$G" "$Z"
  printf '  %s██╔═══╝ ██╔══██║╚════██║   ██║     ╚██╔╝  %s\n' "$R" "$Z"
  printf '  %s██║     ██║  ██║███████║   ██║      ██║   %s\n' "$R" "$Z"
  printf '  %s╚═╝     ╚═╝  ╚═╝╚══════╝   ╚═╝      ╚═╝   %s\n' "$R" "$Z"
  printf '       %sone board, pins in place%s\n\n' "$D" "$Z"
}

dep_row() {
  local name="$1" why="$2" have="$3"
  if [ "$have" = "yes" ]; then
    printf '  %s+%s  %-12s %s%s%s\n' "$OK" "$Z" "$name" "$D" "$why" "$Z"
  else
    printf '  %s-%s  %-12s %s%s%s\n' "$R" "$Z" "$name" "$D" "$why" "$Z"
  fi
}

have() { command -v "$1" >/dev/null 2>&1 && echo yes || echo no; }

deps_table() {
  local present=0 missing=0 total=0
  printf '  %sdependencies%s\n' "$W" "$Z"
  for spec in \
    "git|clone and update the source|required" \
    "swift|compile the app|required" \
    "xcrun|macOS toolchain|required" \
    "brew|optional, only for the tap route|optional"
  do
    IFS='|' read -r n w kind <<< "$spec"
    local h; h=$(have "$n")
    [ "$kind" = "optional" ] && w="$w (optional)"
    dep_row "$n" "$w" "$h"
    total=$((total+1))
    if [ "$h" = "yes" ]; then present=$((present+1))
    elif [ "$kind" != "optional" ]; then missing=$((missing+1)); fi
  done
  printf '\n  %s%d of %d present   %d missing%s\n\n' "$D" "$present" "$total" "$missing" "$Z"
  return $missing
}

do_install() {
  local offline="${1:-no}"
  if [ "$offline" = "no" ]; then
    if [ -d "$SRC/.git" ]; then
      printf '  %supdating source%s\n' "$D" "$Z"
      git -C "$SRC" pull --ff-only || { printf '  %spull failed%s\n' "$R" "$Z"; return 1; }
    else
      printf '  %scloning source%s\n' "$D" "$Z"
      git clone "$REPO_URL" "$SRC" || { printf '  %sclone failed, check git auth%s\n' "$R" "$Z"; return 1; }
    fi
  else
    [ -d "$SRC" ] || { printf '  %sno local source to rebuild%s\n' "$R" "$Z"; return 1; }
    printf '  %soffline rebuild from %s%s\n' "$D" "$SRC" "$Z"
  fi

  ( cd "$SRC" && VERSION="1.0.0" BUILD="$(date +%Y%m%d%H%M)" bash scripts/build_app.sh ) || return 1

  mkdir -p "$APP_DIR"
  rm -rf "$APP"
  cp -R "$SRC/packaging/Pasty.app" "$APP" || return 1
  xattr -dr com.apple.quarantine "$APP" 2>/dev/null

  printf '\n  %sinstalled%s  %s\n' "$OK" "$Z" "$APP"
  printf '  %sgrant Accessibility once so one click can paste%s\n' "$D" "$Z"
  open "$APP"
}

do_uninstall() {
  printf '\n  %s[A]%s app only, keep clips and settings\n' "$G" "$Z"
  printf '  %s[E]%s everything, clips and settings too\n' "$G" "$Z"
  printf '  %s[Q]%s back\n\n  ' "$G" "$Z"
  read -rsn1 k; printf '\n'
  case "$k" in
    a|A)
      rm -rf "$APP" "$SRC"
      printf '  %sapp removed, clips kept%s\n' "$OK" "$Z" ;;
    e|E)
      rm -rf "$APP" "$SRC"
      rm -rf "$HOME/Library/Application Support/Pasty"
      defaults delete com.mantraproductions.pasty 2>/dev/null
      printf '  %severything removed%s\n' "$OK" "$Z" ;;
    *) return ;;
  esac
}

menu() {
  while true; do
    banner
    deps_table; local missing=$?
    printf '  %s[I]%s install or update      %s[D]%s dependencies\n' "$G" "$Z" "$G" "$Z"
    printf '  %s[U]%s uninstall              %s[↵]%s offline rebuild\n' "$G" "$Z" "$G" "$Z"
    printf '  %s[Q]%s quit\n\n  ' "$G" "$Z"
    read -rsn1 key
    case "$key" in
      i|I) printf '\n'; do_install no ;;
      d|D) printf '\n'
           command -v brew >/dev/null 2>&1 || printf '  %sinstall Homebrew from brew.sh first%s\n' "$R" "$Z"
           xcode-select --install 2>/dev/null || printf '  %sxcode tools already present%s\n' "$D" "$Z" ;;
      u|U) do_uninstall ;;
      q|Q) printf '\n'; exit 0 ;;
      "")  printf '\n'; do_install yes ;;
      *)   continue ;;
    esac
    printf '\n  %spress any key%s' "$D" "$Z"; read -rsn1 _; clear
  done
}

clear
menu
