#!/bin/sh

. messages.sh
. is_service_installed.sh
. is_service_active.sh

FAIL2BAN_SSH=$(cat <<EOF
[sshd]
enabled  = true
port     = 22
filter   = sshd
logpath  = /var/log/secure
maxretry = 2
bantime  = 5m
EOF
)

FAIL2BAN_VSFTPD=$(cat <<EOF
[vsftpd]
enabled  = true
port     = ftp
filter   = vsftpd
logpath  = /var/log/vsftpd.log
maxretry = 2
bantime  = 21600
EOF
)

install_fail2ban() {
    if is_service_installed fail2ban; then
        echo "Fail2ban is already installed."
        return 1
    fi

    dnf install -y fail2ban fail2ban-firewalld
    cp -f /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    [ -f /etc/fail2ban/jail.d/00-firewalld.conf ] && mv -f /etc/fail2ban/jail.d/00-firewalld.conf /etc/fail2ban/jail.d/00-firewalld.local
    echo "$FAIL2BAN_SSH" > /etc/fail2ban/jail.d/10-sshd.conf
    echo "$FAIL2BAN_VSFTPD" > /etc/fail2ban/jail.d/20-vsftpd.conf

    if [ ! -f /var/log/vsftpd.log ]; then
        touch /var/log/vsftpd.log
        chown root:root /var/log/vsftpd.log
        chmod 644 /var/log/vsftpd.log
    fi

    sed -i '/^[[:space:]]*banaction[[:space:]]*=[[:space:]]*iptables-multiport[[:space:]]*$/s/^/#/' /etc/fail2ban/jail.local
    sed -i '/^[[:space:]]*banaction_allports[[:space:]]*=[[:space:]]*iptables-allports[[:space:]]*$/s/^/#/' /etc/fail2ban/jail.local

    if ! grep -q '^banaction[[:space:]]*=' /etc/fail2ban/jail.local; then
        sed -i '/^\[DEFAULT\]/a banaction = firewallcmd-rich-rules\nbanaction_allports = firewallcmd-rich-rules' /etc/fail2ban/jail.local
    fi

    systemctl enable fail2ban
    systemctl restart fail2ban

    if ! is_service_active fail2ban; then
        alert "Fail2ban is not working properly"
        return 1
    fi
}
