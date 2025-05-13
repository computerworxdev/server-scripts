#!/bin/sh

. messages.sh
. is_service_installed.sh
. is_service_active.sh

FTPCONFIG=$(cat <<EOF
anonymous_enable=NO
local_enable=YES
local_root=/var/www
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES
hide_ids=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
listen=NO
listen_ipv6=YES
pam_service_name=vsftpd
userlist_enable=YES
userlist_deny=NO
EOF
)

SERVICE=vsftpd

install_vsftpd() {

    if is_service_installed $SERVICE; then
        alert "$SERVICE is already installed"
        return 1
    fi
    
    dnf install -y vsftpd
    cp /etc/vsftpd/vsftpd.conf /etc/vsftpd/vsftpd.conf.bak
    echo "$FTPCONFIG" > /etc/vsftpd/vsftpd.conf
    setsebool -P ftpd_full_access 1
    systemctl enable vsftpd
    systemctl start vsftpd

    if ! is_service_active $SERVICE; then
        alert "$SERVICE is not working properly"
        return 1
    fi
}

add_vsftpd_user() {
    echo "$1" | tee -a /etc/vsftpd/user_list >/dev/null
}

is_vsftpd_active() {
    if [ "$#" -ne 3 ]; then
        alert "Incorrect number of parameters"
        echo "Provide: username password and host"
        return 1
    fi

    if ! is_service_installed lftp; then
        dnf -y install lftp
    fi

    if lftp -u "$1","$2" "$3" -e "ls; bye" >/dev/null 2>&1; then
        success "FTP server is responding"
    else
        alert "FTP server is not responding"
    fi
}
