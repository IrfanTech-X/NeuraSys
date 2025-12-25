heal_disk() {
    rm -rf /tmp/*
    journalctl --vacuum-time=3d
    log_action "Disk cleanup completed"
}

