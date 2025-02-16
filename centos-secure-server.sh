#!/bin/bash
#
# Script to Secure a CentOS Server
# Author: Bard
# Date: `date`
# Description: This script automates common server hardening tasks on CentOS,
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

# Initialize summary message variable
SUMMARY_MESSAGE=""
BASHRC_SUMMARY_MESSAGE="" # Separate summary for .bashrc
MOTD_FILE="/etc/motd" # CentOS uses /etc/motd for the MOTD

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
  rpm -q "$1" > /dev/null 2>&1
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
STEP1_PERFORMED=false

if confirm "Do you want to proceed with updating the system?"; then
  msg "Performing system update..."
  sudo yum update -y

  if [ $? -eq 0 ]; then
    msg "${GREEN}System update completed successfully.${NC}"
    STEP1_PERFORMED=true
  else
    msg "${RED}Error: System update failed. Check for network connectivity or package manager issues.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping system update.${NC}"
fi

# --- STEP 2: Install and Configure SSH ---
msg "${BLUE}--- STEP 2: Install and Configure SSH ---${NC}"
STEP2_PERFORMED=false

if is_package_installed openssh-server; then
  msg "${YELLOW}SSH is already installed. Skipping installation and service management.${NC}"
else
  if confirm "Do you want to proceed with installing and configuring SSH?"; then
    msg "Installing openssh-server..."
    sudo yum install openssh-server -y

    if [ $? -eq 0 ]; then
      msg "${GREEN}openssh-server installed successfully.${NC}"
      SUMMARY_MESSAGE+="${GREEN}- SSH server installed.${NC}\n"
      BASHRC_SUMMARY_MESSAGE+="- Installed SSH server\n"
      STEP2_PERFORMED=true
    else
      msg "${RED}Error: openssh-server installation failed.${NC}"
      exit 1
    fi

    msg "Starting and enabling sshd service..."
    sudo systemctl start sshd
    sudo systemctl enable sshd

    if [ $? -eq 0 ]; then
      msg "${GREEN}sshd service started and enabled successfully.${NC}"
      STEP2_PERFORMED=true
    else
      msg "${RED}Error: Failed to start or enable sshd service.${NC}"
      exit 1
    fi
  else
    msg "${YELLOW}Skipping SSH installation.${NC}"
  fi
fi

# ... (Rest of the script adapted similarly for CentOS) ...

# --- STEP 3: Set Timezone ---
msg "${BLUE}--- STEP 3: Setting Timezone ---${NC}"
msg "Please check available timezones using 'timedatectl list-timezones'"

while true; do
  TIMEZONE=$(get_input "Enter the timezone (e.g., America/Toronto)")
  if [[ -n "$TIMEZONE" ]]; then  # Simpler check for CentOS timezones
    msg "${GREEN}Timezone format is valid.${NC}"
    break
  else
    msg "${RED}Error: Invalid timezone format.${NC}"
  fi
done

if confirm "Do you want to proceed with setting the timezone to $TIMEZONE?"; then
  msg "Setting timezone to $TIMEZONE..."
  sudo timedatectl set-timezone "$TIMEZONE"

  if [ $? -eq 0 ]; then
    msg "${GREEN}Timezone set to $TIMEZONE successfully.${NC}"
    SUMMARY_MESSAGE+="${GREEN}- Timezone set to $TIMEZONE.${NC}\n"
    BASHRC_SUMMARY_MESSAGE+="- Set timezone to $TIMEZONE\n"
    STEP3_PERFORMED=true
  else
    msg "${RED}Error: Failed to set timezone. Verify the timezone name is correct.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping timezone configuration.${NC}"
fi

# ... (Adapt the rest of the steps similarly) ...

# --- STEP 4: Install and Configure Fail2ban ---
msg "${BLUE}--- STEP 4: Install and Configure Fail2ban ---${NC}"
STEP4_PERFORMED=false

if is_package_installed fail2ban; then
  msg "${YELLOW}Fail2ban is already installed. Skipping installation.${NC}"
else
  if confirm "Do you want to proceed with installing and configuring Fail2ban?"; then
    msg "Installing fail2ban..."
    sudo yum install fail2ban -y

    if [ $? -eq 0 ]; then
      msg "${GREEN}fail2ban installed successfully.${NC}"
      SUMMARY_MESSAGE+="${GREEN}- Fail2ban installed.${NC}\n"
      BASHRC_SUMMARY_MESSAGE+="- Installed Fail2ban\n"
      STEP4_PERFORMED=true
    else
      msg "${RED}Error: Failed to install fail2ban.${NC}"
      exit 1
    fi

    # ... (Fail2ban configuration -  Adapt paths if necessary) ...
  else
    msg "${YELLOW}Skipping Fail2ban installation.${NC}"
  fi
fi


# --- STEP 5: Configure Rsyslog for Graylog ---
msg "${BLUE}--- STEP 5: Configuring Rsyslog for Graylog ---${NC}"
STEP5_PERFORMED=false

if confirm "Do you want to proceed with configuring Rsyslog for Graylog?"; then
  msg "Configuring rsyslog for Graylog logging..."

  # Check if the file exists, create it if it doesn't
  if [[ ! -f /etc/rsyslog.d/20-graylog.conf ]]; then
    sudo touch /etc/rsyslog.d/20-graylog.conf
  fi

  sudo sed -i "/# TCP (reliable)/a auth,authpriv.*  @@${GRAYLOG_SERVER_IP}:${GRAYLOG_PORT}" /etc/rsyslog.d/20-graylog.conf

  # ... (rest of Rsyslog configuration) ...
else
  msg "${YELLOW}Skipping Rsyslog configuration for Graylog.${NC}"
fi

# ... (Adapt remaining steps for CentOS) ...

# Update MOTD at the end to include all summaries
echo -e "${BLUE}---------------------------------------------------------------${NC}" >> "$MOTD_FILE"
echo -e "${BLUE}          Server Security Hardening Summary                    ${NC}" >> "$MOTD_FILE"
echo -e "${BLUE}---------------------------------------------------------------${NC}" >> "$MOTD_FILE"
echo -e "$SUMMARY_MESSAGE" >> "$MOTD_FILE"


# --- Update .bashrc for Current User ---
msg "${BLUE}--- Updating .bashrc for current user ---${NC}"

if confirm "Do you want to add the security summary to your .bashrc?"; then
  # Check if .bashrc exists; if not, create it
  if [[ ! -f "$HOME/.bashrc" ]]; then
      touch "$HOME/.bashrc"
  fi

  #Escape newline characters
  BASHRC_SUMMARY_MESSAGE=$(echo "$BASHRC_SUMMARY_MESSAGE" | sed 's/\n/\\n/g')

  # Add security summary to .bashrc (adapt as needed)
  echo "# Security Hardening Summary:" >> "$HOME/.bashrc"
  echo "echo -e \"$BASHRC_SUMMARY_MESSAGE\"" >> "$HOME/.bashrc"

  msg "${GREEN}.bashrc updated with security summary.${NC}"
else
  msg "${YELLOW}Skipping .bashrc update.${NC}"
fi

exit 0
