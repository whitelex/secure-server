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
#               This version creates the MOTD file at the beginning and uses echo to add content after each step.
#

distro=$(cat /etc/*-release | grep "DISTRIB_ID" | cut -d "=" -f 2-)

if [ "$distro" = "Ubuntu" ]; then
  echo "$distro"
else
  echo "Your system is $distro. Try using another tweak file for your system."
  exit 1
fi

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'  # No Color

# Initialize summary message variable
SUMMARY_MESSAGE=""
BASHRC_SUMMARY_MESSAGE="" # Separate summary for .bashrc
MOTD_FILE="/etc/update-motd.d/99-security-summary"

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

# --- Create MOTD file at the beginning ---
msg "${BLUE}--- Creating login welcome message script at ${MOTD_FILE} ---${NC}"
echo '#!/bin/bash' | sudo tee "$MOTD_FILE" > /dev/null
echo "" | sudo tee -a "$MOTD_FILE" > /dev/null
echo "echo -e \"${BLUE}---------------------------------------------------------------${NC}\"" | sudo tee -a "$MOTD_FILE" > /dev/null
echo "echo -e \"${BLUE}          Server Security Hardening Summary                    ${NC}\"" | sudo tee -a "$MOTD_FILE" > /dev/null
echo "echo -e \"${BLUE}---------------------------------------------------------------${NC}\"" | sudo tee -a "$MOTD_FILE" > /dev/null
sudo chmod +x "$MOTD_FILE"
msg "${GREEN}Login welcome message script created at ${MOTD_FILE}${NC}"

# --- STEP 1: System Update ---
msg "${BLUE}--- STEP 1: Updating System ---${NC}"
STEP1_PERFORMED=false

if confirm "Do you want to proceed with updating the system?"; then
  msg "Performing system update..."
  sudo apt update -y && sudo apt upgrade -y

  if [ $? -eq 0 ]; then
    msg "${GREEN}System update completed successfully.${NC}"
    STEP1_PERFORMED=true
  else
    msg "${RED}Error: System update failed.  Check for network connectivity or package manager issues.${NC}"
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
    sudo apt install openssh-server -y

    if [ $? -eq 0 ]; then
      msg "${GREEN}openssh-server installed successfully.${NC}"
      SUMMARY_MESSAGE+="${GREEN}- SSH server installed.${NC}\n"
      BASHRC_SUMMARY_MESSAGE+="- Installed SSH server\n"
      echo "echo -e \"${GREEN}- SSH server installed.${NC}\"" | sudo tee -a "$MOTD_FILE" > /dev/null # Add to MOTD
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
      STEP2_PERFORMED=true # Service management also considered part of step 2
    else
      msg "${RED}Error: Failed to start or enable sshd service.${NC}"
      exit 1
    fi
  else
    msg "${YELLOW}Skipping SSH installation.${NC}"
  fi
fi
if [[ "$STEP2_PERFORMED" == "true" ]]; then
    SUMMARY_MESSAGE+="${GREEN}- SSH service started and enabled.${NC}\n"
    BASHRC_SUMMARY_MESSAGE+="- Started and enabled SSH service\n"
    echo "echo -e \"${GREEN}- SSH service started and enabled.${NC}\"" | sudo tee -a "$MOTD_FILE" > /dev/null  # Add to MOTD
fi


# Consider disabling password authentication and enabling key-based authentication here
# This significantly improves security, but it requires setting up SSH keys first.
# Example (Requires prior key setup):
#  sudo sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
#  sudo sed -i 's/^#PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config #Recommended to disable root login via SSH
#  sudo systemctl restart sshd

# --- STEP 3: Set Timezone ---
msg "${BLUE}--- STEP 3: Setting Timezone ---${NC}"
msg "Please check available timezones at https://en.wikipedia.org/wiki/List_of_tz_database_time_zones"
msg "Proper format example: America/Toronto"

while true; do
  TIMEZONE=$(get_input "Enter the timezone in the format Region/City (e.g., America/Toronto)")
  if [[ "$TIMEZONE" =~ .*/.* ]]; then
    msg "${GREEN}Timezone format is valid.${NC}"
    break
  else
    msg "${RED}Error: Invalid timezone format. Please enter in the format Region/City.${NC}"
  fi
done

if confirm "Do you want to proceed with setting the timezone to $TIMEZONE?"; then
  msg "Setting timezone to $TIMEZONE..."
  sudo timedatectl set-timezone "$TIMEZONE"

  if [ $? -eq 0 ]; then
    msg "${GREEN}Timezone set to $TIMEZONE successfully.${NC}"
    SUMMARY_MESSAGE+="${GREEN}- Timezone set to $TIMEZONE.${NC}\n"
    BASHRC_SUMMARY_MESSAGE+="- Set timezone to $TIMEZONE\n"
     echo "echo -e \"${GREEN}- Timezone set to $TIMEZONE.${NC}\"" | sudo tee -a "$MOTD_FILE" > /dev/null # Add to MOTD
    STEP3_PERFORMED=true
  else
    msg "${RED}Error: Failed to set timezone.  Verify the timezone name is correct.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping timezone configuration.${NC}"
