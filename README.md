# Arch Linux dotfiles

This repository contains shared desktop configuration plus optional laptop
power-management configuration. Both the desktop and laptop use the `master`
branch. Hardware-specific or sensitive state must not be copied into this
repository.

## Installation overview

1. Install Windows first if the machine will dual-boot.
2. Boot the Arch ISO and connect to the network.
3. Partition the disk and run `archinstall`.
4. Boot the new Arch installation and update it.
5. Install the package sets needed for the machine.
6. Clone this repository and apply the shared Stow packages.
7. Apply the laptop-only files only on a laptop.
8. Enable the appropriate services and reboot.

The commands below assume a UEFI system, an existing user with `sudo`
privileges, and a repository checkout at `~/dotfiles`.

## Before installing

Back up any files that matter. Verify the target disk and partition names
before running formatting or partitioning commands. The examples below are
destructive when pointed at the wrong disk; never paste them without checking
`lsblk` and `fdisk -l`.

For a Windows/Arch dual boot, install Windows first and leave unallocated
space for Arch. Windows should use a GPT partition table and an EFI System
Partition. Arch can reuse the existing EFI System Partition; do not format it
when installing Arch.

The following Windows installer workflow is one possible manual layout, not a
requirement:

```text
EFI System Partition: 300 MiB, FAT32
Windows:              space required by Windows
Arch:                 remaining unallocated space
```

If using `diskpart`, confirm the disk number carefully. `clean` erases the
selected disk.

## Boot the Arch ISO

Download the current ISO from <https://archlinux.org/download/> and write it
to a USB drive. Boot the USB in UEFI mode.

### Connect to Wi-Fi

For the normal Arch ISO network setup:

```sh
iwctl
device list
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "SSID"
exit
ping -c 3 archlinux.org
```

Replace `wlan0` with the device reported by `device list`. If the SSID
contains spaces, keep the quotes. A wired connection usually works without
additional setup.

### Verify the clock and disk

```sh
timedatectl set-ntp true
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS,PARTUUID,UUID
fdisk -l
```

## Partitioning

The exact partition sizes depend on the disk and RAM. A common UEFI layout is:

```text
Existing EFI System Partition: 300 MiB or larger, shared with Windows
Linux swap:                   RAM-sized if hibernation is required
Linux root `/`:               about 30 GiB or more
Linux home `/home`:           remaining space
```

Swap does not need to be RAM-sized unless hibernation is required. zram is
also an option for systems that do not need disk-backed hibernation.

Use `cfdisk` only after confirming the disk:

```sh
cfdisk /dev/nvme0n1
```

After creating the Linux partitions, format only the new Linux partitions.
Replace the placeholders with the actual partition names:

```sh
mkfs.ext4 /dev/<root-partition>
mkfs.ext4 /dev/<home-partition>
mkswap /dev/<swap-partition>
```

Do not run `mkfs` on the Windows EFI partition. If Arch will use the existing
EFI partition, it should be mounted during installation but not formatted.

## Install Arch with archinstall

Start the guided installer:

```sh
archinstall
```

Recommended choices for this repository:

### Locale and mirrors

- Keyboard layout: choose the physical keyboard layout.
- Locale: `en_US.UTF-8` or the preferred locale.
- Time zone: `Asia/Seoul`.
- Mirror region: `South Korea` or a nearby reliable region.

### Disk configuration

Choose manual partitioning:

- Mount the existing EFI System Partition at `/boot`.
- Mount the new root partition at `/`.
- Mount the new home partition at `/home`.
- Configure swap if using a swap partition.
- Format only the new Linux root and home partitions.
- Do not format the Windows EFI partition.

The repository's Niri configuration contains output names and modes from one
machine. Review the `output` blocks before using it on another machine.

### Profile and graphics

This repository currently uses Niri, Waybar, and Wayland utilities. Install a
minimal profile and add the required packages below; the older Hyprland notes
are not the current restore path. Intel integrated graphics normally use the
open-source driver. NVIDIA systems need the driver choice appropriate for
their GPU and kernel.

For a login manager, `ly` can be used if desired, but it is optional. A
terminal login followed by starting the compositor is also valid.

### Network and audio

- Network configuration: `NetworkManager` (the standard backend).
- Audio: `PipeWire`.
- Bluetooth: enable it if needed.

### User and security

Create the normal user account, set a root password if desired, and grant the
user `sudo` access. Do not put passwords, tokens, SSH keys, or authentication
databases in this repository.

### Packages to select in archinstall

Add these packages in `Additional packages` so the first boot already has a
working network, audio, compositor, terminal, editor, and repository tools:

