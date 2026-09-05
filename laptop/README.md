# Laptop migration

This directory contains portable configuration selected from the current Arch
Linux laptop. It excludes credentials, browser/application profiles, bookmarks,
caches, logs, generated state, machine identifiers, and hardware-specific
monitor or disk settings.

## Restore

From the repository root on the target laptop:

```sh
install -Dm644 laptop/home/.bashrc "$HOME/.bashrc"
install -Dm644 laptop/home/.bash_profile "$HOME/.bash_profile"
install -Dm644 laptop/home/.xprofile "$HOME/.xprofile"
mkdir -p "$HOME/.config"
cp -a laptop/home/.config/. "$HOME/.config/"
sudo install -Dm644 laptop/system/etc/tlp.d/99-laptop-battery.conf \
  /etc/tlp.d/99-laptop-battery.conf
sudo install -Dm644 laptop/system/etc/systemd/system/powertop-autotune.service \
  /etc/systemd/system/powertop-autotune.service
sudo systemctl daemon-reload
sudo systemctl enable --now tlp.service
```

The system files must be copied with `sudo`. Neovim plugins are installed by
the configuration; generated plugin lock/state files are omitted. Existing
shared desktop configurations under `ghostty/`, `hypr/`, `tofi/`, `waybar/`,
and `zsh/` remain in their existing repository locations.

## Power management

TLP is the primary power-management service. `power-profiles-daemon` must
remain disabled or masked; do not enable it alongside TLP. The Powertop unit is
an optional one-shot service that applies Powertop runtime tunables at boot.
It can override TLP choices, so enable it only after reviewing the target
hardware:

```sh
sudo systemctl disable --now power-profiles-daemon.service 2>/dev/null || true
sudo systemctl enable powertop-autotune.service
```

No battery charge thresholds were captured because none were explicitly
configured. No udev, modprobe, or systemd preset files were present for this
laptop.

## Package manifests

`packages-pacman-laptop.txt` is the exact sorted output of `pacman -Qqn`;
`packages-aur-laptop.txt` is the exact sorted output of `pacman -Qqm`. They
contain no overlap. Review the lists before restoring rather than installing
everything blindly. Desktop- or workload-specific examples include Hyprland,
Niri, Waybar, Ghostty, Kitty, Dunst, OBS Studio, Steam, LibreOffice, TeX,
games, VPN clients, and application launchers; these are not required for a
minimal laptop restore.

Install selected packages with:

```sh
sudo pacman -S --needed - < packages-pacman-laptop.txt
paru -S --needed - < packages-aur-laptop.txt
```
