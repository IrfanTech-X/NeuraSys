check_disk() {
    df / | awk 'NR==2 {print $5}' | sed 's/%//'
}

