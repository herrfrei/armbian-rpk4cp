#!/bin/bash
# rock4cp-common.sh — shared helper functions for Rock 4C+ setup scripts
#
# Do not run directly. Source this file after downloading it:
#   source /tmp/rock4cp-common.sh

# ---------------------------------------------------------------------------
# Common variables — can be overridden by the calling script before sourcing
# ---------------------------------------------------------------------------
GH_USER="${GH_USER:-herrfrei}"
GH_REPO="${GH_REPO:-dietpi-rpk4cp}"
BRANCH="${BRANCH:-main}"
BOOT_DIR="${BOOT_DIR:-/boot}"

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

function check_root {
    if [[ "${EUID}" -ne 0 ]]; then
        echo >&2 "This script must be run as root"
        exit 1
    fi
}

function check_armbian {
    if [[ ! -f /boot/armbianEnv.txt ]]; then
        echo >&2 "This program only works on Armbian (missing /boot/armbianEnv.txt)"
        exit 1
    fi
}

function check_writeable {
    local BOOT_RW_TEST="${BOOT_DIR}/.rw_test.$$"
    if ! touch "${BOOT_RW_TEST}" 2>/dev/null; then
        echo >&2 "ERROR: ${BOOT_DIR} is mounted read-only"
        echo >&2 "Remount read-write and run the script again"
        exit 1
    fi
    rm -f "${BOOT_RW_TEST}"
}

#
# Download a file with retry logic and timeout.
#
function download {
    local SRC="$1"
    local DEST="$2"
    local retries=5
    echo "Downloading ${SRC}"
    for ((i=1; i<=retries; i++)); do
        curl --fail --silent --show-error \
             --connect-timeout 10 --max-time 30 \
             -o "${DEST}" "${SRC}" && return 0
        echo >&2 "Attempt ${i}/${retries} failed, retrying..."
        sleep 2
    done
    echo >&2 "ERROR: Failed to download ${SRC} after ${retries} attempts"
    exit 1
}

#
# Download a helper script to /tmp/ and make it executable.
# Skips the download if the script is already present and executable.
#
function check_or_install_temp_script {
    local URL="$1"
    local SCRIPT_FILE
    SCRIPT_FILE=$(basename "${URL}")
    if [[ ! -x "/tmp/${SCRIPT_FILE}" ]]; then
        download "${URL}" "/tmp/${SCRIPT_FILE}"
        chmod +x "/tmp/${SCRIPT_FILE}"
    fi
}

#
# Ensure the device-tree-compiler is available.
# The overlay DTS is compiled locally so it matches the running kernel's
# base device tree — pre-compiled blobs may be incompatible across kernel
# versions (e.g. Linux 6.12 broke pre-built overlays).
#
function check_or_install_dtc {
    if ! command -v dtc >/dev/null 2>&1; then
        echo "device-tree-compiler not found, installing..."
        apt-get update
        apt-get install -y device-tree-compiler
        if ! command -v dtc >/dev/null 2>&1; then
            echo >&2 "ERROR: dtc is still unavailable after installation"
            exit 1
        fi
    fi
}

#
# Activate a vendor overlay that is already present on the system.
# Only registers the overlay name under the "overlays" key in armbianEnv.txt.
# No .dtbo download or compilation is performed.
#
function activate_vendor_overlay {
    local OVERLAY="$1"
    if ! command -v armbian-add-overlay >/dev/null 2>&1; then
        echo >&2 "ERROR: armbian-add-overlay not found — is this an Armbian system?"
        exit 1
    fi
    # armbian-add-overlay without a path argument registers a kernel-provided
    # overlay by name under the "overlays" key in armbianEnv.txt.
    armbian-add-overlay "${OVERLAY}"
}

#
# Compile a .dts source file and register it as a user overlay via
# armbian-add-overlay, which handles compilation, placement into
# /boot/overlay-user/, and registration in armbianEnv.txt.
#
# armbian-add-overlay expects a .dts file path as its argument.
# It compiles with dtc internally (installing it if needed) and writes
# the .dtbo to /boot/overlay-user/, then adds the overlay name under
# "user_overlays" in /boot/armbianEnv.txt.
#
function compile_overlay {
    local DTS_FILE="$1"

    if ! command -v armbian-add-overlay >/dev/null 2>&1; then
        echo >&2 "ERROR: armbian-add-overlay not found — is this an Armbian system?"
        exit 1
    fi

    echo "Installing overlay via armbian-add-overlay: ${DTS_FILE}"
    armbian-add-overlay "${DTS_FILE}"
}