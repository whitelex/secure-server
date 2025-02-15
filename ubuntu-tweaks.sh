#!/bin/bash
#
# Tweaks

distro=$(cat /etc/*-release | grep "DISTRIB_ID" | cut -d "=" -f 2-)

if [ "$distro" = "Ubuntu" ]; then
  echo "$distro"
else
  echo "Your system is $distro. Try using another tweak file for your system."
  exit 1
fi

motd="/etc/update-motd.d/"

rm -f $motd/00-header
rm -f $motd/10-help-text
rm -f $motd/50-motd-news

wget -P "$motd" https://github.com/whitelex/secure-server/raw/refs/heads/main/00-ubuntu-header || { echo "Failed to download new 00-ubuntu-header" >&2; exit 1; }
chmod +x "$motd/00-ubuntu-header" || { echo "Failed to make 00-header executable" >&2; exit 1; }

wget -P "$motd" https://raw.githubusercontent.com/yboetz/motd/refs/heads/master/40-services || { echo "Failed to download new 40-services" >&2; exit 1; }
chmod +x "$motd/40-services" || { echo "Failed to make 40-services executable" >&2; exit 1; }

wget -P "$motd" https://raw.githubusercontent.com/yboetz/motd/refs/heads/master/20-sysinfo || { echo "Failed to download new 20-sysinfo" >&2; exit 1; }
chmod +x "$motd/20-sysinfo" || { echo "Failed to make 20-sysinfo executable" >&2; exit 1; }

echo "Operation Complete! Logout and login again to see the results."
