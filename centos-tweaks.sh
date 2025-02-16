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
rm -f /run/motd.d/21_os_release.motd
