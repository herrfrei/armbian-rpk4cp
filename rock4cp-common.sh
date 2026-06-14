#!/bin/bash
# rock4cp-common.sh — shared helper functions for Rock 4C+ setup scripts
#
# Do not run directly. Source this file after downloading it:
#   source /tmp/rock4cp-common.sh

# ---------------------------------------------------------------------------
# Common variables — can be overridden by the calling script before sourcing
# ---------------------------------------------------------------------------
GH_USER="${GH_USER:-herrfrei}"
GH_REPO="${GH_REPO:-armbian-rpk4cp}"
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
# Activate a vendor overlay that is already present on the system.
# Only registers the overlay name under the "overlays" key in armbianEnv.txt.
# No .dtbo download or compilation is performed.
#
function activate_vendor_overlay {
    local OVERLAY="$1"
    check_or_install_temp_script \
        "https://raw.githubusercontent.com/${GH_USER}/${GH_REPO}/${BRANCH}/armbian-activate-overlay"
    /tmp/armbian-activate-overlay "${OVERLAY}"
}
