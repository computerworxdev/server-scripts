#!/bin/sh

. set_colors.sh

# Message Functions

alert() {
	echo -e "${COLOR_RED}$1${COLOR_NAN}"
}

success() {
	echo -e "${COLOR_GREEN}$1${COLOR_NAN}"
}

bold() {
	echo -e "${COLOR_YELLOW}$1${COLOR_NAN}"
}
