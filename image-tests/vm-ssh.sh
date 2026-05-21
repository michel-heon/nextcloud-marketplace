#!/usr/bin/env bash
# image-tests/vm-ssh.sh
# Connexion SSH à la VM de test (lit l'IP depuis .image-test-state)
#
# Usage : bash image-tests/vm-ssh.sh [commande optionnelle]
# Exemple: bash image-tests/vm-ssh.sh journalctl -u nextcloud-first-boot --no-pager

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=lib/common.sh
source "${PROJECT_ROOT}/image-tests/lib/common.sh"
load_state

SSH_PRIVKEY="${TEST_SSH_KEY_PATH%.pub}"

if [[ $# -gt 0 ]]; then
    # Execute a specific command on the VM
    ssh -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        -i "${SSH_PRIVKEY}" \
        "${TEST_ADMIN_USER}@${TEST_VM_IP}" \
        "$@"
else
    # Interactive session
    echo "[INFO] Connexion à ${TEST_ADMIN_USER}@${TEST_VM_IP}"
    echo "[INFO] IP : ${TEST_VM_IP} — Image : v${IMAGE_VERSION}"
    echo ""
    ssh -o StrictHostKeyChecking=no \
        -o ConnectTimeout=15 \
        -i "${SSH_PRIVKEY}" \
        "${TEST_ADMIN_USER}@${TEST_VM_IP}"
fi