fi

# --- STEP 4: Install and Configure Fail2ban ---
msg "${BLUE}--- STEP 4: Install and Configure Fail2ban ---${NC}"
STEP4_PERFORMED=false

if is_package_installed fail2ban; then
  msg "${YELLOW}Fail2ban is already installed. Skipping installation.${NC}"
else
  if confirm "Do you want to proceed with installing and configuring Fail2ban?"; then
    msg "Installing fail2ban..."
    sudo apt install fail2ban -y

    if [ $? -eq 0 ]; then
      msg "${GREEN}fail2ban installed successfully.${NC}"
      SUMMARY_MESSAGE+="${GREEN}- Fail2ban installed.${NC}\n"
      BASHRC_SUMMARY_MESSAGE+="- Installed Fail2ban\n"
      echo "echo -e \"${GREEN}- Fail2ban installed.${NC}\"" | sudo tee -a "$MOTD_FILE" > /dev/null  # Add to MOTD
      STEP4_PERFORMED=true
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
      SUMMARY_MESSAGE+="${GREEN}- Fail2ban SSH jail configured.${NC}\n"
      BASHRC_SUMMARY_MESSAGE+="- Configured Fail2ban SSH jail\n"
      echo "echo -e \"${GREEN}- Fail2ban SSH jail configured.${NC}\"" | sudo tee -a "$MOTD_FILE" > /dev/null # Add to MOTD
      STEP4_PERFORMED=true
    else
      msg "${RED}Error: Failed to create /etc/fail2ban/jail.d/sshd.local.${NC}"
      exit 1
    fi
  else
    msg "${YELLOW}Skipping Fail2ban installation.${NC}"
  fi
fi

if [[ "$STEP4_PERFORMED" == "true" ]]; then
    msg "Starting and enabling fail2ban service..."
    sudo systemctl start fail2ban
    sudo systemctl enable fail2ban

    if [ $? -eq 0 ]; then
      msg "${GREEN}fail2ban service started and enabled successfully.${NC}"
      BASHRC_SUMMARY_MESSAGE+="- Started and enabled Fail2ban service\n"
    else
      msg "${RED}Error: Failed to start or enable fail2ban service.${NC}"
      exit 1
    fi

    msg "Checking fail2ban sshd status..."
    sudo fail2ban-client status sshd
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

  if [ $? -eq 0 ]; then
    msg "${GREEN}rsyslog configuration updated for Graylog successfully.${NC}"
    SUMMARY_MESSAGE+="${GREEN}- Rsyslog configured for Graylog logging to ${GRAYLOG_SERVER_IP}:${GRAYLOG_PORT}.${NC}\n"
    BASHRC_SUMMARY_MESSAGE+="- Configured Rsyslog for Graylog\n"
    echo "echo -e \"${GREEN}- Rsyslog configured for Graylog logging to ${GRAYLOG_SERVER_IP}:${GRAYLOG_PORT}.${NC}\"" | sudo tee -a "$MOTD_FILE" > /dev/null # Add to MOTD
    STEP5_PERFORMED=true
  else
    msg "${RED}Error: Failed to update rsyslog configuration for Graylog.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping Rsyslog configuration for Graylog.${NC}"
fi

# --- STEP 6: Configure Journald for Local Time ---
msg "${BLUE}--- STEP 6: Configuring Journald for Local Time ---${NC}"
STEP6_PERFORMED=false

if confirm "Do you want to proceed with configuring Journald for local time?"; then
  msg "Configuring journald to use local time..."
  sudo sed -i 's/^#UTC=yes/UTC=no/' /etc/systemd/journald.conf

  if [ $? -eq 0 ]; then
    msg "${GREEN}Journald configuration updated for local time successfully.${NC}"
    SUMMARY_MESSAGE+="${GREEN}- Journald configured to use local time.${NC}\n"
    BASHRC_SUMMARY_MESSAGE+="- Configured Journald for local time\n"
    STEP6_PERFORMED=true
  else
    msg "${RED}Error: Failed to update journald configuration for local time.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping Journald configuration for local time.${NC}"
fi

# Restart rsyslog after changes
msg "Restarting rsyslog service..."
sudo systemctl restart rsyslog

if [ $? -eq 0 ]; then
  msg "${GREEN}rsyslog service restarted successfully.${NC}"
  if [[ "$STEP5_PERFORMED" == "true" ]]; then # Only add to summary if rsyslog config was changed
    SUMMARY_MESSAGE+="${GREEN}- Rsyslog service restarted.${NC}\n"
    BASHRC_SUMMARY_MESSAGE+="- Restarted Rsyslog service\n"
  fi
else
  msg "${RED}Error: Failed to restart rsyslog service.${NC}"
  exit 1
fi

# --- STEP 7: Syntax Highlights/Coloring shell---
msg "${BLUE}--- STEP 7: Configuring Syntax Highlights & Shell Coloring---${NC}"
STEP7_PERFORMED=false

