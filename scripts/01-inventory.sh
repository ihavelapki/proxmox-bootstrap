#!/usr/bin/env bash

set -u
set -o pipefail

section() {
    printf '\n===== %s =====\n' "$1"
}

section "Host and Proxmox version"

printf '%s\n' "--- Hostname ---"
hostname
hostname -f

printf '\n%s\n' "--- Proxmox VE version ---"
pveversion
pveversion -v

printf '\n%s\n' "--- Kernel and uptime ---"
uname -r
uptime

section "Hardware resources"

printf '%s\n' "--- CPU ---"
lscpu

printf '\n%s\n' "--- Memory ---"
free -h

printf '\n%s\n' "--- Block devices ---"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS

printf '\n%s\n' "--- Filesystem mounts ---"
df -hT

section "Network interfaces"

printf '%s\n' "--- Link state and MAC addresses ---"
ip -br link

printf '\n%s\n' "--- Interface addresses ---"
ip -br addr

printf '\n%s\n' "--- Bridge ports ---"
bridge link

printf '\n%s\n' "--- Bridge VLANs ---"
bridge vlan show

section "Routing and DNS"

printf '%s\n' "--- IPv4 routes ---"
ip route

printf '\n%s\n' "--- IPv6 routes ---"
ip -6 route

printf '\n%s\n' "--- /etc/resolv.conf ---"
cat /etc/resolv.conf

printf '\n%s\n' "--- /etc/hosts ---"
cat /etc/hosts

section "Proxmox network configuration"

printf '%s\n' "--- /etc/network/interfaces ---"
if [[ -r /etc/network/interfaces ]]; then
    cat /etc/network/interfaces
else
    printf '%s\n' "/etc/network/interfaces is not readable or does not exist."
fi

printf '\n%s\n' "--- /etc/network/interfaces.d/ ---"
if [[ -d /etc/network/interfaces.d ]]; then
    NETWORK_CONFIG_FOUND=false

    for NETWORK_CONFIG_FILE in /etc/network/interfaces.d/*; do
        [[ -f "$NETWORK_CONFIG_FILE" ]] || continue
        NETWORK_CONFIG_FOUND=true

        printf '\n--- %s ---\n' "$NETWORK_CONFIG_FILE"
        cat "$NETWORK_CONFIG_FILE"
    done

    if [[ "$NETWORK_CONFIG_FOUND" == false ]]; then
        printf '%s\n' "No regular configuration files found."
    fi
else
    printf '%s\n' "/etc/network/interfaces.d does not exist."
fi

section "Cluster status"

printf '%s\n' "--- Cluster status ---"
if ! pvecm status; then
    printf '%s\n' "Cluster status is unavailable; this is expected on a standalone node."
fi

printf '\n%s\n' "--- Cluster nodes ---"
if ! pvecm nodes; then
    printf '%s\n' "Cluster node list is unavailable; this is expected on a standalone node."
fi

section "Proxmox storage"

printf '%s\n' "--- Configured Proxmox storage ---"
pvesm status

printf '\n%s\n' "--- LVM volume groups ---"
vgs

printf '\n%s\n' "--- LVM logical volumes ---"
lvs

printf '\n%s\n' "--- ZFS pools ---"
if command -v zpool >/dev/null 2>&1; then
    zpool list
else
    printf '%s\n' "zpool is not installed; skipping ZFS pool inventory."
fi

printf '\n%s\n' "--- ZFS datasets ---"
if command -v zfs >/dev/null 2>&1; then
    zfs list -o name,used,avail,refer,mountpoint
else
    printf '%s\n' "zfs is not installed; skipping ZFS dataset inventory."
fi

section "Virtual machines and containers"

printf '%s\n' "--- Virtual machines ---"
qm list

printf '\n%s\n' "--- Containers ---"
pct list

section "Firewall status"

printf '%s\n' "--- Installed Proxmox firewall packages ---"
if ! pveversion -v | grep -E '^(pve-firewall|proxmox-firewall):'; then
    printf '%s\n' "No Proxmox firewall package was reported."
fi

printf '\n%s\n' "--- Firewall services ---"
for FIREWALL_SERVICE in pve-firewall.service proxmox-firewall.service; do
    FIREWALL_LOAD_STATE=$(systemctl show "$FIREWALL_SERVICE" --property=LoadState --value)

    if [[ "$FIREWALL_LOAD_STATE" == "not-found" ]]; then
        printf '%s\n' "$FIREWALL_SERVICE is not installed."
    elif [[ -z "$FIREWALL_LOAD_STATE" ]]; then
        printf '%s\n' "Could not determine whether $FIREWALL_SERVICE is installed."
    else
        systemctl status "$FIREWALL_SERVICE" --no-pager
    fi
done

printf '\n%s\n' "--- Datacenter firewall configuration ---"
if [[ -r /etc/pve/firewall/cluster.fw ]]; then
    cat /etc/pve/firewall/cluster.fw
else
    printf '%s\n' "/etc/pve/firewall/cluster.fw is not present or readable."
fi

NODE_NAME=$(hostname -s)
NODE_FIREWALL_FILE="/etc/pve/nodes/$NODE_NAME/host.fw"

printf '\n--- Node firewall configuration: %s ---\n' "$NODE_FIREWALL_FILE"
if [[ -r "$NODE_FIREWALL_FILE" ]]; then
    cat "$NODE_FIREWALL_FILE"
else
    printf '%s\n' "$NODE_FIREWALL_FILE is not present or readable."
fi

section "Network services"

ss -lntup

section "Time synchronization"

printf '%s\n' "--- System time status ---"
timedatectl

printf '\n%s\n' "--- Chrony synchronization ---"
if command -v chronyc >/dev/null 2>&1; then
    chronyc tracking
else
    printf '%s\n' "chronyc is not installed; skipping chrony synchronization status."
fi
