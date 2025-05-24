#!/bin/sh

# pre-conditions
. messages.sh

get_input() {
  local prompt=" "
  local skip_confirm=false

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -y|--yes)
        skip_confirm=true
        shift
        ;;
      *)
        prompt="$1"
        shift
        ;;
    esac
  done

  local input=""
  while [[ -z "$input" ]]; do
    read -p "$prompt " input
    if [[ -z "$input" ]]; then
      alert "Input cannot be empty. Try again."
    fi
  done

  # Confirm if not skipping confirmation
  if ! $skip_confirm; then
    while true; do
	    read -p "you entered: '$input'. Confirm? (y/n): " confirm
      case "$confirm" in
        [Yy]*) break ;;
        [Nn]*) 
          input=""
          while [[ -z "$input" ]]; do
            read -p "$prompt " input
            if [[ -z "$input" ]]; then
              alert "Input cannot be empty. Try again."
            fi
          done
          ;;
        *) "Please answer y or n." ;;
      esac
    done
  fi
  echo "$input"
}


