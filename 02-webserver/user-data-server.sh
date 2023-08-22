#!/bin/bash

set -e -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install docker-ce docker-ce-cli containerd.io -y

cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo systemctl enable docker
sudo systemctl daemon-reload
sudo systemctl restart docker

sudo apt-get install -y apt-transport-https ca-certificates curl
sudo mkdir -p /etc/apt/keyrings
sudo curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update -y
sudo apt-get install -y kubelet=1.27.3-00 kubeadm=1.27.3-00 kubectl=1.27.3-00

rm /etc/containerd/config.toml
systemctl restart containerd

PUBLIC_IP=$(curl -s ifconfig.me)
IPADDR=$(ip a s dev ens5 | awk '/inet /{print $2}' | awk -F / '{print $1}')
NODENAME=$(hostname -s)

sudo kubeadm init --apiserver-advertise-address=$IPADDR --apiserver-cert-extra-sans=${PUBLIC_IP},${IPADDR} --pod-network-cidr=192.168.0.0/16 --node-name $NODENAME --ignore-preflight-errors Swap

sudo mkdir /root/.kube
sudo cp /etc/kubernetes/admin.conf /root/.kube/config

sudo curl -O https://get.helm.sh/helm-v3.12.3-linux-amd64.tar.gz
sudo tar zxf helm-v3.12.3-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/

sudo helm repo add projectcalico https://docs.tigera.io/calico/charts
sudo kubectl create namespace tigera-operator
sudo helm install calico projectcalico/tigera-operator --version v3.25.1 --namespace tigera-operator

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
sudo echo '/nfs 10.0.0.0/24(rw,sync,no_root_squash,no_subtree_check)' >> /etc/exports
sudo exportfs -a
sudo helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
sudo helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --set nfs.server=$IPADDR \
  --set nfs.path=/nfs

echo 'DONE'
