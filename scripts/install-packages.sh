#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
[[ $EUID -ne 0 ]] || { echo "Run this script as a regular user with sudo access." >&2; exit 1; }

usage() {
  cat <<'EOF'
Usage: install-packages.sh [--interactive] [--laptop] [--optional]

Interactive mode is the default. It selects packages, shared Stow packages,
and laptop-only dotfiles and system services without overwriting existing files.
EOF
}

for arg in "$@"; do
  case "$arg" in
    --interactive) ;;
    --laptop) noninteractive_laptop=true ;;
    --optional) noninteractive_optional=true ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
  esac
done

noninteractive_laptop="${noninteractive_laptop:-false}"
noninteractive_optional="${noninteractive_optional:-false}"

read_yes_no() {
  local prompt="$1" default="${2:-y}" answer
  while true; do
    if [[ "$default" == y ]]; then
      read -r -p "$prompt [Y/n] " answer || exit 1
    else
      read -r -p "$prompt [y/N] " answer || exit 1
    fi
    answer="${answer:-$default}"
    case "${answer,,}" in y|yes) return 0;; n|no) return 1;; esac
  done
}

read_choice() {
  local prompt="$1" choices="$2" answer
  while true; do
    read -r -p "$prompt [$choices] " answer || exit 1
    [[ "$answer" =~ ^[0-9]+$ ]] && printf '%s\n' "$answer" && return
  done
}

packages_from() {
  sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' "$repo_dir/$1"
}

select_packages() {
  local manifest="$1" mode="$2" package
  local -a selected=()
  while read -r package; do
    if [[ "$mode" == all ]] || read_yes_no "Install $package?" y; then
      selected+=("$package")
    fi
  done < <(packages_from "$manifest")
  printf '%s\0' "${selected[@]}"
}

install_official() {
  local -a selected=()
  while IFS= read -r -d '' package; do selected+=("$package"); done
  # 변경점: 빈 배열일 때 set -e로 인해 스크립트가 종료되는 것을 방지
  ((${#selected[@]})) || return 0
  sudo pacman -S --needed "${selected[@]}"
}

install_aur() {
  local -a selected=()
  while IFS= read -r -d '' package; do selected+=("$package"); done
  ((${#selected[@]})) || return 0
  if ! command -v paru >/dev/null 2>&1; then
    local build_dir
    build_dir="$(mktemp -d)"
    trap 'rm -rf "$build_dir"' EXIT
    git clone https://aur.archlinux.org/paru.git "$build_dir/paru"
    (cd "$build_dir/paru" && makepkg -si)
  fi
  paru -S --needed "${selected[@]}"
}

restore_file_no_clobber() {
  local source="$1" target="$2"
  if [[ -e "$target" || -L "$target" ]]; then
    echo "Skipping existing: $target"
  else
    sudo install -D -m 0644 "$source" "$target"
  fi
}

restore_laptop_home() {
  while IFS= read -r -d '' source; do
    local relative="${source#"$repo_dir/laptop/home/"}"
    local target="$HOME/$relative"
    if [[ "$relative" == .config/* ]]; then
      mkdir -p "$(dirname "$target")"
      if [[ -e "$target" || -L "$target" ]]; then
        echo "Skipping existing: $target"
      else
        install -D -m 0644 "$source" "$target"
      fi
    else
      if [[ -e "$target" || -L "$target" ]]; then
        echo "Skipping existing: $target"
      else
        install -D -m 0644 "$source" "$target"
      fi
    fi
  done < <(find "$repo_dir/laptop/home" -type f -print0)
}

restore_laptop_system() {
  local source relative target
  while IFS= read -r -d '' source; do
    relative="${source#"$repo_dir/laptop/system/"}"
    target="/$relative"
    if [[ -e "$target" || -L "$target" ]]; then
      echo "Skipping existing system file: $target"
    else
      sudo install -D -m 0644 "$source" "$target"
    fi
  done < <(find "$repo_dir/laptop/system" -type f -print0)
  sudo systemctl daemon-reload
}

stow_shared() {
  local -a packages=()
  local package
  for package in bash dunst ghostty gtk htop niri nvim p10k profile scripts tofi waybar xprofile zsh; do
    if read_yes_no "Apply shared Stow package '$package'?" y; then
      packages+=("$package")
    fi
  done
  ((${#packages[@]})) || return 0

  if read_yes_no "Apply the selected shared dotfiles now (force overwrite)?" y; then
    (
      cd "$repo_dir"
      # 기존 파일을 흡수하며 심볼릭 링크 생성
      stow --adopt "${packages[@]}"
      # 흡수되어 바뀐 패키지 파일을 원래 git 커밋 상태로 복구 (저장소 내용으로 덮어쓰기 완료)
      git restore "${packages[@]}"
    )
  fi
}

main() {
  local laptop="$noninteractive_laptop" optional="$noninteractive_optional"
  if [[ $laptop == false && $optional == false ]]; then
    echo "This will install packages and optionally restore dotfiles."
    read_yes_no "Install the required official packages?" y || return 0
    install_official < <(select_packages packages-pacman-required.txt choose)
    
    # 변경점: 모든 단독 && 구문을 if문으로 교체
    if read_yes_no "Install required AUR packages?" y; then
      install_aur < <(select_packages packages-aur-required.txt choose)
    fi
    
    if read_yes_no "Configure shared dotfiles with Stow?" y; then 
      stow_shared
    fi
    
    if read_yes_no "Configure this machine as a laptop?" n; then 
      laptop=true
    fi
    
    if read_yes_no "Review and install optional packages?" n; then 
      optional=true
    fi
  else
    install_official < <(select_packages packages-pacman-required.txt all)
    install_aur < <(select_packages packages-aur-required.txt all)
  fi

  if [[ $optional == true ]]; then
    install_official < <(select_packages packages-pacman-optional.txt choose)
    install_aur < <(select_packages packages-aur-optional.txt choose)
  fi

  if [[ $laptop == true ]]; then
    install_official < <(select_packages packages-pacman-laptop-required.txt choose)
    if [[ "$noninteractive_laptop" == false ]]; then
      if read_yes_no "Restore laptop home dotfiles without overwriting existing files?" y; then
        restore_laptop_home
      fi
      
      if read_yes_no "Restore laptop system files (TLP, keyd, Powertop) without overwriting existing files?" y; then
        restore_laptop_system
      fi
      
      if read_yes_no "Enable TLP and keyd now?" y; then
        sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
        sudo systemctl enable --now tlp.service
        sudo systemctl enable --now keyd.service
      fi
      
      if read_yes_no "Enable the optional Powertop autotune service?" n; then
        sudo systemctl enable --now powertop-autotune.service
      fi
    fi
  fi
}

main "$@"
