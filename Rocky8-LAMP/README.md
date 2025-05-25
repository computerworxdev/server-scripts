# Rocky 8 LAMP Automated Installer

## Overview

This project provides an automated script to install and configure a full LAMP stack (Linux, Apache, MariaDB, PHP) and additional services on **Rocky Linux 8.10**. The script is designed for use on a clean installation of the minimal ISO distribution.

## What Does This Script Do?

- Installs and configures:
  - Apache (with mod_ssl and mod_rewrite)
  - PHP (Remi 8.2)
  - MariaDB (with optional secure installation)
  - phpMyAdmin
  - firewalld (with HTTP, HTTPS, FTP, SSH rules)
  - vsftpd (with SSL support)
  - fail2ban (with SSH and FTP protection)
  - MongoDB (with root user creation)
  - Certbot (optional, commented out by default)
- Creates a dedicated user and group for web administration.
- Sets up virtual hosts and permissions.
- At the end of the installation, a summary check is performed to ensure all
  services are running correctly.
- All output is displayed in the terminal and also saved to `output.log`.

## Key Features

- **Interactive or Default Setup:** Choose to use default variables or provide your own for domain, user, password, and group.
- **Idempotent Functions:** Checks for existing installations and configurations before making changes.
- **Error Handling:** Uses safe execution and prompts for retry/continue/abort on failures.
- **Modular Design:** Core logic is organized into reusable functions.

## Configuration Variables

You can define the following variables at the start of the script or interactively:

- `WEBDOMAIN`: The domain name for your website (default: `example.com`)
- `USER`: The username for the web administrator (default: `webadmin`)
- `PASSWORD`: The password for the web administrator (default: `webadmin`)
- `GROUP`: The group for the web administrator (default: `webadmin`)

## How to Use

1. **Prepare a Clean Rocky Linux 8.10 Minimal Installation.**
2. **Download or Clone this Repository.**
3. **Run the Installer Script:**
   ```sh
   chmod +x lamp-install.sh
   sudo ./lamp-install.sh
   ```
4. **Follow the Prompts:**  
   You can accept the default variables or enter your own.
5. **Check the Output:**  
   All actions and results are shown in the terminal and saved to `output.log` for later review.

## How the Script is Built

- The main install script (`lamp-install.sh`) is constructed using a set of modular functions.
- These functions are defined in the `functions` folder. You can copy and paste them into your own scripts as needed.
- The script uses these functions to perform installation, configuration, and validation steps in a logical order.
- Output is piped to both the terminal and `output.log` for transparency and troubleshooting.

## Requirements & Compatibility

- **OS:** Rocky Linux 8.10 (minimal ISO, clean install)
- **Privileges:** Must be run as root or with `sudo`
- **Tested:** Only on Rocky Linux 8.10 minimal ISO

## Troubleshooting & Notes

- The script is intended for fresh installations. Running on a system with
  existing configurations may lead to unexpected results.
