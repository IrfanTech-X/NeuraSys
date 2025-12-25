scan_startup_executables() {

    echo "🔍 Scanning startup executable files..."
    log_action "Startup executable scan started"

    locations=(
        "$HOME/.bashrc"
        "$HOME/.profile"
        "$HOME/.bash_profile"
        "/etc/init.d"
        "/etc/systemd/system"
        "/usr/local/bin"
    )

    patterns=(
        "while true"
        "shutdown"
        "reboot"
        ":(){"
        "rm -rf /"
        "kill -9 1"
    )

    for loc in "${locations[@]}"; do
        if [[ -e "$loc" ]]; then
            find "$loc" -type f -executable 2>/dev/null | while read file; do
                echo "✔ Executable found: $file"
                for p in "${patterns[@]}"; do
                    if grep -q "$p" "$file"; then
                        echo "⚠ Suspicious pattern '$p' detected in $file"
                        log_action "Threat detected in $file | Pattern: $p"
                    fi
                done
            done
        fi
    done

    log_action "Startup executable scan completed"
}

