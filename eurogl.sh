#!/bin/bash

# Requirements: yad, curl, unzip, find, sudo (if device mount needed)

GL_URL="https://registry.khronos.org/OpenGL/api/GL.zip"
MNTDIR="/mnt/mediumiso"

# Get list of block devices for selection
get_devices() {
    lsblk -ndo NAME,SIZE,MODEL | grep -v loop | while read -r name size model ; do
        echo "/dev/$name" "$name $size $model"
    done
}

select_device() {
    DEV=$(get_devices | yad --list --title="MediumISO: Select Target Device" \
        --width=600 --height=400 --column="Device" --column="Description" --print-column=1 --single-select --separator=" " --center)
    echo "$DEV"
}

mount_device() {
    local DEV=$1
    MNT=$(lsblk -no MOUNTPOINT "$DEV" | grep -v '^$' | head -n1)
    if [ -z "$MNT" ]; then
        sudo mkdir -p "$MNTDIR"
        sudo mount "$DEV" "$MNTDIR"
        echo "$MNTDIR"
        export MISO_UMOUNT="yes"
    else
        echo "$MNT"
        export MISO_UMOUNT=""
    fi
}

unmount_device() {
    local DEV=$1
    [ "$MISO_UMOUNT" = "yes" ] && sudo umount "$DEV"
}

download_and_extract() {
    TMPDIR=$(mktemp -d)
    yad --info --text="Downloading OpenGL API..." --timeout=2 --center
    curl -fsSL "$GL_URL" -o "$TMPDIR/GL.zip" || {
        yad --error --text="Failed to download OpenGL API archive!" --center
        exit 1
    }
    unzip -q "$TMPDIR/GL.zip" -d "$TMPDIR"
    # Remove HTML and image files
    find "$TMPDIR" -type f \( -iname "*.html" -o -iname "*.htm" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" -o -iname "*.svg" \) -delete
    echo "$TMPDIR"
}

copy_to_device() {
    local SRC="$1"
    local DEST="$2/OpenGL-API"
    sudo mkdir -p "$DEST"
    sudo cp -r "$SRC"/* "$DEST"
    sudo chown -R $(whoami):$(whoami) "$DEST"
}

main() {
    DEV=$(select_device)
    [ -z "$DEV" ] && exit 1

    MNT=$(mount_device "$DEV")
    if [ ! -d "$MNT" ]; then
        yad --error --text="Failed to mount device!" --center
        exit 1
    fi

    TMPDIR=$(download_and_extract)
    copy_to_device "$TMPDIR" "$MNT"
    yad --info --text="OpenGL API (no HTML/images) installed to $MNT/OpenGL-API" --center

    unmount_device "$DEV"
    rm -rf "$TMPDIR"
}

main
