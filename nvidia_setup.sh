#!/bin/bash
# nvidia_setup.sh

# NVIDIA Repository hinzufügen
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb
sudo apt update

# NVIDIA Driver & CUDA installieren
sudo apt install -y nvidia-driver-535 nvidia-cuda-toolkit

# Reboot erforderlich
echo "Reboot required after NVIDIA installation!"
echo "Run 'sudo reboot' and continue with docker setup"