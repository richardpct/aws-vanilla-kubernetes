#!/usr/bin/env bash

set -e -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

cd /root

NUM=`echo $(hostname) | awk -F '-' '{print $4}'`
NODENAME=worker-$NUM
hostnamectl set-hostname $NODENAME

setenforce 0
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config

dnf install -y nfsv4-client-utils

cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

CONTAINERD_VERS=$(curl -s https://github.com/containerd/containerd | grep '/releases/tag/v' | sed -e 's/.*\(.[0-9]*\.[0-9]*\.[0-9]\).*/\1/')
curl -L -O https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERS/containerd-$CONTAINERD_VERS-linux-${archi}.tar.gz
tar Cxzvf /usr/local containerd-$CONTAINERD_VERS-linux-${archi}.tar.gz
rm containerd-$CONTAINERD_VERS-linux-${archi}.tar.gz

cat <<EOF | tee /lib/systemd/system/containerd.service
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

mkdir /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

RUNC_VERS=$(curl -s https://github.com/opencontainers/runc | grep '/releases/tag/v' | sed -e 's/.*\(.[0-9]*\.[0-9]*\.[0-9]\).*/\1/')
curl -L -O https://github.com/opencontainers/runc/releases/download/v$RUNC_VERS/runc.${archi}
install -m 755 runc.${archi} /usr/local/sbin/runc
rm runc.${archi}

systemctl daemon-reload
systemctl start containerd
systemctl enable containerd

KUBE_VERS=$(curl -s https://github.com/kubernetes/kubernetes | grep '/releases/tag/v' | sed -e 's/.*\(.[0-9]*\.[0-9]*\)\..*/\1/')

cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v$KUBE_VERS/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v$KUBE_VERS/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

dnf update
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
systemctl enable kubelet

mkdir /nfs

while ! mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ /nfs; do
  sleep 10
done

while [ ! -f /nfs/worker.sh ]; do
  sleep 10
done

while ! /nfs/worker.sh; do
  sleep 10
done

umount /nfs

echo 'Done'

#shutdown -r now
