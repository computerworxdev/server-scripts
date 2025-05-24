#!/bin/sh

. messages.sh
. is_service_active.sh
. is_service_installed.sh
. number_of_parameters.sh

add_firewall_service() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller SERVICE_NAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

	local service=$1
	if firewall-cmd --permanent --add-service="$service"; then
        firewall-cmd --reload
		success "firewalld successfully added $service"
	else
		alert "firewalld failed to add $service"
		return 1
	fi
}

add_firewall_port() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller PORT_NUMBER/PROTOCOL"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

    local port=$1
    if firewall-cmd --permanent --add-port="$port"; then
        firewall-cmd --reload
        success "firewalld successfully added port $port"
    else
        alert "firewalld failed to add port $port"
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
