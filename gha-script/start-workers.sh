```bash
#!/usr/bin/env bash

# start-workers.sh
#
# Check all PowerCore worker services.
# Start any worker that is not active.
# Verify that all workers are active at the end.

set -euo pipefail


# ─────────────────────────────────────────────────────────────
# 1. Check powercore user
# ─────────────────────────────────────────────────────────────

if ! id powercore &>/dev/null; then
    echo "ERROR: 'powercore' user does not exist"
    exit 1
fi

POWERCORE_UID=$(id -u powercore)
XDG_RUNTIME_DIR="/run/user/${POWERCORE_UID}"
DBUS_SESSION_BUS_ADDRESS="unix:path=${XDG_RUNTIME_DIR}/bus"

echo "✓ powercore user exists"
echo "  UID: ${POWERCORE_UID}"


# ─────────────────────────────────────────────────────────────
# 2. Helper: run systemctl --user as powercore
# ─────────────────────────────────────────────────────────────

_sctl() {
    sudo -u powercore \
        XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR}" \
        DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS}" \
        systemctl --user "$@"
}


# ─────────────────────────────────────────────────────────────
# 3. PowerCore worker services
# ─────────────────────────────────────────────────────────────

WORKERS=(
    "03-preprocess"
    "04-shallow-scan"
    "05-deep-scan"
    "06-post-process"
    "07-bookkeeping"
)


# ─────────────────────────────────────────────────────────────
# 4. Check and start workers
# ─────────────────────────────────────────────────────────────

echo
echo "========================================"
echo " PowerCore Worker Status"
echo "========================================"

ALL_ACTIVE=true

for stage in "${WORKERS[@]}"; do

    SERVICE="powercore-worker@${stage}.service"

    STATUS=$(
        _sctl is-active "${SERVICE}" 2>/dev/null || true
    )

    if [ "${STATUS}" = "active" ]; then
        echo "✓ ${SERVICE}: active"
    else
        echo "⚠ ${SERVICE}: ${STATUS:-inactive}"
        echo "  Starting ${SERVICE}..."

        if _sctl start "${SERVICE}"; then
            echo "✓ ${SERVICE}: started"
        else
            echo "✗ Failed to start ${SERVICE}"
            ALL_ACTIVE=false
        fi
    fi
done


# ─────────────────────────────────────────────────────────────
# 5. Verify final status
# ─────────────────────────────────────────────────────────────

echo
echo "========================================"
echo " Final Worker Status"
echo "========================================"

for stage in "${WORKERS[@]}"; do

    SERVICE="powercore-worker@${stage}.service"

    STATUS=$(
        _sctl is-active "${SERVICE}" 2>/dev/null || true
    )

    if [ "${STATUS}" = "active" ]; then
        echo "✓ ${SERVICE}: active"
    else
        echo "✗ ${SERVICE}: ${STATUS:-inactive}"
        ALL_ACTIVE=false
    fi
done


# ─────────────────────────────────────────────────────────────
# 6. Result
# ─────────────────────────────────────────────────────────────

echo

if [ "${ALL_ACTIVE}" = "true" ]; then
    echo "========================================"
    echo " SUCCESS"
    echo " All PowerCore workers are active"
    echo "========================================"
    exit 0
else
    echo "========================================"
    echo " ERROR"
    echo " One or more PowerCore workers are not active"
    echo "========================================"
    exit 1
fi
```
