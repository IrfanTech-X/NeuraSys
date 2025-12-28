#!/bin/bash

# ==============================
# NeuraSys v2.0 - Automated Linux Performance & Risk Scanner
# ==============================

# LOG FILE
LOG_FILE="$HOME/NeuraSys/logs/neuraysys.log"
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') : $1" >> "$LOG_FILE"
}

# ==============================
# CHECK SYSTEM RESOURCES
# ==============================
check_cpu() {
    # CPU usage percentage
    echo $(top -bn1 | grep "Cpu(s)" | awk '{print $2 + $4}')
}

check_memory() {
    # Memory usage percentage
    free | awk '/Mem/{printf "%.0f", $3/$2 * 100}'
}

check_disk() {
    # Disk usage of root
    df / | awk 'NR==2 {print $5}' | sed 's/%//'
}

# ==============================
# SELF-HEALING FUNCTIONS
# ==============================
free_memory() {
    sudo sync; sudo echo 3 > /proc/sys/vm/drop_caches
    log_action "Memory cache cleared automatically"
    echo "✔ Memory cache cleared"
}

clean_disk() {
    # Remove temp files safely
    sudo rm -rf /tmp/* 2>/dev/null
    log_action "Temporary files deleted from /tmp"
    echo "✔ Disk cleaned"
}

kill_zombie() {
    zombies=$(ps aux | awk '{if ($8=="Z") print $2}')
    if [[ ! -z "$zombies" ]]; then
        for pid in $zombies; do
            sudo kill -9 "$pid" 2>/dev/null
            log_action "Killed zombie process PID: $pid"
        done
        echo "✔ Zombie processes cleared"
    fi
}

# ==============================
# EXECUTABLE SCAN & RISK ANALYSIS
# ==============================
declare -A RISKY_FILES

analyze_risk() {
    file="$1"
    score=0

    # Suspicious patterns
    grep -q "while true" "$file" 2>/dev/null && ((score+=4))
    grep -Eq "shutdown|reboot" "$file" 2>/dev/null && ((score+=3))
    grep -q ":(){" "$file" 2>/dev/null && ((score+=5))

    # File permissions & owner
    perms=$(stat -c "%a" "$file" 2>/dev/null)
    [[ "$perms" == "777" ]] && ((score+=2))
    owner=$(stat -c "%U" "$file" 2>/dev/null)
    [[ "$owner" == "root" ]] && ((score+=2))

    echo "$score"
}

scan_and_classify() {
    RISKY_FILES=()
    locations=("$HOME/.bashrc" "/etc/init.d" "/etc/systemd/system" "/usr/local/bin")

    for loc in "${locations[@]}"; do
        [[ -e "$loc" ]] && sudo find "$loc" -type f -executable 2>/dev/null | while read file; do
            score=$(analyze_risk "$file")
            if [[ "$score" -ge 3 ]]; then
                RISKY_FILES["$file"]=$score
            fi
        done
    done
}

view_risky_files() {
    scan_and_classify
    echo
    echo "⚠ Risky Executable Files:"
    for file in "${!RISKY_FILES[@]}"; do
        score=${RISKY_FILES[$file]}
        [[ "$score" -ge 6 ]] && level="HIGH" || level="MEDIUM"
        echo "[$level] $file (Risk Score: $score)"
    done
}

fix_risky_files() {
    view_risky_files
    echo
    read -p "Enter FULL PATH of file to disable (or press Enter to cancel): " target
    if [[ -n "$target" && -f "$target" ]]; then
        chmod -x "$target"
        log_action "Disabled risky executable: $target"
        echo "✔ Execution permission removed"
    else
        echo "No action taken"
    fi
}

# ==============================
# REAL-TIME MONITORING
# ==============================
monitor_resources() {
    echo "Starting real-time monitoring (Press Ctrl+C to stop)"
    while true; do
        cpu=$(check_cpu)
        mem=$(check_memory)
        disk=$(check_disk)

        echo "CPU: $cpu% | Memory: $mem% | Disk: $disk%"
        log_action "CPU:$cpu% Memory:$mem% Disk:$disk%"

        # Self-healing
        [[ $cpu -ge 85 ]] && echo "⚠ High CPU" | tee -a "$LOG_FILE"
        [[ $mem -ge 80 ]] && free_memory
        [[ $disk -ge 90 ]] && clean_disk
        kill_zombie

        sleep 60
    done
}

# ==============================
# MENU SYSTEM
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
        echo "5. Real-Time Resource Monitoring"
        echo "6. View Logs"
        echo "7. Exit"
        read -p "Choose an option: " choice

        case $choice in
            1)
                echo "CPU: $(check_cpu)%"
                echo "Memory: $(check_memory)%"
                echo "Disk: $(check_disk)%"
                ;;
            2)
                scan_and_classify
                echo "Startup executables scanned"
                ;;
            3)
                view_risky_files
                ;;
            4)
                fix_risky_files
                ;;
            5)
                monitor_resources
                ;;
            6)
                tail -n 20 "$LOG_FILE"
                ;;
            7)
                echo "Exiting NeuraSys..."
                exit 0
                ;;
            *)
                echo "Invalid option"
                ;;
        esac
    done
}

# ==============================
# STARTUP PROMPT
# ==============================
echo "NeuraSys detected system startup."
read -p "Run startup executable security scan now? (yes/no): " choice
[[ "$choice" == "yes" ]] && scan_and_classify

log_action "NeuraSys started"
menu