```text
base-devel git sudo stow networkmanager
pipewire pipewire-pulse wireplumber
zsh neovim ghostty niri waybar dunst
fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool fcitx5-hangul
brightnessctl wl-clipboard xdg-desktop-portal xdg-desktop-portal-gtk
```

For the laptop profile, also select:

```text
tlp powertop keyd htop fontconfig
```

Add a browser, file manager, and applications such as `nautilus`, `firefox`,
or `zed` according to the machine's purpose. Do not paste the entire package
manifest into `archinstall`; those lists include optional applications,
libraries, development dependencies, games, and packages from the source
machines that are not required everywhere.

## First boot

After `archinstall` completes:

```sh
reboot
```

Log in and update the system. NetworkManager was selected during
`archinstall`, so no chroot workaround or manual replacement of the network
backend is needed:

```sh
sudo pacman -Syu
```

Confirm the expected service if needed:

```sh
systemctl status NetworkManager.service
```

## Install package sets

The package manifests are snapshots from the source systems:

| File | Meaning |
| --- | --- |
| `packages-pacman.txt` | Official Arch packages for the broader desktop setup |
| `packages-aur.txt` | AUR/foreign packages for the broader desktop setup |
| `packages-pacman-laptop.txt` | Official packages captured from the laptop |
| `packages-aur-laptop.txt` | AUR/foreign packages captured from the laptop |

The lists are intentionally broad and include desktop and workload-specific
software. Examples include games, OBS Studio, LibreOffice, TeX, VPN clients,
development tools, and desktop applications. Review them and install a
smaller set when building a different machine.

Official packages:

```sh
sudo pacman -S --needed - < packages-pacman.txt
```

For a laptop, use the laptop list instead or in addition to a reviewed common
set:

```sh
sudo pacman -S --needed - < packages-pacman-laptop.txt
```

Install `paru` before installing AUR packages. This is the only package that
must be bootstrapped from the AUR manually:

```sh
git clone https://aur.archlinux.org/paru.git
cd paru
makepkg -si
cd ..
rm -rf paru
```

Then install a reviewed AUR set:

```sh
paru -S --needed - < packages-aur.txt
```

For a laptop:

```sh
paru -S --needed - < packages-aur-laptop.txt
```

`tofi` is also an AUR package in the current setup, so install it after
`paru` if it was not included in the selected AUR manifest:

```sh
paru -S --needed tofi
```

The AUR list may include `paru` and `paru-debug` because they were installed
on the source system. Do not reinstall `paru` from its own manifest before the
bootstrap step is complete.

## Clone and apply the repository

Use `master` on both desktop and laptop:

```sh
git clone https://github.com/SuwonJ/dotfiles-A.git ~/dotfiles
cd ~/dotfiles
git switch master
```

The repository is organized as Stow packages. Apply only the shared packages
you want; do not use `stow *`, because that would also try to treat package
manifests and the laptop directory as Stow packages.

```sh
stow bash dunst ghostty gtk htop niri nvim p10k profile tofi waybar xprofile zsh
```

`stow` creates links from the package directories into `$HOME`. Existing
files can conflict. Inspect them first and move a personal file aside rather
than overwriting it:

```sh
stow -nv bash dunst ghostty gtk htop niri nvim p10k profile tofi waybar xprofile zsh
```

The repository does not contain `.gitconfig`, browser profiles, cookies,
credentials, SSH keys, GPG keys, or application databases. Configure those
locally and keep them out of Git.

## Shared desktop configuration

These packages are intended to be shared between machines:

```text
bash/       bash startup files
dunst/      notifications
ghostty/    terminal and theme
gtk/        GTK 3 and GTK 4 appearance
htop/       process viewer
niri/       Wayland compositor
nvim/       Neovim/LazyVim configuration
p10k/       Powerlevel10k prompt
profile/    login environment
tofi/       application launcher
waybar/     status bar and scripts
xprofile/   X session environment compatibility
zsh/        Zsh configuration
```

The Niri configuration starts Waybar, PipeWire-related desktop components,
Fcitx5, dark GTK preferences, and other user applications. Review startup
commands and output blocks on a new machine before starting Niri.

### Korean input with Fcitx5

This setup uses Fcitx5, not Nimf. The repository includes the Fcitx5
configuration under the laptop package because it was captured from the
laptop. The relevant official packages are:

```sh
sudo pacman -S --needed fcitx5 fcitx5-gtk fcitx5-qt fcitx5-configtool fcitx5-hangul
```

The Niri configuration starts Fcitx5 and the Ghostty binding supplies the
relevant Wayland environment for that terminal. Nimf instructions from older
notes are not part of the current restore path.

### Fonts

