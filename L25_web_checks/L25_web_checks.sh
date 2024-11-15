#!/bin/bash

# EMBA - EMBEDDED LINUX ANALYZER

# Copyright and license information removed for brevity

# Set environment variables
export TMP_DIR="/tmp/emba_tmp"
export LOG_DIR="/var/log/emba"
export EXT_DIR="/opt/emba/external_tools"
export CONFIG_DIR="/etc/emba"

# Function to initialize logging
module_log_init() {
    local module_name="$1"
    echo "Initializing module: $module_name" >> "$LOG_DIR/emba.log"
}

# Function to write output
print_output() {
    local message="$1"
    local log_option="${2:-}"
    echo "$message"
    if [[ "$log_option" != "no_log" ]]; then
        echo "$message" >> "$LOG_DIR/emba.log"
    fi
}

# Main function for web checks
L25_web_checks() {
    export WEB_RESULTS=0
    
    module_log_init "${FUNCNAME[0]}"
    print_output "Web tests of emulated device."
    
    if [[ -v IP_ADDRESS_ ]]; then
        if ! system_online_check "${IP_ADDRESS_}"; then
            print_output "[-] System not responding - Not performing web checks"
            return
        fi
        main_web_check "${IP_ADDRESS_}"
    else
        print_output "[-] No IP address found ... skipping live system tests"
    fi
    
    print_output "[*] Statistics: ${WEB_RESULTS}"
}

main_web_check() {
    local IP_ADDRESS_="$1"
    local WEB_DONE=0
    
    # Assuming NMAP_PORTS_SERVICES_ARR is populated from previous steps
    for PORT_SERVICE in "${NMAP_PORTS_SERVICES_ARR[@]}"; do
        local PORT=$(echo "${PORT_SERVICE}" | cut -d/ -f1 | tr -d "[:blank:]")
        local SERVICE=$(echo "${PORT_SERVICE}" | awk '{print $2}' | tr -d "[:blank:]")
        
        print_output "[*] Analyzing service ${SERVICE} - ${PORT} - ${IP_ADDRESS_}"
        
        if [[ "${SERVICE}" == "unknown" ]] || [[ "${SERVICE}" == "tcpwrapped" ]]; then
            continue
        fi
        
        if [[ "${SERVICE}" == *"ssl|http"* ]] || [[ "${SERVICE}" == *"ssl/http"* ]]; then
            handle_https_service "${IP_ADDRESS_}" "${PORT}"
        elif [[ "${SERVICE}" == *"http"* ]]; then
            handle_http_service "${IP_ADDRESS_}" "${PORT}"
        fi
        
        if [[ "${WEB_DONE}" -eq 0 ]]; then
            perform_nikto_scan "${IP_ADDRESS_}" "${PORT}"
            WEB_DONE=1
        fi
    done
    
    process_nikto_results "${IP_ADDRESS_}"
    
    print_output "[*] Web server checks for emulated system with IP ${IP_ADDRESS_} finished"
}

handle_https_service() {
    local IP_ADDRESS_="$1"
    local PORT="$2"
    
    make_web_screenshot "${IP_ADDRESS_}" "${PORT}"
    testssl_check "${IP_ADDRESS_}" "${PORT}"
    web_access_crawler "${IP_ADDRESS_}" "${PORT}" 1
}

handle_http_service() {
    local IP_ADDRESS_="$1"
    local PORT="$2"
    
    check_for_basic_auth_init "${IP_ADDRESS_}" "${PORT}"
    make_web_screenshot "${IP_ADDRESS_}" "${PORT}"
    web_access_crawler "${IP_ADDRESS_}" "${PORT}" 0
}

perform_nikto_scan() {
    local IP_ADDRESS_="$1"
    local PORT="$2"
    
    print_output "Nikto web server analysis for ${IP_ADDRESS_}:${PORT}"
    timeout --preserve-status --signal SIGINT 600 "${EXT_DIR}/nikto/program/nikto.pl" -timeout 3 -nointeractive -maxtime 8m -port "${PORT}" -host "${IP_ADDRESS_}" > "${LOG_DIR}/nikto-scan-${IP_ADDRESS_}.txt"
    print_output "[*] Finished Nikto web server analysis for ${IP_ADDRESS_}:${PORT}"
}

process_nikto_results() {
    local IP_ADDRESS_="$1"
    local NIKTO_LOG="${LOG_DIR}/nikto-scan-${IP_ADDRESS_}.txt"
    
    if [[ -f "${NIKTO_LOG}" ]]; then
        grep -E "(\+ Server:|Retrieved x-powered-by header)" "${NIKTO_LOG}" | sort -u | while read -r VERSION; do
            # Process version information
            echo "Detected version: ${VERSION}"
        done
        
        if grep -q "+ [1-9] host(s) tested" "${NIKTO_LOG}"; then
            WEB_RESULTS=1
        fi
    fi
}