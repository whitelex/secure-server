#!/bin/bash
#
# Tweaks
motd="/etc/update-motd.d/"

rm -f $motd/00-header
rm -f $motd/10-help-text
rm -f $motd/50-motd-news

wget -P "$motd" https://github.com/whitelex/secure-server/raw/refs/heads/main/00-header || { echo "Failed to download new 00-header" >&2; exit 1; }
chmod +x "$motd/00-header" || { echo "Failed to make 00-header executable" >&2; exit 1; }

