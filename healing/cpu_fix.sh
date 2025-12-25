heal_cpu() {
    ps -eo pid,comm,%cpu --sort=-%cpu | awk '$3>80 {print $1,$2}' |
    while read pid name; do
        if [[ ! $name =~ $SAFE_PROCESSES ]]; then
            kill -9 "$pid"
            log_action "High CPU process killed: $name (PID $pid)"
        fi
    done
}

