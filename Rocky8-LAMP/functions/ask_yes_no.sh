#!/bin/sh

ask_yes_no() {
    local prompt="${1:-Are you sure?}"
    [[ "$2" == "-y" || "$2" == "--yes" ]] && return 0

    while true; do
        read -p "$prompt [y/n]: " answer
        case "$answer" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            *) echo "Please answer y or n." ;;
        esac
    done
}
