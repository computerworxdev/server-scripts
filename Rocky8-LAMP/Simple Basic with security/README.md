Provided script is an enhanced version of the basic scrip but with included additional layer of security.

Perquisites:
- Rocky Linux 8.10 installed 
- Firewalld service installed and running (Firewal)
- Selinux enabled and running.


To run and execute copy the script content or download it to your server then :
- chmod +x scriptname.sh (assign executable permission to the script)
- ./scriptsname.sh (to execute the script)

You will be prompt in 2 areas to :
- enter full domain name for website ssl security (letsencrypt ssl example mydomain.com)
- half way you will be asked question to be used in SelfCertificate to secure your ftp server and its connection. ( by default it set to be valid for 365 days). See notes for more info.

What does the script do? :
- collects domain name information
- sets up ftp/web user account (webadmin)
- installs EPEL Respository (for additional software installation)
- installs and configures Fail2Ban service (server additional layer of protection)
- installs latest updates to your linux distribution
- configures firewall rules
- installs apache service and cnfigures it for a website
- installs php 8.2
- installes and configures vsftp with TLS 1.2 security (ftp server)
- installs and configures certbot for your website (SSL secured connection to your website)
- Displays all created credentials for you to save and use on this setup.

Notes:
- when ftp ssl expires and you need to renew for another 1 year 365 days please issue this command in terminal on server.
# openssl req -x509 -nodes -keyout /etc/ssl/vsftpd/vsftpd-selfsigned.pem -out /etc/ssl/vsftpd/vsftpd-selfsigned.pem -days 365 -newkey rsa:2048

then restart ftp service or reboot the server.
# sudo systemctl restart vsftpd


- Web cerificate will auto renew every 90 days for your website and cron will take care of it.
In case of issues please check Certbot log for errors.

- ftp requires port 990 , 40000-400001 Passive - to work correctly in case of issues please make sure they are open in the firewall.

