#!/bin/bash
#
# Script to Secure an Ubuntu Server
# Author: [Your Name/Organization]
# Date: [Current Date]
# Description:  This script automates common server hardening tasks on Ubuntu,
#               including updates, SSH configuration, timezone setup,
#               fail2ban installation, and rsyslog configuration for Graylog.
#               The script will prompt for confirmation before each major step.
#               It also requires the user to specify the Graylog server IP and port.
#               It checks if the required services/packages are already installed before proceeding.
#
# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Function to display messages with color
msg() {
  echo -e "$1"
}

# Check if the script is run as root
if [[ $EUID -ne 0 ]]; then
  msg "${RED}Error: This script must be run as root.${NC}"
  exit 1
fi

# Function to prompt user and get confirmation
confirm() {
  read -r -p "$1 [y/N]: " response
  case "$response" in
    [yY][eE][sS]|[yY])
      true
      ;;
    *)
      false
      ;;
  esac
}

# Function to get user input
get_input() {
  read -r -p "$1: " input
  echo "$input"
}

# Function to check if a package is installed
is_package_installed() {
  dpkg -s "$1" > /dev/null 2>&1
}

# --- STEP 0: Get Graylog Server IP and Port ---
msg "${BLUE}--- STEP 0: Specify Graylog Server IP and Port ---${NC}"

while true; do
  GRAYLOG_SERVER_IP=$(get_input "Enter the Graylog server IP address")
  if [[ -n "$GRAYLOG_SERVER_IP" ]]; then
    break
  else
    msg "${RED}Error: Graylog server IP address cannot be empty. Please enter a valid IP address.${NC}"
  fi
done

while true; do
  GRAYLOG_PORT=$(get_input "Enter the Graylog server port")
  if [[ -n "$GRAYLOG_PORT" && "$GRAYLOG_PORT" =~ ^[0-9]+$ ]]; then
    break
  else
    msg "${RED}Error: Graylog server port cannot be empty and must be a number. Please enter a valid port number.${NC}"
  fi
done

msg "${GREEN}Graylog server IP: ${GRAYLOG_SERVER_IP}${NC}"
msg "${GREEN}Graylog server port: ${GRAYLOG_PORT}${NC}"

# --- STEP 1: System Update ---
msg "${BLUE}--- STEP 1: Updating System ---${NC}"

if confirm "Do you want to proceed with updating the system?"; then
  msg "Performing system update..."
  sudo apt update -y && sudo apt upgrade -y

  if [ $? -eq 0 ]; then
    msg "${GREEN}System update completed successfully.${NC}"
  else
    msg "${RED}Error: System update failed.  Check for network connectivity or package manager issues.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping system update.${NC}"
  # Removed exit 0 here
fi

# --- STEP 2: Install and Configure SSH ---
msg "${BLUE}--- STEP 2: Install and Configure SSH ---${NC}"

if is_package_installed openssh-server; then
  msg "${YELLOW}SSH is already installed. Skipping installation and service management.${NC}"
else
  if confirm "Do you want to proceed with installing and configuring SSH?"; then
    msg "Installing openssh-server..."
    sudo apt install openssh-server -y

    if [ $? -eq 0 ]; then
      msg "${GREEN}openssh-server installed successfully.${NC}"
    else
      msg "${RED}Error: openssh-server installation failed.${NC}"
      exit 1
    fi

    msg "Starting and enabling sshd service..."
    sudo systemctl start sshd
    sudo systemctl enable sshd

    if [ $? -eq 0 ]; then
      msg "${GREEN}sshd service started and enabled successfully.${NC}"
    else
      msg "${RED}Error: Failed to start or enable sshd service.${NC}"
      exit 1
    fi
  else
    msg "${YELLOW}Skipping SSH installation.${NC}"
    # Removed exit 0 here
  fi
fi

# Consider disabling password authentication and enabling key-based authentication here
# This significantly improves security, but it requires setting up SSH keys first.
# Example (Requires prior key setup):
#  sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
#  sudo sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config #Recommended to disable root login via SSH
#  sudo systemctl restart sshd

# --- STEP 3: Set Timezone ---
msg "${BLUE}--- STEP 3: Setting Timezone ---${NC}"

if confirm "Do you want to proceed with setting the timezone to America/Toronto?"; then
  msg "Setting timezone to America/Toronto..."
  sudo timedatectl set-timezone 'America/Toronto'

  if [ $? -eq 0 ]; then
    msg "${GREEN}Timezone set to America/Toronto successfully.${NC}"
  else
    msg "${RED}Error: Failed to set timezone.  Verify the timezone name is correct.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping timezone configuration.${NC}"
  # Removed exit 0 here
