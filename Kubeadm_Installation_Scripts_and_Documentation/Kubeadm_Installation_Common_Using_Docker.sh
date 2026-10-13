#!/bin/bash

# Execute on Both "Master" & "Worker" Nodes:

# 1. Disable Swap: Required for Kubernetes to function correctly.
echo "Disabling swap..."
sudo swapoff -a
sleep 2

# 2. Load Necessary Kernel Modules: Required for Kubernetes networking.
echo "Loading necessary kernel modules for Kubernetes networking..."
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter
sleep 2

# 3. Set Sysctl Parameters: Helps with networking.
echo "Setting sysctl parameters for networking..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system
lsmod | grep br_netfilter
lsmod | grep overlay
sleep 2

# 4. Install Docker:
echo "Installing containerd..."
sudo apt-get update
sleep 2

sudo apt-get install -y ca-certificates curl apt-transport-https
sleep 2

sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
sleep 2

sudo apt-get update
sleep 2

sudo apt-get install -y docker.io
sleep 2

sudo systemctl restart docker
sleep 2

sudo systemctl is-active docker
sleep 2


# Install cri-dockerd: Docker adapter for Kubernetes
echo "Installing cri-dockerd..."

sudo apt-get update
sudo apt-get install -y curl tar

ARCH=$(dpkg --print-architecture)
VERSION=$(curl -fsSL \
  https://api.github.com/repos/Mirantis/cri-dockerd/releases/latest \
  | grep '"tag_name":' | cut -d '"' -f 4 | sed 's/^v//')

curl -fL \
  "https://github.com/Mirantis/cri-dockerd/releases/download/v${VERSION}/cri-dockerd-${VERSION}.${ARCH}.tgz" \
  -o /tmp/cri-dockerd.tgz

tar -xzf /tmp/cri-dockerd.tgz -C /tmp

sudo install -o root -g root -m 0755 \
  /tmp/cri-dockerd/cri-dockerd /usr/local/bin/cri-dockerd

sudo curl -fsSL \
  https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service \
  -o /etc/systemd/system/cri-docker.service

sudo curl -fsSL \
  https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket \
  -o /etc/systemd/system/cri-docker.socket

sudo sed -i \
  's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' \
  /etc/systemd/system/cri-docker.service

sudo systemctl daemon-reload
sudo systemctl enable --now cri-docker.socket

sudo systemctl status cri-docker.socket --no-pager


# 5. Install Kubernetes Components:
echo "Installing Kubernetes components (kubelet, kubeadm, kubectl)..."
sudo apt-get update
sleep 2

sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sleep 2

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sleep 2

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sleep 2

sudo apt-get install -y kubelet kubeadm kubectl
sleep 2

sudo apt-mark hold kubelet kubeadm kubectl
sleep 2

echo "Kubernetes setup completed."
