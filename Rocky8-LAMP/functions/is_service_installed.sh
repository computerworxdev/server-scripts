#!/bin/sh

is_service_installed() {
	dnf list installed $1 &> /dev/null
}


