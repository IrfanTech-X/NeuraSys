heal_zombies() {
    for pid in $(check_zombies); do
        ppid=$(ps -o ppid= -p "$pid")
        kill -9 "$ppid"
        log_action "Zombie resolved by killing parent PID $ppid"
    done
}

