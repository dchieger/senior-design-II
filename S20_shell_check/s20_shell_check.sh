#!/bin/bash

# EMBA - EMBEDDED LINUX ANALYZER (Modified for DigitalOcean)
#
# Original Copyright 2020-2024 Siemens Energy AG
# Modifications for DigitalOcean environment

# Set up environment variables
export FIRMWARE_PATH="/root/senior-design-II/deep_password_search/firmware"
export CONFIG_DIR="/root/senior-design-II/deep_password_search/config"
export TMP_DIR="/root/senior-design-II/deep_password_search/tmp"
export LOG_PATH_MODULE="/root/senior-design-II/deep_password_search/logs"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print output
print_output() {
    echo -e "${1}"
    [[ -n "${3}" ]] && echo -e "${1}" >> "${3}"
}

# Function to write CSV log
write_csv_log() {
    echo "${1},${2},${3},${4}" >> "${LOG_PATH_MODULE}/shell_check_results.csv"
}

S20_shell_check() {
    echo "Starting shell script check"
    
    S20_SHELL_VULNS=0
    S20_SCRIPTS=0
    
    # Ensure necessary directories exist
    mkdir -p "${TMP_DIR}" "${LOG_PATH_MODULE}"
    
    # Find shell scripts
    mapfile -t SH_SCRIPTS < <(find "${FIRMWARE_PATH}" -type f -exec file {} \; | grep "shell script" | cut -d: -f1 | sort -u)
    
    write_csv_log "Script path" "Shell issues detected" "common linux file" "shellcheck"
    
    for SH_SCRIPT in "${SH_SCRIPTS[@]}"; do
        ((S20_SCRIPTS+=1))
        s20_script_check "${SH_SCRIPT}"
    done
    
    if [[ -f "${TMP_DIR}/S20_VULNS.tmp" ]]; then
        S20_SHELL_VULNS=$(awk '{sum += $1} END {print sum}' "${TMP_DIR}/S20_VULNS.tmp")
        rm "${TMP_DIR}/S20_VULNS.tmp"
    fi
    
    echo "Summary of shell issues (shellcheck)"
    print_output "[+] Found ${ORANGE}${S20_SHELL_VULNS}${NC} issues in ${ORANGE}${S20_SCRIPTS}${NC} shell scripts"
    
    echo "Statistics:${S20_SHELL_VULNS}:${S20_SCRIPTS}" >> "${LOG_PATH_MODULE}/statistics.log"
}

s20_script_check() {
    local SH_SCRIPT_="${1:-}"
    local NAME=$(basename "${SH_SCRIPT_}" | sed -e 's/:/_/g')
    local SHELL_LOG="${LOG_PATH_MODULE}/shellchecker_${NAME}.txt"
    
    # Ensure shellcheck is installed
    if ! command -v shellcheck &> /dev/null; then
        echo "shellcheck is not installed. Installing now..."
        sudo apt-get update && sudo apt-get install -y shellcheck
    fi
    
    shellcheck -C "${SH_SCRIPT_}" > "${SHELL_LOG}" 2>/dev/null || true
    local VULNS=$(grep -c "\\^-- SC" "${SHELL_LOG}" 2>/dev/null || true)
    
    s20_reporter "${VULNS}" "${SH_SCRIPT_}" "${SHELL_LOG}"
}

s20_reporter() {
    local VULNS="${1:0}"
    local SH_SCRIPT_="${2:0}"
    local SHELL_LOG="${3:0}"
    
    if [[ "${VULNS}" -ne 0 ]]; then
        if [[ "${VULNS}" -gt 20 ]]; then
            print_output "[+] Found ${RED}${VULNS} issues${NC} in script: ${SH_SCRIPT_}" "" "${SHELL_LOG}"
        else
            print_output "[+] Found ${ORANGE}${VULNS} issues${NC} in script: ${SH_SCRIPT_}" "" "${SHELL_LOG}"
        fi
        write_csv_log "${SH_SCRIPT_}" "${VULNS}" "NA" "shellcheck"
        echo "${VULNS}" >> "${TMP_DIR}/S20_VULNS.tmp"
    fi
}

# Main execution
echo "Shell Script Checker for DigitalOcean"
S20_shell_check
echo "Check complete. Results are in ${LOG_PATH_MODULE}"