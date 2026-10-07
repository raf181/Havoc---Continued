#!/usr/bin/env bash

set -Eeuo pipefail
umask 077

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
readonly REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd -P)"
readonly PROFILE_TEMPLATE="${REPO_ROOT}/profiles/havoc.yaotl"
readonly PROFILE_OUTPUT="${REPO_ROOT}/profiles/classroom.generated.yaotl"
readonly CREDENTIAL_FILE="${REPO_ROOT}/data/classroom-credentials.txt"
readonly BACKUP_DIR="${REPO_ROOT}/data/classroom-backups"

LAB_INTERFACE=""
ACCEPT_POLICY=false
FRESH_STATE=false
START_SERVER=false

usage() {
    cat <<EOF
Usage:
  ${SCRIPT_NAME} --accept-classroom-policy --interface INTERFACE [options]

Required:
  --accept-classroom-policy  Confirm use is limited to the authorized classroom VMs.
  --interface INTERFACE      Dedicated VMware host-only interface to validate.

Options:
  --fresh-state              Back up the existing Teamserver database before setup.
  --start-server             Start the Teamserver after successful validation.
  -h, --help                 Show this help.

This script configures only the defensive classroom environment. It does not
generate or deliver agents, create listeners, disable security controls, or
automate post-exploitation.
EOF
}

fail() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

info() {
    printf '[INFO] %s\n' "$*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fail "Missing required command: $1"
}

while (($#)); do
    case "$1" in
        --accept-classroom-policy)
            ACCEPT_POLICY=true
            shift
            ;;
        --interface)
            (($# >= 2)) || fail "--interface requires a value"
            LAB_INTERFACE="$2"
            shift 2
            ;;
        --fresh-state)
            FRESH_STATE=true
            shift
            ;;
        --start-server)
            START_SERVER=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "Unknown argument: $1"
            ;;
    esac
done

[[ "${ACCEPT_POLICY}" == true ]] || fail "Pass --accept-classroom-policy after reviewing README.md"
[[ -n "${LAB_INTERFACE}" ]] || fail "Pass the dedicated VMware host-only interface with --interface"
((EUID != 0)) || fail "Do not run this script as root or with sudo"

cd -- "${REPO_ROOT}"

for command_name in ip ss openssl python3 nasm awk date grep install tr; do
    require_command "${command_name}"
done

[[ -x "${REPO_ROOT}/havoc" ]] || fail "Missing executable: ${REPO_ROOT}/havoc"
[[ -x "${REPO_ROOT}/client/Havoc" ]] || fail "Missing executable: ${REPO_ROOT}/client/Havoc"
[[ -r "${PROFILE_TEMPLATE}" ]] || fail "Missing profile template: ${PROFILE_TEMPLATE}"
[[ -x "${REPO_ROOT}/data/x86_64-w64-mingw32-cross/bin/x86_64-w64-mingw32-gcc" ]] || fail "Bundled x64 compiler is missing or not executable"
[[ -x "${REPO_ROOT}/data/i686-w64-mingw32-cross/bin/i686-w64-mingw32-gcc" ]] || fail "Bundled x86 compiler is missing or not executable"

ip link show dev "${LAB_INTERFACE}" >/dev/null 2>&1 || fail "Interface does not exist: ${LAB_INTERFACE}"

LAB_IP="$(ip -o -4 addr show dev "${LAB_INTERFACE}" scope global | awk 'NR == 1 { split($4, address, "/"); print address[1] }')"
[[ -n "${LAB_IP}" ]] || fail "No global IPv4 address is assigned to ${LAB_INTERFACE}"

DEFAULT_INTERFACE="$(ip -4 route show default | awk 'NR == 1 { print $5 }')"
if [[ -n "${DEFAULT_INTERFACE}" && "${LAB_INTERFACE}" == "${DEFAULT_INTERFACE}" ]]; then
    fail "${LAB_INTERFACE} carries the default route. Add a separate VMware host-only adapter and use that interface"
fi

python3 - "${LAB_IP}" <<'PY'
import ipaddress
import sys

address = ipaddress.ip_address(sys.argv[1])
private_networks = (
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
)
if not any(address in network for network in private_networks):
    raise SystemExit(
        f"[ERROR] {address} is not an RFC1918 classroom address. "
        "Configure the VMware host-only network with a private subnet."
    )
PY

if ss -H -ltn '( sport = :40056 )' | grep -q .; then
    fail "TCP 40056 is already in use. Stop the existing Teamserver before setup"
fi

install -d -m 700 "${REPO_ROOT}/data/loot" "${BACKUP_DIR}"

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"

