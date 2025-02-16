#!/bin/bash
#
# Tweaks

distro=$(cat /etc/*-release | (grep "ID=" || grep "NAME=") | head -n 1 | cut -d "=" -f 2- | tr -d '"')

if [[ "$distro" =~ ^(centos|redhat|fedora)$ ]]; then
  echo "$distro"
else
  echo "Your system is $distro. Try using another tweak file for your system."
  exit 1
fi

# CentOS uses /etc/motd for static messages, but we can mimic Ubuntu's dynamic MOTD
motd="/etc/profile.d/"

# Remove old MOTD files if they exist
rm -f $motd/00-header.sh
rm -f $motd/10-help-text.sh
rm -f $motd/50-motd-news.sh

# Download new MOTD scripts, adapting for CentOS
wget -P "$motd" https://raw.githubusercontent.com/whitelex/secure-server/refs/heads/main/00-centos-header || { echo "Failed to download new 00-centos-header.sh" >&2; exit 1; }
chmod +x "$motd/00-centos-header.sh" || { echo "Failed to make 00-centos-header.sh executable" >&2; exit 1; }

wget -P "$motd" https://raw.githubusercontent.com/yboetz/motd/refs/heads/master/40-services || { echo "Failed to download new 40-services" >&2; exit 1; }
chmod +x "$motd/40-services" || { echo "Failed to make 40-services executable" >&2; exit 1; }

wget -P "$motd" https://raw.githubusercontent.com/yboetz/motd/refs/heads/master/20-sysinfo || { echo "Failed to download new 20-sysinfo" >&2; exit 1; }
chmod +x "$motd/20-sysinfo" || { echo "Failed to make 20-sysinfo executable" >&2; exit 1; }

# Note: These scripts might need manual adjustment to work with CentOS environments
echo "Operation Complete! Logout and login again to see the results."
