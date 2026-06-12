#!/usr/bin/env bash
# SpaceMouse setup for FreeCAD on Arch Linux
# Tested with: SpaceNavigator (046d:c626), FreeCAD 1.1.x, spacenavd built from source
#
# Builds spacenavd from source with a one-line patch that blacklists the
# 3Dconnexion Universal Receiver (256f:c652). Without the patch, spacenavd opens
# the receiver as a second SpaceMouse device; its event dispatch filter then
# silently drops all wired SpaceNavigator events so FreeCAD gets nothing.

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
die()   { echo -e "${RED}[x]${NC} $*" >&2; exit 1; }

require_no_root() {
    [[ $EUID -ne 0 ]] || die "Run as a regular user — sudo is invoked internally where needed."
}

detect_spacemouse() {
    local found
    found=$(lsusb | grep -i "046d:c6" | grep -v "Universal Receiver" | head -1 || true)
    if [[ -z "$found" ]]; then
        warn "No wired SpaceMouse detected via lsusb — continuing anyway."
    else
        info "Detected: $found"
    fi
}

build_and_install_spacenavd() {
    local build_dir
    build_dir=$(mktemp -d)
    trap "rm -rf '$build_dir'" EXIT

    info "Cloning spacenavd from source..."
    git clone --depth=1 https://github.com/FreeSpacenav/spacenavd.git "$build_dir/spacenavd" \
        || die "git clone failed"

    info "Applying Universal Receiver blacklist patch..."
    python3 - "$build_dir/spacenavd/src/dev.c" <<'PYEOF'
import sys
path = sys.argv[1]
content = open(path).read()
entry = '\t{0x256f, 0xc652},\t/* Universal Receiver blacklisted: causes event dispatch conflict with wired SpaceNavigator */\n'
terminator = '\t{-1, -1}'
marker = '{0x256f, 0xc652}'   # specific to the blacklist struct syntax, not the existing if(pid==0xc652) line
if marker in content:
    print("  patch already present")
elif terminator not in content:
    raise SystemExit(f"ERROR: patch anchor not found in {path} — update setup.sh")
else:
    patched = content.replace(terminator, entry + terminator, 1)
    open(path, 'w').write(patched)
    assert marker in open(path).read(), "patch write failed"
    print("  patch applied: 256f:c652 blacklisted")
PYEOF

    grep -q "0xc652" "$build_dir/spacenavd/src/dev.c" \
        || die "Patch verification failed — 0xc652 not found in dev.c"
    info "Patch verified in source."

    info "Building..."
    (
        cd "$build_dir/spacenavd"
        ./configure --prefix=/usr 2>&1 | tail -5
        make -j"$(nproc)" 2>&1 | tail -10
    ) || die "Build failed"

    info "Installing binary..."
    sudo install -m755 "$build_dir/spacenavd/spacenavd" /usr/bin/spacenavd
    sudo install -m755 "$build_dir/spacenavd/spnavd_ctl" /usr/bin/spnavd_ctl
    info "spacenavd installed."
}

write_udev_rule() {
    local rule_file=/etc/udev/rules.d/99-spacemouse.rules
    if [[ -f "$rule_file" ]]; then
        info "udev rule already exists: $rule_file"
        return
    fi
    info "Writing udev rule..."
    sudo tee "$rule_file" > /dev/null <<'EOF'
KERNEL=="event*", ATTRS{idVendor}=="046d", ATTRS{idProduct}=="c626", \
    GROUP="input", MODE="0660", TAG+="uaccess"
KERNEL=="event*", ATTRS{idVendor}=="256f", \
    GROUP="input", MODE="0660", TAG+="uaccess"
EOF
    sudo udevadm control --reload-rules
    sudo udevadm trigger --attr-match=idVendor=046d
    info "udev rules reloaded."
}

ensure_input_group() {
    local user="${SUDO_USER:-$USER}"
    if groups "$user" | grep -qw input; then
        info "User '$user' is already in the 'input' group."
    else
        info "Adding '$user' to the 'input' group..."
        sudo usermod -aG input "$user"
        warn "Group change requires a new login session to take effect."
    fi
}

write_systemd_service() {
    local svc=/etc/systemd/system/spacenavd.service
    if [[ -f "$svc" ]]; then
        info "systemd service already exists."
        return
    fi
    info "Writing spacenavd.service..."
    sudo tee "$svc" > /dev/null <<'EOF'
[Unit]
Description=Spacenav daemon — free driver for 3Dconnexion 6DoF devices

[Service]
Type=forking
PIDFile=/run/spnavd.pid
ExecStart=/usr/bin/spacenavd

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
}

enable_service() {
    write_systemd_service
    info "Enabling and restarting spacenavd.service..."
    sudo systemctl enable spacenavd
    sudo systemctl restart spacenavd
    sleep 1
    if systemctl is-active --quiet spacenavd; then
        info "spacenavd is running."
    else
        die "spacenavd failed to start. Check: sudo journalctl -u spacenavd -e"
    fi
}

verify_socket() {
    local sock=/var/run/spnav.sock
    if [[ -S "$sock" ]]; then
        info "Socket present: $sock"
    else
        warn "Socket not found. Plug in the SpaceMouse and run: sudo systemctl restart spacenavd"
    fi
}

print_freecad_instructions() {
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  FreeCAD configuration"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "  1. Close FreeCAD if open, then run:"
    echo "       python3 $(dirname "$(readlink -f "$0")")/configure_freecad.py"
    echo "  2. Open FreeCAD — SpaceMouse should work immediately."
    echo "  3. For axis mapping / sensitivity: Tools → Customize → SpaceMouse"
    echo
    echo "  Troubleshooting:"
    echo "    • sudo systemctl status spacenavd"
    echo "    • cat /var/log/spnavd.log"
    echo "    • python3 $(dirname "$(readlink -f "$0")")/test_spnav.py"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
}

main() {
    require_no_root
    echo "SpaceMouse setup for FreeCAD on Arch Linux"
    echo

    detect_spacemouse
    build_and_install_spacenavd
    write_udev_rule
    ensure_input_group
    enable_service
    verify_socket
    print_freecad_instructions

    info "Setup complete."
}

main "$@"
