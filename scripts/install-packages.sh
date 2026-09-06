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
    # stdin이 파이프에 묶여있어도 터미널(/dev/tty)에서 직접 입력을 받도록 수정
    if [[ "$default" == y ]]; then
      read -r -p "$prompt [Y/n] " answer </dev/tty || exit 1
    else
      read -r -p "$prompt [y/N] " answer </dev/tty || exit 1
    fi
    answer="${answer:-$default}"
    case "${answer,,}" in y|yes) return 0;; n|no) return 1;; esac
  done
}

read_choice() {
  local prompt="$1" choices="$2" answer
  while true; do
    read -r -p "$prompt [$choices] " answer </dev/tty || exit 1
    [[ "$answer" =~ ^[0-9]+$ ]] && printf '%s\n' "$answer" && return
  done
}

packages_from() {
  if [[ ! -f "$repo_dir/$1" ]]; then
    echo "Warning: Manifest file not found: $repo_dir/$1" >&2
    return 0
  fi
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

  # set -u 상태에서 빈 배열 참조 시 unbound variable 에러 방지
  if ((${#selected[@]} > 0)); then
    printf '%s\0' "${selected[@]}"
  fi
}

install_official() {
  local -a selected=()
  while IFS= read -r -d '' package; do selected+=("$package"); done
  
  if ((${#selected[@]} == 0)); then
    echo "No official packages to install."
    return 0
  fi
  
  echo "Installing pacman packages: ${selected[*]}"
  sudo pacman -S --needed "${selected[@]}"
}

install_aur() {
  local -a selected=()
  while IFS= read -r -d '' package; do selected+=("$package"); done
  
  if ((${#selected[@]} == 0)); then
    echo "No AUR packages to install."
    return 0
  fi

  if ! command -v paru >/dev/null 2>&1; then
    local build_dir
    build_dir="$(mktemp -d)"
    trap 'rm -rf "$build_dir"' EXIT
    git clone https://aur.archlinux.org/paru.git "$build_dir/paru"
    (cd "$build_dir/paru" && makepkg -si)
  fi

  echo "Installing AUR packages: ${selected[*]}"
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
  if [[ ! -d "$repo_dir/laptop/home" ]]; then
    echo "Notice: $repo_dir/laptop/home directory not found. Skipping."
    return 0
  fi
  while IFS= read -r -d '' source; do
    local relative="${source#"$repo_dir/laptop/home/"}"
    local target="$HOME/$relative"
    if [[ -e "$target" || -L "$target" ]]; then
      echo "Skipping existing: $target"
    else
      install -D -m 0644 "$source" "$target"
    fi
  done < <(find "$repo_dir/laptop/home" -type f -print0)
}

restore_laptop_system() {
  if [[ ! -d "$repo_dir/laptop/system" ]]; then
    echo "Notice: $repo_dir/laptop/system directory not found. Skipping."
    return 0
  fi
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

  if read_yes_no "Apply the selected shared dotfiles now (force overwrite existing via adopt)?" y; then
    (
      cd "$repo_dir"
      stow --adopt "${packages[@]}"
      git restore "${packages[@]}"
    )
  fi
}

main() {
  local laptop="$noninteractive_laptop" optional="$noninteractive_optional"

  if [[ $laptop == false && $optional == false ]]; then
    echo "This will install packages and optionally restore dotfiles."
    
    if read_yes_no "Install the required official packages?" y; then
      install_official < <(select_packages packages-pacman-required.txt choose)
    fi

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
    # 노트북 필수 패키지(tlp 등) 설치
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
        # 서비스 활성화 실패 시에도 스크립트가 죽지 않도록 방어
        sudo systemctl enable --now tlp.service || echo "Failed to enable tlp.service (Check if tlp is installed)" >&2
        sudo systemctl enable --now keyd.service || echo "Failed to enable keyd.service (Check if keyd is installed)" >&2
      fi

      if read_yes_no "Enable the optional Powertop autotune service?" n; then
        sudo systemctl enable --now powertop-autotune.service || echo "Failed to enable powertop-autotune.service" >&2
      fi
    fi
  fi
}

main "$@"
