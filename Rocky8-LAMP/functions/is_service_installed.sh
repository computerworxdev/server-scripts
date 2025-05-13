#!/bin/sh

# Checks if service is installed
is_service_installed() {
	dnf list installed $1 &> /dev/null
}


