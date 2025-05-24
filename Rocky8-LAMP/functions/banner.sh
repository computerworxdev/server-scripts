banner() {
    local message="$1"
    local border_char="${2:-=}"
    local padding=4
    local border_length=$(( ${#message} + padding ))

    printf "\n"
    printf "%${border_length}s\n" | tr ' ' "$border_char"
    printf "%s%s%s\n" "$border_char" " $message " "$border_char"
    printf "%${border_length}s\n" | tr ' ' "$border_char"
    printf "\n"
}
