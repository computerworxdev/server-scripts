#!/bin/sh

. messages.sh
. is_service_active.sh
. is_service_installed.sh
. ask_yes_no.sh


install_mariadb() {
SERVICE=mariadb
    if is_service_installed  $SERVICE-server; then
        alert "$SERVICE is already installed"
        return 1
    fi

    dnf -y install $SERVICE-server $SERVICE-server-utils expect

    systemctl enable $SERVICE
    systemctl start $SERVICE

	if ! is_service_active $SERVICE; then
		alert "Failed to activate $SERVICE service"
		return 1
	fi

    success "$SERVICE is installed and running"
    alert "You should run manually mysql_secure_installation to secure the setup"
    if ask_yes_no "Do you to run mysql_secure_installation now"; then
        mysql_secure_installation
    fi 
}
