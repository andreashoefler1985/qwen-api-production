#!/bin/bash
# system_setup.sh

# System Update
sudo apt update && sudo apt upgrade -y

# Grundpakete installieren
sudo apt install -y \
    curl wget git vim htop \
    build-essential software-properties-common \
    apt-transport-https ca-certificates \
    gnupg lsb-release unzip

# Timezone setzen
sudo timedatectl set-timezone Europe/Berlin