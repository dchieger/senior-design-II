#!/bin/bash

# EMBA - EMBEDDED LINUX ANALYZER
#
# Copyright 2020-2024 Siemens Energy AG
#
# EMBA comes with ABSOLUTELY NO WARRANTY. This is free software, and you are
# welcome to redistribute it under the terms of the GNU General Public License.
# See LICENSE file for usage of this software.
#
# EMBA is licensed under GPLv3
# SPDX-License-Identifier: GPL-3.0-only
#
# Author(s): Michael Messner
# Modified for DigitalOcean environment

# Description:  Searches for files with a specified password pattern inside.

# Set up environment variables
export FIRMWARE_PATH="/firmware"
export CONFIG_DIR="/config"
export TMP_DIR="/tmp"
export LOG_FILE="/logs/s107_deep_password_search.log"

# Color definitions
ORANGE='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Function to log messages
log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to print colored output
print_output() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

# Function to write CSV log
write_csv_log() {
    echo "$1,$2,$3" >> "${TMP_DIR}/pw_hashes.csv"
}

S107_deep_password_search()
{
  log_message "Starting deep analysis of files for password hashes"

  local PW_HASH_CONFIG="${CONFIG_DIR}/password_regex.cfg"
  local PW_COUNTER=0
  local PW_PATH=""
  local PW_HASHES=()
  local PW_HASH=""

  # Check if necessary tools are installed
  if ! command -v grep &> /dev/null || ! command -v find &> /dev/null || ! command -v strings &> /dev/null; then
      log_message "Error: Required tools (grep, find, or strings) are not installed"
      exit 1
  fi

  # Check if necessary directories and files exist
  if [ ! -d "$FIRMWARE_PATH" ] || [ ! -d "$CONFIG_DIR" ] || [ ! -f "$PW_HASH_CONFIG" ]; then
      log_message "Error: Required directories or files are missing"
      exit 1
  fi

  find "${FIRMWARE_PATH}" -xdev -type f -exec grep -n -a -E -H -f "${PW_HASH_CONFIG}" {} \; > "${TMP_DIR}/pw_hashes.txt"

  if [[ $(wc -l "${TMP_DIR}/pw_hashes.txt" | awk '{print $1}') -gt 0 ]]; then
    print_output "[+] Found the following password hash values:"
    write_csv_log "PW_PATH" "PW_HASH"
    while read -r PW_HASH; do
      PW_PATH=$(echo "${PW_HASH}" | cut -d: -f1)
      mapfile -t PW_HASHES < <(strings "${PW_PATH}" | grep -a -E -f "${PW_HASH_CONFIG}")
      for PW_HASH in "${PW_HASHES[@]}"; do
        print_output "[+] PATH: ${ORANGE}${PW_PATH}${NC}\t-\tHash: ${ORANGE}${PW_HASH}${NC}"
        write_csv_log "NA" "${PW_PATH}" "${PW_HASH}"
        ((PW_COUNTER+=1))
      done
    done < "${TMP_DIR}/pw_hashes.txt"

    print_output "\n[*] Found ${ORANGE}${PW_COUNTER}${NC} password hashes."
  else
    print_output "No password hashes found."
  fi

  log_message "Statistics: ${PW_COUNTER} password hashes found"
  log_message "Deep analysis of files for password hashes completed"
}

# Main execution
mkdir -p "$TMP_DIR"
S107_deep_password_search
