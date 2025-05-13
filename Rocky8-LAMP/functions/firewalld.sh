#!/bin/sh

. messages.sh
. is_service_active.sh
. is_service_installed.sh

add_firewall_service() {
	local service=$1
	if firewall-cmd --permanent --add-service="$service"; then
		success "firewalld successfully added $service"
	else
		alert "firewalld failed to add $service"
		return 1
	fi
}

install_firewalld() {
	if is_service_installed firewalld ; then
		success "firewalld is already installed"
	else
		dnf -y install firewalld
	fi

	systemctl enable firewalld
	systemctl start firewalld

	if ! is_service_active firewalld; then
		alert "Failed to activate firewalld service"
		return 1
	fi

	add_firewall_service http
	add_firewall_service https
	add_firewall_service ftp
	add_firewall_service ssh

	if ! firewall-cmd --reload; then
		alert "Failed realoding firewalld"
		return 1
	fi
}
