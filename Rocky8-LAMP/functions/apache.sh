#!/bin/sh

. messages.sh
. is_service_active.sh
. uninstall_service.sh
. number_of_parameters.sh

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

create_apache_domain() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller DOMAINNAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

    if [ "$#" -ne 1 ]; then
        alert "Incorrect number of parameters"
        echo "Provide domain name"
        return 1
    fi

HTTPCONFIG=$(cat <<EOF
<VirtualHost *:80>
    ServerName $1
    DocumentRoot /var/www/$1
    <Directory /var/www/$1}>
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
EOF
)
    rm -fr /var/www/$1
    mkdir /var/www/$1
    echo "$HTTPCONFIG" > /etc/httpd/conf.d/$1.conf
}
