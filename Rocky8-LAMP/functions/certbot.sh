. number_of_parameters.sh
. is_service_installed.sh

is_certbot_renew_scheduled() {
    if ! systemctl list-timers | grep certbot; then
        return 1
    fi
}

install_certbot() {
    local caller="${FUNCNAME[0]}"
    local help_text="Usage: $caller DOMAINNAME"
    if ! number_of_parameters 1 $# "$help_text"; then
        return 1
    fi

    if ! is_service_installed certbot; then
        dnf install -y certbot python3-certbot-apache
    fi

    # certbot --apache -d $1 --agree-tos -m admin@$1 --non-interactive --redirect --dry-run
    
    if ! is_certbot_renew_scheduled; then
        echo "0 2 10 */1 * root certbot renew --quiet" > /etc/cron.d/certbot-renew
    fi
}
