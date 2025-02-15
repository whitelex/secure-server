# Secure Server Script

This repository contains scripts to automate the hardening of Ubuntu and CentOS servers.

## Scripts

*   **Ubuntu:** `ubuntu-secure-server.sh` - A Bash script designed to secure Ubuntu servers.
*   **CentOS:** `centos-secure-server.sh` - A Bash script designed to secure CentOS servers.

## Description

These scripts perform a series of security-related tasks, including:

*   Updating the system
*   Installing and configuring SSH
*   Setting the timezone
*   Installing and configuring Fail2ban
*   Configuring rsyslog for Graylog integration
*   Configuring journald for local time

The scripts are designed to be interactive, prompting the user for confirmation before each major step. The Graylog server IP and port must be provided by the user.  The script also checks if essential packages/services are already installed before attempting installation.

## Usage

### Prerequisites

*   Root privileges are required to run the scripts.
*   Internet access is required to download packages.

### Downloading the Scripts

You can download the scripts using `wget`:

**Ubuntu:**

```bash
wget https://raw.githubusercontent.com/whitelex/secure-server/refs/heads/main/ubuntu-secure-server.sh
```

**Ubuntu:**

```bash
wget https://raw.githubusercontent.com/whitelex/secure-server/refs/heads/main/centos-secure-server.sh
```

### Make the script executable:

```bash
chmod +x ubuntu-secure-server.sh  # For Ubuntu
chmod +x centos-secure-server.sh  # For CentOS
```

### Run the script as root

```bash
sudo ./ubuntu-secure-server.sh   # For Ubuntu
sudo ./centos-secure-server.sh   # For CentOS
```

