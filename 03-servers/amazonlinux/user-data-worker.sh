#!/usr/bin/env bash

set -e -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

NUM=`echo $(hostname) | awk -F '-' '{print $4}'`
NODENAME=worker-$NUM
hostnamectl set-hostname $NODENAME

sudo setenforce 0
sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

sudo dnf install -y \
  nfsv4-client-utils \
  nvme-cli \
  iscsi-initiator-utils

#sudo dnf install -y \
#  apt-transport-https \
#  ca-certificates \
#  curl \
#  gnupg \
#  ncat \
#  nvme-cli \
#  nfs-common

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
rm containerd-${containerd_vers}-linux-${archi}.tar.gz

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
rm runc.${archi}

sudo systemctl daemon-reload
sudo systemctl start containerd
sudo systemctl enable containerd

cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${kube_vers}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${kube_vers}/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

sudo dnf update
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
sudo systemctl enable kubelet

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

sudo mkdir /nfs

while ! sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ /nfs; do
  sleep 10
done

while [ ! -f /nfs/worker.sh ]; do
  sleep 10
done

sudo /nfs/worker.sh
touch /nfs/$NODENAME
sudo umount /nfs

echo 'Done'

sudo shutdown -r now
