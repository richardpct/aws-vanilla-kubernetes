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

curl -L -O https://github.com/containerd/containerd/releases/download/v${containerd_vers}/containerd-${containerd_vers}-linux-amd64.tar.gz
sudo tar Cxzvf /usr/local containerd-${containerd_vers}-linux-amd64.tar.gz

cat <<EOF | sudo tee /lib/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target local-fs.target

[Service]
ExecStartPre=-/sbin/modprobe overlay
ExecStart=/usr/local/bin/containerd

Type=notify
Delegate=yes
KillMode=process
Restart=always
RestartSec=5

LimitNPROC=infinity
LimitCORE=infinity

TasksMax=infinity
OOMScoreAdjust=-999

[Install]
WantedBy=multi-user.target
EOF

sudo mkdir /etc/containerd
sudo containerd config default > /etc/containerd/config.toml
sudo sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

curl -L -O https://github.com/opencontainers/runc/releases/download/v${runc_vers}/runc.amd64
sudo install -m 755 runc.amd64 /usr/local/sbin/runc

curl -L -O https://github.com/containernetworking/plugins/releases/download/v${cni_plugins_vers}/cni-plugins-linux-amd64-v${cni_plugins_vers}.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v${cni_plugins_vers}.tgz

sudo systemctl daemon-reload
sudo systemctl start containerd
sudo systemctl enable containerd

[ -d /etc/apt/keyrings ] || sudo mkdir -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${kube_vers}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${kube_vers}/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update -y
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

while ! curl -s ifconfig.me; do
  sleep 2
done

PUBLIC_IP=$(curl -s ifconfig.me)
IPADDR=$(ip a s dev ens5 | awk '/inet /{print $2}' | awk -F / '{print $1}')
NODENAME=$(hostname -s)

sudo kubeadm init \
  --skip-phases=addon/kube-proxy \
  --apiserver-advertise-address=$IPADDR \
  --apiserver-cert-extra-sans=$PUBLIC_IP,$IPADDR \
  --node-name $NODENAME

sudo mkdir /root/.kube
sudo cp /etc/kubernetes/admin.conf /root/.kube/config
mkdir /home/${linux_user}/.kube
sudo install -m 644 -o ${linux_user} -g ${linux_user} /etc/kubernetes/admin.conf /home/${linux_user}/.kube/
mv /home/${linux_user}/.kube/admin.conf /home/${linux_user}/.kube/config

sudo curl -O https://get.helm.sh/helm-v${helm_vers}-linux-amd64.tar.gz
sudo tar zxf helm-v${helm_vers}-linux-amd64.tar.gz
sudo cp linux-amd64/helm /usr/local/bin/

sudo apt-get install -y nfs-common nfs-kernel-server

sudo mkdir /nfs
set +x
sudo grep 'kubeadm join' /var/log/user-data.log > /nfs/kubeadm.sh
sudo grep -- '--discovery-token-ca-cert-hash' /var/log/user-data.log >> /nfs/kubeadm.sh
set -x
sudo chmod 755 /nfs/kubeadm.sh
sudo echo '/nfs 192.168.0.0/16(rw,sync,no_root_squash,no_subtree_check)' >> /etc/exports
sudo exportfs -a
