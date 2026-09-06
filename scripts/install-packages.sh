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
  ((${#selected[@]})) && sudo pacman -S --needed "${selected[@]}"
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
  echo "Previewing Stow changes (existing conflicts are not overwritten):"
  (cd "$repo_dir" && stow --simulate --verbose "${packages[@]}") || {
    echo "Stow preview reported conflicts; no shared dotfiles were applied." >&2
    return 1
  }
  read_yes_no "Apply the selected shared dotfiles now?" y &&
    (cd "$repo_dir" && stow "${packages[@]}")
}

main() {
  local laptop="$noninteractive_laptop" optional="$noninteractive_optional"
  if [[ $laptop == false && $optional == false ]]; then
    echo "This will install packages and optionally restore dotfiles."
    read_yes_no "Install the required official packages?" y || return 0
    install_official < <(select_packages packages-pacman-required.txt choose)
    read_yes_no "Install required AUR packages?" y &&
      install_aur < <(select_packages packages-aur-required.txt choose)
    read_yes_no "Configure shared dotfiles with Stow?" y && stow_shared
    if read_yes_no "Configure this machine as a laptop?" n; then laptop=true; fi
    read_yes_no "Review and install optional packages?" n && optional=true
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
      read_yes_no "Restore laptop home dotfiles without overwriting existing files?" y &&
        restore_laptop_home
      read_yes_no "Restore laptop system files (TLP, keyd, Powertop) without overwriting existing files?" y &&
        restore_laptop_system
      read_yes_no "Enable TLP and keyd now?" y && {
        sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
        sudo systemctl enable --now tlp.service
        sudo systemctl enable --now keyd.service
      }
      read_yes_no "Enable the optional Powertop autotune service?" n &&
        sudo systemctl enable --now powertop-autotune.service
    fi
  fi
}

main "$@"
