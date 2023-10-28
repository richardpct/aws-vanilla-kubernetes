#!/bin/bash

set -e -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch="$(dpkg --print-architecture)" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  "$(. /etc/os-release && echo "$VERSION_CODENAME")" stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install containerd.io -y

sudo containerd config default > /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

sudo systemctl restart containerd
sudo systemctl enable containerd

curl -fsSL https://pkgs.k8s.io/core:/stable:/v${kube_vers}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${kube_vers}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

PUBLIC_IP=$(curl -s ifconfig.me)
IPADDR=$(ip a s dev ens5 | awk '/inet /{print $2}' | awk -F / '{print $1}')
NODENAME=$(hostname -s)

sudo kubeadm init --apiserver-advertise-address=$IPADDR --apiserver-cert-extra-sans=$PUBLIC_IP,$IPADDR --pod-network-cidr=192.168.0.0/16 --node-name $NODENAME --ignore-preflight-errors Swap

sudo mkdir /root/.kube
sudo cp /etc/kubernetes/admin.conf /root/.kube/config
mkdir /home/ubuntu/.kube
sudo install -m 644 -o ubuntu -g ubuntu /etc/kubernetes/admin.conf /home/ubuntu/.kube/
mv /home/ubuntu/.kube/admin.conf /home/ubuntu/.kube/config

sudo curl -O https://get.helm.sh/helm-v${helm_vers}-linux-amd64.tar.gz
sudo tar zxf helm-v${helm_vers}-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/

sudo apt-get install -y nfs-common
sudo apt-get install -y nfs-kernel-server

sudo mkdir /nfs
set +x
sudo grep 'kubeadm join' /var/log/user-data.log > /nfs/kubeadm.sh
sudo grep -- '--discovery-token-ca-cert-hash' /var/log/user-data.log >> /nfs/kubeadm.sh
set -x
sudo chmod 755 /nfs/kubeadm.sh
sudo echo '/nfs 10.0.0.0/16(rw,sync,no_root_squash,no_subtree_check)' >> /etc/exports
sudo exportfs -a
#[ -f /var/run/reboot-required ] && shutdown -r now
