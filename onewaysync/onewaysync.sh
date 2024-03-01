#!/bin/sh

# REQUIREMENTS
# - rsync installed in source and destination
# - sshpass installed in source

# GENERAL SETTINGS
username="USERNAME"
password="PASSWORD"
server="SERVERNAME_OR_ADDRESS"
log_file="/opt/backup/log.txt"

# ADD PATHS OF THE FOLDERS TO BACKUP
source_dir_1="/home/adminet20/public_html/member-only/images/cover images"
source_dir_2="/home/adminet20/public_html/member-only/media/playlists"
target_dir_1="/var/www/vhosts/tvpolnet.info/httpdocs/member-only/images/cover images"
target_dir_2="/var/www/vhosts/tvpolnet.info/httpdocs/member-only/media/playlists"

echo date >> $log_file
rsync_command="sshpass -p $password \
    rsync -avz \
        --delete \
        $source_dir_1 \
        $username@$server:$target_dir_1"
eval $rsync_command >> $log_file
echo -en "\n" >> $log_file

rsync_command="sshpass -p $password \
    rsync -avz \
        --delete \
        $source_dir_2 \
        $username@$server:$target_dir_2"
eval $rsync_command >> $log_file
echo -en "\n" >> $log_file