fi

# --- STEP 4: Install and Configure Fail2ban ---
msg "${BLUE}--- STEP 4: Install and Configure Fail2ban ---${NC}"

if is_package_installed fail2ban; then
  msg "${YELLOW}Fail2ban is already installed. Skipping installation.${NC}"
else
  if confirm "Do you want to proceed with installing and configuring Fail2ban?"; then
    msg "Installing fail2ban..."
    sudo apt install fail2ban -y

    if [ $? -eq 0 ]; then
      msg "${GREEN}fail2ban installed successfully.${NC}"
    else
      msg "${RED}Error: Failed to install fail2ban.${NC}"
      exit 1
    fi

    msg "Creating /etc/fail2ban/jail.d/sshd.local..."
    cat <<EOF | sudo tee /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
EOF

    if [ $? -eq 0 ]; then
      msg "${GREEN}/etc/fail2ban/jail.d/sshd.local created successfully.${NC}"
    else
      msg "${RED}Error: Failed to create /etc/fail2ban/jail.d/sshd.local.${NC}"
      exit 1
    fi
  else
      msg "${YELLOW}Skipping Fail2ban installation.${NC}"
      # Removed exit 0 here
  fi
fi

msg "Starting and enabling fail2ban service..."
sudo systemctl start fail2ban
sudo systemctl enable fail2ban

if [ $? -eq 0 ]; then
  msg "${GREEN}fail2ban service started and enabled successfully.${NC}"
else
  msg "${RED}Error: Failed to start or enable fail2ban service.${NC}"
  exit 1
fi

msg "Checking fail2ban sshd status..."
sudo fail2ban-client status sshd

# --- STEP 5: Configure Rsyslog for Graylog ---
msg "${BLUE}--- STEP 5: Configuring Rsyslog for Graylog ---${NC}"

if confirm "Do you want to proceed with configuring Rsyslog for Graylog?"; then
  msg "Configuring rsyslog for Graylog logging..."
  sudo sed -i "/# TCP (reliable)/a auth,authpriv.*  @@${GRAYLOG_SERVER_IP}:${GRAYLOG_PORT}" /etc/rsyslog.d/20-graylog.conf

  if [ $? -eq 0 ]; then
    msg "${GREEN}rsyslog configuration updated for Graylog successfully.${NC}"
  else
    msg "${RED}Error: Failed to update rsyslog configuration for Graylog.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping Rsyslog configuration for Graylog.${NC}"
  # Removed exit 0 here
fi

# --- STEP 6: Configure Journald for Local Time ---
msg "${BLUE}--- STEP 6: Configuring Journald for Local Time ---${NC}"

if confirm "Do you want to proceed with configuring Journald for local time?"; then
  msg "Configuring journald to use local time..."
  sudo sed -i 's/^#UTC=yes/UTC=no/' /etc/systemd/journald.conf

  if [ $? -eq 0 ]; then
    msg "${GREEN}Journald configuration updated for local time successfully.${NC}"
  else
    msg "${RED}Error: Failed to update journald configuration for local time.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping Journald configuration for local time.${NC}"
  # Removed exit 0 here
fi

# Restart rsyslog after changes
msg "Restarting rsyslog service..."
sudo systemctl restart rsyslog

if [ $? -eq 0 ]; then
  msg "${GREEN}rsyslog service restarted successfully.${NC}"
else
  msg "${RED}Error: Failed to restart rsyslog service.${NC}"
  exit 1
fi

# --- STEP 7: Security Best Practices (Optional, but Recommended) ---
msg "${BLUE}--- STEP 7: Security Best Practices (Optional) ---${NC}"
msg "${YELLOW}Consider implementing these additional security measures:${NC}"
msg "${YELLOW}- Configure a strong firewall (e.g., ufw).${NC}"
msg "${YELLOW}- Regularly check system logs for suspicious activity.${NC}"
msg "${YELLOW}- Disable unnecessary services.${NC}"
msg "${YELLOW}- Implement intrusion detection and prevention systems (IDS/IPS).${NC}"
msg "${YELLOW}- Enable automatic security updates.${NC}"
msg "${YELLOW}- Harden SSH further (disable password authentication, use key-based authentication, change default port).${NC}"

msg "${GREEN}Server hardening script completed. Please review the output for any errors.${NC}"

exit 0
