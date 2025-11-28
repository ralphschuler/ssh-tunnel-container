#!/usr/bin/env bash

# entrypoint.sh – read a YAML configuration and execute ssh port forwards
#
# Expects yq to be available for parsing.  The CONFIG_PATH environment
# variable points to the YAML file to load.  The script builds up an
# ssh command with all configured -L options and replaces the shell
# process with ssh (-N so no command is executed on the server).

set -euo pipefail

# Config file path (overrideable via environment)
CONFIG_PATH="${CONFIG_PATH:-/config/config.yml}"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "[ERROR] Config file not found: $CONFIG_PATH" >&2
  exit 1
fi

# Extract top-level fields from YAML
host=$(yq -r '.host // empty' "$CONFIG_PATH")
user=$(yq -r '.user // empty' "$CONFIG_PATH")
port=$(yq -r '.port // 22' "$CONFIG_PATH")
identity=$(yq -r '.identityFile // empty' "$CONFIG_PATH")

if [ -z "$host" ] || [ -z "$user" ]; then
  echo "[ERROR] 'host' and 'user' must be specified in the config file." >&2
  exit 1
fi

# Start building the ssh command
cmd=(ssh -N)

# Additional SSH options from array
if yq -e '.sshOptions' "$CONFIG_PATH" > /dev/null 2>&1; then
  mapfile -t ssh_opts < <(yq -r '.sshOptions[] | tostring' "$CONFIG_PATH")
  if [ "${#ssh_opts[@]}" -gt 0 ]; then
    cmd+=("${ssh_opts[@]}")
  fi
fi

# Set port if provided
cmd+=( -p "$port" )

# Identity file, if set
if [ -n "$identity" ] && [ "$identity" != "null" ]; then
  cmd+=( -i "$identity" )
fi

# Parse tunnel definitions
if ! yq -e '.tunnels' "$CONFIG_PATH" >/dev/null 2>&1; then
  echo "[ERROR] No 'tunnels' section found in config file." >&2
  exit 1
fi

# Build -L forward options
while IFS=$'\t' read -r localPort remoteHost remotePort bindAddress; do
  [ -z "$localPort" ] && continue
  bindAddress="${bindAddress:-127.0.0.1}"
  forward="${bindAddress}:${localPort}:${remoteHost}:${remotePort}"
  echo "[INFO] Adding tunnel: -L ${forward}"
  cmd+=( -L "$forward" )
done < <(
  yq -r '.tunnels[] | [.localPort, .remoteHost, .remotePort, (.bindAddress // "127.0.0.1")] | @tsv' "$CONFIG_PATH"
)

# Append user@host target
cmd+=( "${user}@${host}" )

echo "[INFO] Executing: ${cmd[*]}"

# Execute ssh as PID 1
exec "${cmd[@]}"
