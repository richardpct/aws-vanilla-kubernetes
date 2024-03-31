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
  etcd-client \
  nfs-common

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

curl -L -O https://github.com/containerd/containerd/releases/download/v${containerd_vers}/containerd-${containerd_vers}-linux-${archi}.tar.gz
sudo tar Cxzvf /usr/local containerd-${containerd_vers}-linux-${archi}.tar.gz

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

curl -L -O https://github.com/opencontainers/runc/releases/download/v${runc_vers}/runc.${archi}
sudo install -m 755 runc.${archi} /usr/local/sbin/runc

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

NODENAME=$(hostname -s)

sudo kubeadm init \
  --control-plane-endpoint "${kube_api_internal}:6443" \
  --skip-phases=addon/kube-proxy \
  --apiserver-cert-extra-sans=${kube_api_internet},${kube_api_internal} \
  --node-name $NODENAME \
  --upload-certs

sudo mkdir /root/.kube
sudo cp /etc/kubernetes/admin.conf /root/.kube/config
mkdir /home/${linux_user}/.kube
sudo install -m 644 -o ${linux_user} -g ${linux_user} /etc/kubernetes/admin.conf /home/${linux_user}/.kube/
mv /home/${linux_user}/.kube/admin.conf /home/${linux_user}/.kube/config
echo 'alias k=kubectl' >> /root/.bashrc

sudo curl -O https://get.helm.sh/helm-v${helm_vers}-linux-${archi}.tar.gz
sudo tar zxf helm-v${helm_vers}-linux-${archi}.tar.gz
sudo cp linux-${archi}/helm /usr/local/bin/

sudo mkdir /nfs

while ! nc -w1 ${efs_dns_name} ${nfs_port}; do
  sleep 5
done

while ! sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ /nfs; do
  sleep 5
done

sudo install -m 644 /etc/kubernetes/admin.conf /nfs/config

set +x
sudo grep 'kubeadm join' /var/log/user-data.log | tail -n 1 > /nfs/worker.sh
sudo grep -- '--discovery-token-ca-cert-hash' /var/log/user-data.log | tail -n 1 >> /nfs/worker.sh
set -x
sudo chmod 755 /nfs/worker.sh

echo 'Done'
