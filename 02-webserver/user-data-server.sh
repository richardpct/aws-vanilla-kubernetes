#!/bin/bash

set -e -x

HELM_VERS=3.12.3
CALICO_VERS=3.26.1

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

sudo mkdir -m 755 /etc/apt/keyrings
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

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

PUBLIC_IP=$(curl -s ifconfig.me)
IPADDR=$(ip a s dev ens5 | awk '/inet /{print $2}' | awk -F / '{print $1}')
NODENAME=$(hostname -s)

sudo kubeadm init --apiserver-advertise-address=$IPADDR --apiserver-cert-extra-sans=${PUBLIC_IP},${IPADDR} --pod-network-cidr=192.168.0.0/16 --node-name $NODENAME --ignore-preflight-errors Swap

sudo mkdir /root/.kube
sudo cp /etc/kubernetes/admin.conf /root/.kube/config

sudo curl -O https://get.helm.sh/helm-v${HELM_VERS}-linux-amd64.tar.gz
sudo tar zxf helm-v${HELM_VERS}-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/

sudo helm repo add projectcalico https://docs.tigera.io/calico/charts
sudo kubectl create namespace tigera-operator
sudo helm install calico projectcalico/tigera-operator --version v${CALICO_VERS} --namespace tigera-operator

sudo helm repo add haproxytech https://haproxytech.github.io/helm-charts
sudo helm install haproxy-kubernetes-ingress haproxytech/kubernetes-ingress \
  --create-namespace \
  --namespace haproxy-controller \
  --set controller.service.nodePorts.http=30080 \
  --set controller.service.nodePorts.https=30443 \
  --set controller.service.nodePorts.stat=30002

curl -L https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml -o /tmp/components.yaml
sed -i -e 's/\(--metric-resolution=15s\)/\1\n        - --kubelet-insecure-tls/' /tmp/components.yaml
sudo kubectl apply -f /tmp/components.yaml

sudo apt-get install -y nfs-common
sudo apt-get install -y nfs-kernel-server

sudo mkdir /nfs
set +x
sudo grep 'kubeadm join' /var/log/user-data.log > /nfs/kubeadm.sh
sudo grep -- '--discovery-token-ca-cert-hash' /var/log/user-data.log >> /nfs/kubeadm.sh
set -x
sudo chmod 755 /nfs/kubeadm.sh
sudo echo '/nfs 10.0.0.0/24(rw,sync,no_root_squash,no_subtree_check)' >> /etc/exports
sudo exportfs -a
sudo helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
sudo helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=$IPADDR \
  --set nfs.path=/nfs

echo 'DONE'
