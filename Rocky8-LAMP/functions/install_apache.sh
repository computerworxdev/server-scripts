#!/bin/sh

. messages.sh
. is_service_active.sh

is_apache_responding() {
	curl -s --head "http://localhost/" | grep "HTTP" > /dev/null
}


install_mod_ssl() {
# Install mod_ssl and enable mod_rewrite
	dnf install -y mod_ssl

	# Create a backup of the httpd configuration file
	cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.bak

	# If a line to load the rewrite module doesn't exist, append it
	grep -q 'LoadModule rewrite_module' /etc/httpd/conf/httpd.conf \
	  || echo 'LoadModule rewrite_module modules/mod_rewrite.so' >> /etc/httpd/conf/httpd.conf

	# If a line to load the rewrite module exists but is commented, uncomment it
	sed -i '/LoadModule rewrite_module/s/^#//g' /etc/httpd/conf/httpd.conf
}

install_apache() {
	if is_service_installed httpd ; then
		success "Apache is already installed"
	else
		dnf -y install httpd
		install_mod_ssl
	fi

	systemctl enable httpd
	systemctl start httpd

	if ! is_service_active httpd; then
		alert "Failed to activate httpd service"
		return 1
	fi

	if ! is_apache_responding ; then
		alert "Apache is not responding to http requests"
		return 1
	fi
}