The fontconfig file refers to `Pretendard`, `SUITE`, and `MaruBuri`. Install
the fonts separately from trusted sources, then rebuild the font cache:

```sh
fc-cache -f
fc-list | grep -Ei 'Pretendard|SUITE|MaruBuri'
```

Do not copy an entire font directory into the repository.

## Laptop-only setup

Apply this section only on a laptop. The files are stored in `laptop/` so
their presence in the repository does not affect a desktop until explicitly
installed.

### User files

```sh
cd ~/dotfiles
install -Dm644 laptop/home/.bashrc "$HOME/.bashrc"
install -Dm644 laptop/home/.bash_profile "$HOME/.bash_profile"
install -Dm644 laptop/home/.xprofile "$HOME/.xprofile"
install -Dm644 p10k/.p10k.zsh "$HOME/.p10k.zsh"
mkdir -p "$HOME/.config"
cp -a laptop/home/.config/. "$HOME/.config/"
```

If the shared Stow packages are already installed, prefer the shared versions
and copy only the laptop-specific Fcitx5, fontconfig, GTK, and htop files
that are desired.

### TLP and Powertop

TLP is the primary power-management service. Do not enable
`power-profiles-daemon` alongside it:

```sh
sudo pacman -S --needed tlp powertop
sudo systemctl mask --now power-profiles-daemon.service 2>/dev/null || true
sudo install -Dm644 laptop/system/etc/tlp.d/99-laptop-battery.conf \
  /etc/tlp.d/99-laptop-battery.conf
sudo install -Dm644 laptop/system/etc/systemd/system/powertop-autotune.service \
  /etc/systemd/system/powertop-autotune.service
sudo systemctl daemon-reload
sudo systemctl enable --now tlp.service
```

The Powertop unit is optional. It applies Powertop runtime tunables once at
boot and may override or duplicate TLP policy. Enable it only after checking
the target hardware:

```sh
sudo systemctl enable powertop-autotune.service
```

No battery charge thresholds were captured because none were explicitly
configured. Do not copy `/etc/tlp.conf` wholesale: it may contain
hardware-specific settings.

### keyd

The laptop's keyd configuration makes Caps Lock act as Control when held and
Caps Lock when tapped:

```sh
sudo pacman -S --needed keyd
sudo install -Dm644 laptop/system/etc/keyd/default.conf \
  /etc/keyd/default.conf
sudo systemctl enable --now keyd.service
```

Do not enable this if the target laptop already has a conflicting keyboard
remapping service.

## Desktop-only considerations

The repository contains the current Niri-based desktop configuration. A
desktop may omit laptop TLP, Powertop, and keyd files. Install desktop
applications from the reviewed `packages-pacman.txt` and `packages-aur.txt`
lists as needed.

The package snapshot also contains legacy or alternative desktop software.
This is intentional inventory, not a requirement to install every package.
For a smaller desktop, start with the compositor, terminal, bar, launcher,
audio, network, input method, editor, and browser, then add applications
individually.

## Bootloader and dual boot

When using the shared EFI partition, verify the installed boot entries:

```sh
efibootmgr -v
```

Do not create a new entry until you know which EFI partition and loader path
the installation uses. `efibootmgr` examples often use `/dev/nvme0n1` and
partition `1`; those values are machine-specific and must not be copied
blindly.

Windows Fast Startup and hibernation can leave NTFS filesystems dirty. Disable
Fast Startup in Windows before writing to shared Windows partitions from Arch.

## Verification

After applying the configuration:

```sh
systemctl --failed
systemctl --user --failed
fcitx5-remote -r 2>/dev/null || true
niri validate 2>/dev/null || true
```

Start Niri from the login manager or a Wayland session. Check:

- keyboard layout and Korean input;
- terminal, launcher, Waybar, notifications, and audio;
- external displays after reviewing Niri output names;
- NetworkManager and Bluetooth if needed;
- TLP status on a laptop;
- keyd behavior on a laptop.

For laptop power policy:

```sh
tlp-stat -s
tlp-stat -c
systemctl status tlp.service powertop-autotune.service keyd.service
```

For a package inventory without changing the system:

```sh
pacman -Qqn | sort
pacman -Qqm | sort
```

## Ongoing management

Both machines should stay on `master`:

```sh
cd ~/dotfiles
git switch master
git pull --ff-only origin master
```

When changing shared configuration, edit the shared Stow package and commit it
to `master`. When changing laptop-only behavior, edit `laptop/` and document
whether the change requires `sudo` or a systemd service reload.

Use short-lived feature branches only for review. Do not maintain permanent
desktop and laptop branches; the directory layout, not branches, separates
shared and machine-specific configuration.
