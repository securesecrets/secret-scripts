#!/bin/bash

set -e

# Total number of steps
TOTAL_STEPS=8

# Function to display messages in bold and with a green color
display_message() {
    echo -e "\033[1;32mStep $1/$TOTAL_STEPS: $2\033[0m"
}

# Function to handle errors
handle_error() {
    echo -e "\033[1;31mError: $1\033[0m" 1>&2
    exit 1
}

display_message 1 "Downloading secret network snapshot..."
wget -O secret.tar.lz4 https://snapshots.lavenderfive.com/snapshots/secretnetwork/latest.tar.lz4 || handle_error "Failed to download secret network snapshot"

display_message 2 "Updating packages and installing dependencies..."
sudo apt update && sudo apt install -y snapd lz4 pv || handle_error "Failed to install dependencies"

display_message 3 "Stopping secret-node service..."
sudo systemctl stop cosmovisor || handle_error "Failed to stop secret-node service"

display_message 4 "Removing old data and .compute directories..."
rm -rf $HOME/.secretd/data $HOME/.secretd/.compute || handle_error "Failed to remove old data and .compute directories"

display_message 5 "Resetting tendermint state..."
secretd tendermint unsafe-reset-all --home $HOME/.secretd || handle_error "Failed to reset tendermint state"

display_message 6 "Decompressing and extracting snapshot..."
# Using pv to show progress. The lz4 file size needs to be provided to pv.
SNAPSHOT_SIZE=$(du -sb secret.tar.lz4 | awk '{ print $1 }')
lz4 -c -d secret.tar.lz4 | pv -s $SNAPSHOT_SIZE | tar -x -C $HOME/.secretd || handle_error "Failed to decompress and extract snapshot"

display_message 7 "Downloading address book..."
wget -O addrbook.json https://snapshots.lavenderfive.com/addrbooks/secretnetwork/addrbook.json || handle_error "Failed to download address book"
mv addrbook.json $HOME/.secretd/config || handle_error "Failed to move address book"

display_message 8 "Restarting secret-node and displaying logs..."
sudo systemctl restart cosmovisor && journalctl -fu cosmovisor || handle_error "Failed to restart secret-node service"
