#!/bin/bash

set -e -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  ncat \
  nvme-cli

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

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo mkdir /var/lib/longhorn
longhorn_disk=''

for disk in $(nvme list | awk '/nvme/{print $1}'); do
  if ! sudo blkid $disk > /dev/null 2>&1; then
    longhorn_disk=$disk
    break
  fi
done

if [ $longhorn_disk == '' ]; then
  echo 'No additional disk found'
  exit 1
fi

sudo mkfs.ext4 $longhorn_disk
sudo tune2fs -L "longhorn" $longhorn_disk
sudo echo 'LABEL=longhorn    /var/lib/longhorn    ext4    defaults    0 0' >> /etc/fstab
sudo mount /var/lib/longhorn

sudo apt-get install -y nfs-common

while ! nc -w1 ${kubernetes_master_ip} ${nfs_port}; do
  sleep 5
done

while ! sudo mount -t nfs ${kubernetes_master_ip}:/nfs /mnt; do
  sleep 5
done

sudo /mnt/kubeadm.sh
sudo umount /mnt
