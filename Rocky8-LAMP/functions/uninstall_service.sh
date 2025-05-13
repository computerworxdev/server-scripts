#!/bin/sh

. is_service_installed.sh

uninstall_service() {
	if ! is_service_installed "$1"; then
		alert "Service $1 is not installed"
		return 1
	fi

	dnf -y remove "$1"
}
