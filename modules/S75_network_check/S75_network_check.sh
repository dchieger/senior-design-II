#!/bin/bash

# EMBA - EMBEDDED LINUX ANALYZER (Modified for DigitalOcean)
#
# Original Copyright 2020-2024 Siemens Energy AG
# Modifications for DigitalOcean environment

# Set up environment variables
export FIRMWARE_PATH="/root/senior-design-II/deep_password_search/firmware"
export CONFIG_DIR="/root/senior-design-II/deep_password_search/config"
export LOG_PATH_MODULE="/root/senior-design-II/deep_password_search/logs"
export TMP_DIR="/root/senior-design-II/deep_password_search/tmp"

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

# Function to indent output
indent() {
    sed 's/^/  /'
}

S75_network_check() {
    echo "Starting network configuration check"
    
    NET_CFG_FOUND=0
    
    check_resolv
    check_iptables
    check_snmp
    check_network_configs
    
    echo "Network check complete. Found ${NET_CFG_FOUND} configurations."
}

check_resolv() {
    echo "Searching for resolv.conf"
    
    local CHECK=0
    local RES_CONF_PATHS=("/etc/resolv.conf" "${FIRMWARE_PATH}/etc/resolv.conf")
    
    for RES_INFO_P in "${RES_CONF_PATHS[@]}"; do
        if [[ -e "${RES_INFO_P}" ]] ; then
            CHECK=1
            print_output "[+] DNS config ${RES_INFO_P}"
            
            DNS_INFO=$(grep "nameserver" "${RES_INFO_P}" 2>/dev/null || true)
            if [[ "${DNS_INFO}" ]] ; then
                print_output "$(indent "${DNS_INFO}")"
                ((NET_CFG_FOUND+=1))
            fi
        fi
    done
    
    [[ ${CHECK} -eq 0 ]] && print_output "[-] No or empty network configuration found"
}

check_iptables() {
    echo "Searching for iptables.conf"
    
    local CHECK=0
    local IPT_CONF_PATHS=("/etc/iptables" "${FIRMWARE_PATH}/etc/iptables")
    
    for IPT_INFO_P in "${IPT_CONF_PATHS[@]}"; do
        if [[ -e "${IPT_INFO_P}" ]] ; then
            CHECK=1
            print_output "[+] iptables config ${IPT_INFO_P}"
            ((NET_CFG_FOUND+=1))
        fi
    done
    
    [[ ${CHECK} -eq 0 ]] && print_output "[-] No iptables configuration found"
}

check_snmp() {
    echo "Checking SNMP configuration"
    
    local CHECK=0
    local SNMP_CONF_PATHS=("/etc/snmp/snmpd.conf" "${FIRMWARE_PATH}/etc/snmp/snmpd.conf")
    
    for SNMP_CONF_P in "${SNMP_CONF_PATHS[@]}"; do
        if [[ -e "${SNMP_CONF_P}" ]] ; then
            CHECK=1
            print_output "[+] SNMP config ${SNMP_CONF_P}"
            mapfile -t FIND < <(awk '/^com2sec/ { print $4 }' "${SNMP_CONF_P}")
            if [[ "${#FIND[@]}" -ne 0 ]] ; then
                print_output "[*] com2sec line/s:"
                for I in "${FIND[@]}"; do
                    print_output "$(indent "${ORANGE}${I}${NC}")"
                    ((NET_CFG_FOUND+=1))
                done
            fi
        fi
    done
    
    [[ ${CHECK} -eq 0 ]] && print_output "[-] No SNMP configuration found"
}

check_network_configs() {
    echo "Checking for other network configurations"
    
    local NETWORK_CONFS=()
    local CONFIG_FILE="${CONFIG_DIR}/network_conf_files.cfg"
    
    if [[ -f "${CONFIG_FILE}" ]]; then
        mapfile -t NETWORK_CONFS < "${CONFIG_FILE}"
        
        if [[ ${#NETWORK_CONFS[@]} -gt 0 ]] ; then
            print_output "[+] Found ${#NETWORK_CONFS[@]} possible network configs:"
            for LINE in "${NETWORK_CONFS[@]}" ; do
                print_output "$(indent "${ORANGE}${LINE}${NC}")"
                ((NET_CFG_FOUND+=1))
            done
        else
            print_output "[-] No network configs found in config file"
        fi
    else
        print_output "[!] Config file not found: ${CONFIG_FILE}"
    fi
}

# Main execution
mkdir -p "${LOG_PATH_MODULE}" "${TMP_DIR}"
S75_network_check > "${LOG_PATH_MODULE}/network_check.log"
echo "Network check complete. Results are in ${LOG_PATH_MODULE}/network_check.log"
