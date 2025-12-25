check_zombies() {
    ps aux | awk '$8=="Z" {print $2}'
}

