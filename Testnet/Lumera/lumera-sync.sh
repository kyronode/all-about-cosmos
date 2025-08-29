#!/bin/bash


rpc_port=$(grep -m 1 -oP '^laddr = "\K[^"]+' "$HOME/.lumera/config/config.toml" | cut -d ':' -f 3)

while true; do
  
  local_height=$(curl -s localhost:$rpc_port/status | jq -r '.result.sync_info.latest_block_height')

  
  network_height=$(curl -s https://lumera-testnet-rpc.polkachu.com/status | jq -r '.result.sync_info.latest_block_height')

  
  if ! [[ "$local_height" =~ ^[0-9]+$ ]] || ! [[ "$network_height" =~ ^[0-9]+$ ]]; then
    echo -e "\033[1;31mError: Invalid block height data. Retrying...\033[0m"
    sleep 5
    continue
  fi

  
  blocks_left=$((network_height - local_height))

  
  echo -e "\033[1;33mNode Height:\033[1;34m $local_height\033[0m \
\033[1;33m| Network Height:\033[1;36m $network_height\033[0m \
\033[1;33m| Blocks Left:\033[1;31m $blocks_left\033[0m"

  sleep 5
done
