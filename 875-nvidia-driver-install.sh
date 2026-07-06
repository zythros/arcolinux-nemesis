#!/bin/bash
#set -e
##################################################################################################################################
# Author    : zythros
# Purpose   : Install the NVIDIA open kernel module (DKMS) driver stack.
#             Must run BEFORE 880-nvidia-xorg-setup.sh — that script writes the
#             Xorg BusID pin / AutoAddGPU flag / modeset kernel param this driver needs
#             to survive a reboot with dual same-vendor GPUs (GA106 display + GA102 passthrough).
##################################################################################################################################
#
#   DO NOT JUST RUN THIS. EXAMINE AND JUDGE. RUN AT YOUR OWN RISK.
#
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
echo "################### Installing NVIDIA open DKMS driver"
echo "########################################################################"
tput sgr0
echo

if ! lspci | grep -qi "nvidia"; then
    tput setaf 1
    echo "ERROR: No NVIDIA GPU detected via lspci. Aborting."
    tput sgr0
    exit 1
fi

echo "Detected NVIDIA hardware:"
lspci | grep -i "nvidia"
echo

##################################################################################################################################
# 1. Install packages
##################################################################################################################################

# nvidia-open-dkms : open-source kernel modules, built via DKMS against the running kernel headers
# nvidia-utils     : userspace driver libraries (OpenGL/Vulkan/EGL)
# nvidia-settings  : GUI configuration tool
# egl-wayland       : EGLStream backend, needed for NVIDIA under Wayland sessions (Plasma)
PACKAGES=(
    nvidia-open-dkms
    nvidia-utils
    nvidia-settings
    egl-wayland
)

if grep -q "^\[multilib\]" /etc/pacman.conf; then
    PACKAGES+=(lib32-nvidia-utils)
else
    tput setaf 3
    echo "multilib repo not enabled — skipping lib32-nvidia-utils (needed for 32-bit games/Proton)."
    tput sgr0
fi

if sudo pacman -S --noconfirm --needed "${PACKAGES[@]}"; then
    tput setaf 2
    echo "Packages installed."
    tput sgr0
else
    tput setaf 1
    echo "ERROR: pacman failed — aborting. Fix the conflict above and re-run."
    tput sgr0
    exit 1
fi

##################################################################################################################################
# 2. Verify the DKMS module actually built for the running kernel
##################################################################################################################################

echo
KREL="$(uname -r)"
if dkms status | grep -qi "nvidia.*${KREL}.*installed"; then
    tput setaf 2
    echo "DKMS module built and installed for kernel ${KREL}."
    tput sgr0
else
    tput setaf 1
    echo "WARNING: dkms status shows no installed NVIDIA module for kernel ${KREL}."
    echo "Check 'dkms status' and 'journalctl -u dkms' before rebooting — booting with"
    echo "no built module means Xorg will fall back to nouveau/modesetting."
    tput sgr0
fi

##################################################################################################################################

echo
tput setaf 6
echo "##############################################################"
echo "###################  $(basename $0) done"
echo "##############################################################"
echo
echo "Installed: ${PACKAGES[*]}"
echo
echo "NEXT STEP: run 880-nvidia-xorg-setup.sh before rebooting."
echo "Rebooting now, with the driver installed but without that Xorg config,"
echo "is what previously crashed Xorg before reaching SDDM (dual same-vendor GPU"
echo "autodetect assigning the second card to modesetting -> glamor_init crash)."
echo
tput sgr0
