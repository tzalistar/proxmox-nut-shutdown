#!/bin/bash

# Proxmox Graceful Reboot Script with State Preservation

# Optional: Node name (auto-detect from hostname if not provided)
NODE_NAME=$(hostname)
STATE_FILE="/var/lib/proxmox-running-state.txt"

echo "Starting graceful reboot for Proxmox node: $NODE_NAME"

# Check for running backups
if pgrep vzdump >/dev/null; then
  echo "Backup process detected (vzdump). Please wait for it to finish before rebooting."
  exit 1
fi

# Optional: Drain node (if part of a HA cluster)
# echo "Disabling HA services for node $NODE_NAME"
# ha-manager set-node $NODE_NAME --state maintenance

# Save state of currently running VMs and containers
echo "Saving state of running VMs and containers to $STATE_FILE"
> "$STATE_FILE"  # Clear existing state file

# Record running VMs
echo "Recording running VMs..."
qm list | awk 'NR>1 && $3=="running" {print "VM:" $1}' >> "$STATE_FILE"

# Record running containers
echo "Recording running containers..."
pct list | awk 'NR>1 && $3=="running" {print "CT:" $1}' >> "$STATE_FILE"

# Display what was saved
if [ -s "$STATE_FILE" ]; then
  echo "Saved state for the following running guests:"
  cat "$STATE_FILE"
else
  echo "No running VMs or containers found to save state for."
fi

# Shut down all VMs and containers
echo "Shutting down all VMs..."
qm list | awk 'NR>1 {print $1}' | while read -r vmid; do
  echo "Shutting down VM $vmid"
  qm shutdown $vmid &
done

echo "Shutting down all LXC containers..."
pct list | awk 'NR>1 {print $1}' | while read -r ct; do
  echo "Shutting down CT $ct"
  pct shutdown $ct &
done

# Wait for all shutdowns to complete
wait
echo "All VMs and containers shut down."

# Sync disks before reboot
sync

# Reboot the node
echo "Rebooting the node..."
/sbin/reboot
