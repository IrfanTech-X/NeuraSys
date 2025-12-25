#!/bin/bash

# ==============================
# NeuraSys Main Controller
# ==============================

# Load configuration
source config/config.conf

# ==============================
# Logger
# ==============================
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOG_FILE"
}

# ==============================
# Load Modules
# ==============================
source monitor/cpu.sh
source monitor/memory.sh
source monitor/disk.sh
source monitor/process.sh

source healing/cpu_fix.sh
source healing/memory_fix.sh
source healing/disk_fix.sh
source healing/zombie_fix.sh

source security/startup_scan.sh

# ==============================
# RISK ANALYSIS (SOC LOGIC)
# ==============================
analyze_risk() {
    file="$1"
    score=0

    grep -q "while true" "$file" 2>/dev/null && ((score+=3))
    grep -Eq "shutdown|reboot" "$file" 2>/dev/null && ((score+=4))
    grep -q ":(){" "$file" 2>/dev/null && ((score+=5))

    perms=$(stat -c "%a" "$file" 2>/dev/null)
    [[ "$perms" == "777" ]] && ((score+=2))

    owner=$(stat -c "%U" "$file" 2>/dev/null)
    [[ "$owner" == "root" ]] && ((score+=2))

    echo "$score"
}

# ==============================
# SCAN & CLASSIFY EXECUTABLES
# ==============================
declare -A RISKY_FILES

scan_and_classify() {
    RISKY_FILES=()

    locations=(
        "$HOME/.bashrc"
        "/etc/init.d"
        "/etc/systemd/system"
        "/usr/local/bin"
    )

    for loc in "${locations[@]}"; do
        [[ -e "$loc" ]] && find "$loc" -type f -executable 2>/dev/null |
        while read file; do
            score=$(analyze_risk "$file")
            if [[ "$score" -ge 3 ]]; then
                RISKY_FILES["$file"]=$score
            fi
        done
    done
}

# ==============================
# VIEW RISKY FILES
# ==============================
view_risky_files() {
    scan_and_classify
    echo
    echo "⚠ Risky Executable Files:"
    echo "--------------------------"

    for file in "${!RISKY_FILES[@]}"; do
        score=${RISKY_FILES[$file]}
        [[ "$score" -ge 6 ]] && level="HIGH" || level="MEDIUM"
        echo "[$level] $file (Risk Score: $score)"
    done
}

# ==============================
# FIX / DISABLE FILE
# ==============================
fix_risky_files() {
    view_risky_files
    echo
    read -p "Enter FULL PATH of file to disable (or press Enter to cancel): " target

    if [[ -n "$target" && -f "$target" ]]; then
        chmod -x "$target"
        log_action "Disabled risky executable: $target"
        echo "✔ Execution permission removed."
    else
        echo "No action taken."
    fi
}

# ==============================
# VIEW SYSTEM STATUS
# ==============================
view_status() {
    echo
    echo "System Status:"
    echo "--------------"
    echo "CPU Usage   : $(check_cpu | cut -d. -f1)%"
    echo "Memory Usage: $(check_memory)%"
    echo "Disk Usage  : $(check_disk)%"
}

# ==============================
# MENU SYSTEM (MAIN UI)
# ==============================
menu() {
    while true; do
        echo
        echo "=============================="
        echo "        NeuraSys Menu"
        echo "=============================="
        echo "1. View System Status"
        echo "2. Scan Startup Executables"
        echo "3. View Risky Executables"
        echo "4. Fix / Disable Risky Executables"
        echo "5. View Logs"
        echo "6. Exit"
        echo "=============================="
        read -p "Choose an option: " choice

        case $choice in
            1) view_status ;;
            2) scan_startup_executables ;;
            3) view_risky_files ;;
            4) fix_risky_files ;;
            5) tail -n 20 logs/neuraysys.log ;;
            6) echo "Exiting NeuraSys..."; exit ;;
            *) echo "Invalid option!" ;;
        esac
    done
}

# ==============================
# STARTUP PROMPT
# ==============================
echo "NeuraSys detected system startup."
read -p "Run startup executable security scan now? (yes/no): " choice

[[ "$choice" == "yes" ]] && scan_startup_executables

log_action "NeuraSys started"

# ==============================
# START MENU
# ==============================
menu

