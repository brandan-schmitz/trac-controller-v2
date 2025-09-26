#!/usr/bin/env bash
# Apply network settings via nmcli. Limited surface for sudoers.
set -euo pipefail
cmd="$1"; shift || true

# Helper functions
die(){ echo "ERR: $*" >&2; exit 1; }
require(){ command -v "$1" >/dev/null || die "$1 missing"; }
require nmcli

case "$cmd" in
  wifi)
    # wifi <ssid> <psk> [hidden:true|false]
    ssid="$1"; psk="$2"; hidden="${3:-false}"
    dev="wlan0"
    conn="TRAC-WIFI"
    nmcli con show "$conn" >/dev/null 2>&1 || nmcli con add type wifi ifname "$dev" con-name "$conn" ssid "$ssid"
    nmcli con modify "$conn" wifi.ssid "$ssid" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$psk"
    if [[ "$hidden" == "true" ]]; then nmcli con modify "$conn" wifi.hidden yes; else nmcli con modify "$conn" wifi.hidden no; fi
    nmcli con up "$conn" || true
    ;;
  wifi-ipv4)
    # wifi-ipv4 dhcp | static <address> <gateway> <dns1>[,<dnsN>]
    mode="$1"
    conn="TRAC-WIFI"
    if [[ "$mode" == "dhcp" ]]; then
      nmcli con modify "$conn" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
    else
      addr="$2"; gw="$3"; dns="$4"
      nmcli con modify "$conn" ipv4.method manual ipv4.addresses "$addr" ipv4.gateway "$gw" ipv4.dns "$dns"
    fi
    nmcli con up "$conn" || true
    ;;
  eth-ipv4)
    # eth-ipv4 dhcp | static <address> <gateway> <dns1>[,<dnsN>]
    mode="$1"
    conn="TRAC-ETH"
    nmcli con show "$conn" >/dev/null 2>&1 || nmcli con add type ethernet ifname eth0 con-name "$conn"
    if [[ "$mode" == "dhcp" ]]; then
      nmcli con modify "$conn" ipv4.method auto ipv4.addresses "" ipv4.gateway "" ipv4.dns ""
    else
      addr="$2"; gw="$3"; dns="$4"
      nmcli con modify "$conn" ipv4.method manual ipv4.addresses "$addr" ipv4.gateway "$gw" ipv4.dns "$dns"
    fi
    nmcli con up "$conn" || true
    ;;
  scan)
    # scan wifi — prints terse list
    nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list --rescan yes
    ;;
  *) die "unknown command" ;;
esac