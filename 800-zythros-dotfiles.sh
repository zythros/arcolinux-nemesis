#!/bin/bash
#set -e
##################################################################################################################################
# Author    : zythros
# Purpose   : Apply personal dotfiles, install suckless tools, and rebuild chadwm
##################################################################################################################################
#
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
#
##################################################################################################################################
#tput setaf 0 = black
#tput setaf 1 = red
#tput setaf 2 = green
#tput setaf 3 = yellow
#tput setaf 4 = dark blue
#tput setaf 5 = purple
#tput setaf 6 = cyan
#tput setaf 7 = gray
#tput setaf 8 = light blue
##################################################################################################################################

installed_dir=$(dirname $(readlink -f $(basename `pwd`)))

##################################################################################################################################

if [ "$DEBUG" = true ]; then
    echo
    echo "------------------------------------------------------------"
    echo "Running $(basename $0)"
    echo "------------------------------------------------------------"
    echo
    read -n 1 -s -r -p "Debug mode is on. Press any key to continue..."
    echo
fi

##################################################################################################################################

echo
tput setaf 2
echo "########################################################################"
echo "################### Installing zythros personal dotfiles"
echo "########################################################################"
tput sgr0
echo

# Remove picom-git (conflicts with picom or not needed)
if pacman -Qi picom-git &>/dev/null; then
    tput setaf 3
    echo "Removing picom-git..."
    tput sgr0
    sudo pacman -Rns --noconfirm picom-git
fi

# Copy .config files from zythros-personal
if [ -d "$installed_dir/zythros-personal/.config" ]; then
    cp -rv "$installed_dir/zythros-personal/.config/"* "$HOME/.config/"
    tput setaf 2
    echo "Copied zythros-personal .config files to ~/.config/"
    tput sgr0
fi

# Copy .local/share/applications (custom .desktop files)
if [ -d "$installed_dir/zythros-personal/.local/share/applications" ]; then
    mkdir -p "$HOME/.local/share/applications"
    cp -rv "$installed_dir/zythros-personal/.local/share/applications/"* "$HOME/.local/share/applications/"
    tput setaf 2
    echo "Copied custom .desktop files to ~/.local/share/applications/"
    tput sgr0
fi

# Copy .local/bin (volume scripts, etc.)
if [ -d "$installed_dir/zythros-personal/.local/bin" ]; then
    mkdir -p "$HOME/.local/bin"
    cp -rv "$installed_dir/zythros-personal/.local/bin/"* "$HOME/.local/bin/"
    chmod +x "$HOME/.local/bin/"*
    tput setaf 2
    echo "Copied scripts to ~/.local/bin/"
    tput sgr0
fi

# Set up wallpaper system (calls separate script)
if [ -f "$installed_dir/810-wallpaper-setup.sh" ]; then
    bash "$installed_dir/810-wallpaper-setup.sh"
fi

# Set up dmenu (calls separate script)
if [ -f "$installed_dir/820-dmenu-setup.sh" ]; then
    bash "$installed_dir/820-dmenu-setup.sh"
fi

# Set up snapper for BTRFS snapshots (calls separate script)
# Script will check for BTRFS and skip if not present
if [ -f "$installed_dir/840-snapper-setup.sh" ]; then
    bash "$installed_dir/840-snapper-setup.sh"
fi

# Set up SDDM theme background (calls separate script)
if [ -f "$installed_dir/850-sddm-theme-setup.sh" ]; then
    bash "$installed_dir/850-sddm-theme-setup.sh"
fi

# Set up PipeWire audio (calls separate script)
if [ -f "$installed_dir/860-audio-setup.sh" ]; then
    bash "$installed_dir/860-audio-setup.sh"
fi

# Set up VM clipboard sharing (uncomment for VMs)
#bash "$installed_dir/870-vm-clipboard-setup.sh"

# Host-only scripts — skip when running inside a VM
if ! systemd-detect-virt -q --vm; then
    # Install NVIDIA open DKMS driver stack (must run before 880)
    if [ -f "$installed_dir/875-nvidia-driver-install.sh" ]; then
        bash "$installed_dir/875-nvidia-driver-install.sh"
    fi

    # Configure NVIDIA Xorg driver + kernel modeset param (fixes SDDM not reaching login screen)
    if [ -f "$installed_dir/880-nvidia-xorg-setup.sh" ]; then
        bash "$installed_dir/880-nvidia-xorg-setup.sh"
    fi

    # Configure VFIO passthrough for RTX 3090 (isolates it from nvidia driver for VM passthrough)
    if [ -f "$installed_dir/890-vfio-passthrough.sh" ]; then
        bash "$installed_dir/890-vfio-passthrough.sh"
    fi

    # Install and configure virt-manager / QEMU-KVM (registers /mnt/vmssd storage pool)
    if [ -f "$installed_dir/895-virt-manager-setup.sh" ]; then
        bash "$installed_dir/895-virt-manager-setup.sh"
    fi
fi

##################################################################################################################################
# Rebuild chadwm with personal config
##################################################################################################################################

if [ -f "$HOME/.config/arco-chadwm/chadwm/config.def.h" ]; then
    echo
    tput setaf 3
    echo "########################################################################"
    echo "################### Rebuilding chadwm with personal config"
    echo "########################################################################"
    tput sgr0
    echo

    cd "$HOME/.config/arco-chadwm/chadwm"

    # Delete config.h to force regeneration from our config.def.h
    # (make clean does NOT remove config.h, so we must do it manually)
    rm -f config.h

    sudo make clean install

    tput setaf 2
    echo "Chadwm rebuilt successfully"
    tput sgr0
fi

##################################################################################################################################
# Summary
##################################################################################################################################

echo
tput setaf 6
echo "##############################################################"
echo "###################  $(basename $0) done"
echo "##############################################################"
echo
echo "Installed components:"
echo "  - chadwm (personal config with dwm-rev1 style tags)"
echo "  - bar.sh (simple shell status bar)"
echo "  - dmenu (zythros fork: center, grid, border patches)"
echo "  - wallpaper.sh (MOD+w / MOD+Shift+w)"
echo "  - sxhkd keybinds"
echo "  - alacritty config (fish shell)"
echo "  - custom .desktop files (lxappearance)"
echo "  - snapper (BTRFS only: automatic snapshots + grub integration)"
echo "  - SDDM theme (background image)"
echo "  - PipeWire audio"
echo "  - VM clipboard sharing (spice-vdagent, VMs only)"
echo
echo "Key bindings:"
echo "  MOD + d         : dmenu"
echo "  MOD + Space     : Show keybinds"
echo "  MOD + s         : Screenshot (flameshot)"
echo "  MOD + w         : Next wallpaper"
echo "  MOD + Shift + w : Previous wallpaper"
echo "  MOD + Return    : Alacritty (fish)"
echo
tput sgr0
echo
