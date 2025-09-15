#!/bin/bash
set -e

# ================================
# AUTO INSTALLER PAXI NODE
# ================================

echo -e "\n===== AUTO INSTALL PAXI NODE by Kyronode.xyz =====\n"

# --- USER INPUT ---
read -p "Enter your wallet name: " WALLET
read -p "Enter your moniker (validator name): " MONIKER
read -p "Enter your custom port (example 43, 56, 75): " APP_PORT

# --- INSTALL DEPENDENCIES ---
sudo apt update && sudo apt upgrade -y
sudo apt install curl git wget make gcc tmux build-essential jq lz4 unzip -y

# --- INSTALL GO ---
cd $HOME
VER="1.24.4"
wget "https://golang.org/dl/go$VER.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$VER.linux-amd64.tar.gz"
rm "go$VER.linux-amd64.tar.gz"

[ ! -f ~/.bash_profile ] && touch ~/.bash_profile
echo "export PATH=$PATH:/usr/local/go/bin:~/go/bin" >> ~/.bash_profile
source $HOME/.bash_profile
[ ! -d ~/go/bin ] && mkdir -p ~/go/bin

# --- ENV VARIABLES ---
echo "export WALLET=$WALLET" >> $HOME/.bash_profile
echo "export MONIKER=$MONIKER" >> $HOME/.bash_profile
echo "export APP_PORT=$APP_PORT" >> $HOME/.bash_profile
source $HOME/.bash_profile

# --- DOWNLOAD BINARY ---
cd $HOME
rm -rf paxi
git clone https://github.com/paxi-web3/paxi.git
cd paxi
git checkout v1.0.6
go build -mod=readonly -tags "cosmwasm pebbledb" -o $HOME/go/bin/paxid ./cmd/paxid

# --- INIT & CONFIG ---
paxid init $MONIKER --chain-id paxi-mainnet
paxid config set client chain-id paxi-mainnet
paxid config set client node tcp://localhost:${APP_PORT}657

# --- GENESIS & ADDRBOOK ---
curl -Ls https://raw.githubusercontent.com/kyronode/all-about-cosmos/refs/heads/main/Mainnet/Paxi/genesis.json > ~/go/bin/paxi/config/genesis.json
curl -Ls https://raw.githubusercontent.com/kyronode/all-about-cosmos/refs/heads/main/Mainnet/Paxi/addrbook.json > ~/go/bin/paxi/config/addrbook.json

# --- CUSTOM PORTS ---
# app.toml
sed -i.bak -e "s%:1317%:${APP_PORT}317%g;
s%:8080%:${APP_PORT}080%g;
s%:9090%:${APP_PORT}090%g;
s%:9091%:${APP_PORT}091%g;
s%:8545%:${APP_PORT}545%g;
s%:8546%:${APP_PORT}546%g;
s%:6065%:${APP_PORT}065%g" ~/go/bin/paxi/config/app.toml

# config.toml
sed -i.bak -e "s%:26658%:${APP_PORT}658%g;
s%:26657%:${APP_PORT}657%g;
s%:6060%:${APP_PORT}060%g;
s%:26656%:${APP_PORT}656%g;
s%^external_address = \"\"%external_address = \"$(wget -qO- eth0.me):${APP_PORT}656\"%;
s%:26660%:${APP_PORT}660%g" ~/go/bin/paxi/config/config.toml

# --- PRUNING & GAS SETTINGS ---
sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" ~/go/bin/paxi/config/app.toml 
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" ~/go/bin/paxi/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" ~/go/bin/paxi/config/app.toml
sed -i 's|minimum-gas-prices =.*|minimum-gas-prices = "0.01upaxi"|g' ~/go/bin/paxi/config/app.toml
sed -i -e "s/prometheus = false/prometheus = true/" ~/go/bin/paxi/config/config.toml
sed -i -e "s/^indexer *=.*/indexer = \"null\"/" ~/go/bin/paxi/config/config.toml

# --- CREATE SERVICE FILE ---
sudo tee /etc/systemd/system/paxid.service > /dev/null <<EOF
[Unit]
Description=paxi
After=network-online.target
[Service]
User=$USER
ExecStart=$(which paxid) start
Restart=on-failure
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# --- SNAPSHOT INSTALL ---
sudo systemctl daemon-reload
sudo systemctl stop paxid || true

cp ~/go/bin/paxi/data/priv_validator_state.json ~/go/bin/paxi/priv_validator_state.json.backup || true
paxid tendermint unsafe-reset-all --home ~/go/bin/paxi --keep-addr-book
curl -L https://snapshot-t.vinjan.xyz/paxi/latest.tar.lz4  | lz4 -dc - | tar -xf - -C ~/go/bin/paxi
mv ~/go/bin/paxi/priv_validator_state.json.backup ~/go/bin/paxi/data/priv_validator_state.json || true

# --- INSTALL WASM SYNC ---
echo -e "\n===== Installing Wasm Sync =====\n"
bash <(curl -s https://raw.githubusercontent.com/kyronode/all-about-cosmos/refs/heads/main/Mainnet/Paxi/wasm.sh)

# --- START NODE ---
sudo systemctl enable paxid
sudo systemctl restart paxid

echo -e "\n===== INSTALLATION COMPLETE! ====="
echo "Check logs with: journalctl -u paxid -fo cat"
