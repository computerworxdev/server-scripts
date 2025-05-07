#!/bin/sh

safe_exec() {
    local cmd="$*"
    while true; do
        eval "$cmd"
	result=$?
        if [[ $result -eq 0 ]]; then
            return 0
        fi

        alert "Command failed: $cmd"
        echo "Options: [r]etry, [c]ontinue anyway, [a]bort"
        read -rp "Choose an option (r/c/a): " choice
        case "$choice" in
            [Rr]) ;;
            [Cc]) return 0 ;;
            [Aa]) echo "Aborted."; return $result ;;
            *) echo "Invalid option. Please enter r, c, or a." ;;
        esac
    done
}