if confirm "Do you want to proceed with Configuring Syntax Highlights & Shell Coloring?"; then
  msg "Configuring Syntax Highlights & Shell Coloring..."
  export TERM=xterm-256color

  if [ $? -eq 0 ]; then
    msg "${GREEN}Syntax Highlights & Shell Coloring Configuration complete.${NC}"
    STEP7_PERFORMED=true
  else
    msg "${RED}Error: Failed to configure Syntax Highlights & Shell Coloring.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping Syntax Highlights & Shell Coloring configuration.${NC}"
fi

# --- STEP 8: Enable Google Multi-Factor Authentication (MFA) for SSH ---
msg "${BLUE}--- STEP 8: Enabling Google Multi-Factor Authentication (MFA) for SSH ---${NC}"
STEP8_PERFORMED=false

if confirm "Do you want to proceed with enabling Google MFA for SSH?"; then
  msg "Installing google-authenticator..."
  sudo apt install libpam-google-authenticator -y

  if [ $? -eq 0 ]; then
    msg "${GREEN}google-authenticator installed successfully.${NC}"
    msg "Now, you need to run the google-authenticator command. Follow the on-screen instructions carefully.  You'll need to scan a QR code with your Google Authenticator app and enter verification codes."
    sudo google-authenticator

    if [ $? -eq 0 ]; then
      msg "${GREEN}google-authenticator configuration completed.  Remember to save the emergency codes!${NC}"
      # Add the generated key to /etc/pam.d/sshd
      echo "auth required pam_google_authenticator.so" | sudo tee -a /etc/pam.d/sshd

      msg "Restarting SSH service to apply changes..."
      sudo systemctl restart sshd

      if [ $? -eq 0 ]; then
          msg "${GREEN}SSH service restarted successfully.${NC}"
          SUMMARY_MESSAGE+="${GREEN}- Google MFA enabled for SSH.${NC}\n"
          BASHRC_SUMMARY_MESSAGE+="- Enabled Google MFA for SSH\n"
          echo "echo -e \"${GREEN}- Google MFA enabled for SSH.${NC}\"" | sudo tee -a "$MOTD_FILE" > /dev/null # Add to MOTD
          STEP8_PERFORMED=true
      else
          msg "${RED}Error: Failed to restart SSH service.${NC}"
          exit 1
      fi

    else
      msg "${RED}Error: google-authenticator configuration failed. Please try again.${NC}"
      exit 1
    fi
  else
    msg "${RED}Error: Failed to install google-authenticator.${NC}"
    exit 1
  fi
else
  msg "${YELLOW}Skipping Google MFA configuration.${NC}"
fi

# --- STEP 9: Security Best Practices (Optional, but Recommended) ---
msg "${BLUE}--- STEP 9: Security Best Practices (Optional) ---${NC}"
msg "${YELLOW}Consider implementing these additional security measures:${NC}"
msg "${YELLOW}- Configure a strong firewall (e.g., ufw).${NC}"
msg "${YELLOW}- Regularly check system logs for suspicious activity.${NC}"
msg "${YELLOW}- Disable unnecessary services.${NC}"
msg "${YELLOW}- Implement intrusion detection and prevention systems (IDS/IPS).${NC}"
msg "${YELLOW}- Enable automatic security updates.${NC}"
msg "${YELLOW}- Harden SSH further (disable password authentication, use key-based authentication, change default port).${NC}"
msg "${YELLOW}- **Enable Multi-Factor Authentication (MFA) for SSH logins for enhanced security.**${NC}" # Added MFA recommendation here

msg "${GREEN}Server hardening script completed. Please review the output for any errors.${NC}"


# --- Update .bashrc for Current User ---
msg "${BLUE}--- Updating .bashrc for current user ---${NC}"

if confirm "Do you want to add the security summary to your .bashrc?"; then
  # Check if .bashrc exists; if not, create it
  if [[ ! -f "$HOME/.bashrc" ]]; then
      touch "$HOME/.bashrc"
  fi
  
  #Escape newline characters
  BASHRC_SUMMARY_MESSAGE=$(echo "$BASHRC_SUMMARY_MESSAGE" | sed 's/\n/\\n/g')

  # Add a custom prompt (example: user@host [SECURED] )
  echo "# Custom prompt to indicate security hardening" >> "$HOME/.bashrc"
    echo "PROMPT_COMMAND='PS1_CMD1=\$(ip route get 1.1.1.1 | awk -F\"src \" '\"'\"'NR == 1{ split(\$2, a,\" \");print a[1]}'\"'\"')'; PS1='\n┌─(\[\e[93m\]\t\[\e[0m\])─[Host: \[\e[1m\]\H\[\e[0m\]@\${PS1_CMD1}]\n└[\w]\[\e[92m\]#\[\e[0m\] '" >> "$HOME/.bashrc"

  msg "${GREEN}.bashrc updated with security summary and custom prompt.${NC}"
else
  msg "${YELLOW}Skipping .bashrc update.${NC}"
fi

exit 0