if [[ -e "${PROFILE_OUTPUT}" ]]; then
    mv -- "${PROFILE_OUTPUT}" "${BACKUP_DIR}/classroom.generated.${timestamp}.yaotl"
fi

if [[ "${FRESH_STATE}" == true && -e "${REPO_ROOT}/data/teamserver.db" ]]; then
    mv -- "${REPO_ROOT}/data/teamserver.db" "${BACKUP_DIR}/teamserver.${timestamp}.db"
    info "Backed up the previous Teamserver database"
fi

operator_5pider_password="$(openssl rand -base64 24 | tr -d '\n')"
operator_neo_password="$(openssl rand -base64 24 | tr -d '\n')"
service_password="$(openssl rand -base64 24 | tr -d '\n')"

CLASSROOM_PROFILE_TEMPLATE="${PROFILE_TEMPLATE}" \
CLASSROOM_PROFILE_OUTPUT="${PROFILE_OUTPUT}" \
CLASSROOM_PASSWORD_5PIDER="${operator_5pider_password}" \
CLASSROOM_PASSWORD_NEO="${operator_neo_password}" \
CLASSROOM_SERVICE_PASSWORD="${service_password}" \
python3 <<'PY'
import os
import pathlib
import re

source = pathlib.Path(os.environ["CLASSROOM_PROFILE_TEMPLATE"])
destination = pathlib.Path(os.environ["CLASSROOM_PROFILE_OUTPUT"])
text = source.read_text(encoding="utf-8")

def replace_one(pattern: str, replacement: str, label: str) -> None:
    global text
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.DOTALL)
    if count != 1:
        raise SystemExit(f"[ERROR] Could not update {label} in the classroom profile")

replace_one(
    r'(Teamserver\s*\{.*?Host\s*=\s*")[^"]*(")',
    r'\g<1>127.0.0.1\g<2>',
    "Teamserver host",
)

for username, variable in (
    ("5pider", "CLASSROOM_PASSWORD_5PIDER"),
    ("Neo", "CLASSROOM_PASSWORD_NEO"),
):
    replace_one(
        rf'(user\s+"{re.escape(username)}"\s*\{{.*?Password\s*=\s*")[^"]*(")',
        rf'\g<1>{os.environ[variable]}\g<2>',
        f"operator {username}",
    )

replace_one(
    r'(Service\s*\{.*?Password\s*=\s*")[^"]*(")',
    rf'\g<1>{os.environ["CLASSROOM_SERVICE_PASSWORD"]}\g<2>',
    "service password",
)

destination.write_text(text, encoding="utf-8")
PY

printf '%s\n' \
    'CLASSROOM USE ONLY — store according to the course evidence policy.' \
    '' \
    'Teamserver management: 127.0.0.1:40056' \
    "VMware host-only address: ${LAB_IP}" \
    '' \
    'Operator: 5pider' \
    "Password: ${operator_5pider_password}" \
    '' \
    'Operator: Neo' \
    "Password: ${operator_neo_password}" \
    '' \
    "Service password: ${service_password}" \
    >"${CREDENTIAL_FILE}"

chmod 600 "${PROFILE_OUTPUT}" "${CREDENTIAL_FILE}"
[[ ! -e "${REPO_ROOT}/data/server.key" ]] || chmod 600 "${REPO_ROOT}/data/server.key"
[[ ! -e "${REPO_ROOT}/data/server.cert" ]] || chmod 644 "${REPO_ROOT}/data/server.cert"
[[ ! -e "${REPO_ROOT}/data/teamserver.db" ]] || chmod 600 "${REPO_ROOT}/data/teamserver.db"
chmod 700 "${REPO_ROOT}/data/loot" "${BACKUP_DIR}"

info "Classroom profile: ${PROFILE_OUTPUT}"
info "Instructor credentials: ${CREDENTIAL_FILE}"
info "Validated host-only address: ${LAB_IP} (${LAB_INTERFACE})"
info "No listener or agent was created"

if [[ "${START_SERVER}" == true ]]; then
    info "Starting Teamserver on 127.0.0.1:40056"
    exec "${REPO_ROOT}/havoc" server --profile "${PROFILE_OUTPUT}" --verbose
fi

cat <<EOF

Setup complete.

Start the Teamserver:
  cd ${REPO_ROOT}
  ./havoc server --profile profiles/classroom.generated.yaotl --verbose

Start the client in another terminal:
  cd ${REPO_ROOT}
  ./havoc client

Use the credentials stored in:
  ${CREDENTIAL_FILE}

Create any approved classroom listener manually on the validated host-only
address ${LAB_IP}, using a nonprivileged port such as 8443.
EOF
