Version 1 of Simple basic Script
Release Date 05/04/2025
Tested on Rocky Linux 8.10

This is a very simple web server script that will get a website installed and ssl secure it with free lets encrypt certificate for https connections. This is very simple web server script but with few useful services.

Prerequisites:
- Rocky Linux 8.10 clean (Minimal ISO) installed with Firewall (Firewalld).
- root user

Required Modifications to script:
- provide real working domain - ssl certificate will fail if not provided. (Required)
  PRIMARY_DOMAIN="yourdomainname.com"
- Provide your custom username for FTP and Web login. WEB_USER="webadmin" (Default = webadmin) - Optional
- password will be random and provided at the end of the script execution.

This script will execute following tasks:
- install EPEL repository
- update your linux system
-  install wget
-  install apache 2.4 and enable at boot
-  configure firewalld for http,https,ftp,ssh ports
-  create web user account and configure apache server
-  install php 8.2 and needed modules
-  install vsftpd and configure it
-  create LetsEncrypt SSl Certificate for your domain
-  add SSL renewal to cronjob for automatic renewals
-  provide all credentials (ftp access)


Script is free to use for anybody in commercial and personal enviorment.

Enjoy the script
(this is basic very light webserver configuration).
