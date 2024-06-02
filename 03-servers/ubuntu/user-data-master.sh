#!/usr/bin/env bash

set -e -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

cd /root

NUM=`echo $(hostname) | awk -F '-' '{print $4}'`
NODENAME=control-plane-$NUM
hostnamectl set-hostname $NODENAME

apt-get update -y
apt-get upgrade -y
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  etcd-client \
  nfs-common \
  netcat-openbsd \
  open-iscsi \
  vim \
  less \
  bash-completion

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

curl -L -O https://github.com/containerd/containerd/releases/download/v${containerd_vers}/containerd-${containerd_vers}-linux-${archi}.tar.gz
tar Cxzvf /usr/local containerd-${containerd_vers}-linux-${archi}.tar.gz
rm containerd-${containerd_vers}-linux-${archi}.tar.gz

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

curl -L -O https://github.com/opencontainers/runc/releases/download/v${runc_vers}/runc.${archi}
install -m 755 runc.${archi} /usr/local/sbin/runc
rm runc.${archi}

systemctl daemon-reload
systemctl start containerd
systemctl enable containerd

[ -d /etc/apt/keyrings ] || mkdir -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${kube_vers}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${kube_vers}/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

mkdir /nfs

while ! nc -w1 ${efs_dns_name} ${nfs_port}; do
  sleep 5
done

while ! mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ /nfs; do
  sleep 5
done

sleep $((1 + $RANDOM % 10))

if [ ! -f /nfs/first ]; then
  touch /nfs/first
  CONTROL_PLANE='first'
fi

if [[ $CONTROL_PLANE == 'first' ]]; then
  kubeadm init \
    --control-plane-endpoint "${kube_api_internal}:6443" \
    --skip-phases=addon/kube-proxy \
    --apiserver-cert-extra-sans=${kube_api_internet},${kube_api_internal} \
    --upload-certs
else
  while [ ! -f /nfs/master.sh ]; do sleep 5; done
  /nfs/master.sh
fi

mkdir /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config
mkdir /home/${linux_user}/.kube
install -m 644 -o ${linux_user} -g ${linux_user} /etc/kubernetes/admin.conf /home/${linux_user}/.kube/
mv /home/${linux_user}/.kube/admin.conf /home/${linux_user}/.kube/config
echo 'alias k=kubectl' >> /root/.bashrc
echo 'source /usr/share/bash-completion/bash_completion' >> /root/.bashrc
mkdir /etc/bash_completion.d
kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
echo 'complete -o default -F __start_kubectl k' >> /root/.bashrc

if [[ $CONTROL_PLANE == 'first' ]]; then
  install -m 644 /etc/kubernetes/admin.conf /nfs/config

  set +x
  grep 'kubeadm join' /var/log/user-data.log | head -n 1 > /nfs/master.sh
  grep -- '--discovery-token-ca-cert-hash' /var/log/user-data.log | head -n 1 >> /nfs/master.sh
  grep -- '--control-plane --certificate-key' /var/log/user-data.log | head -n 1 >> /nfs/master.sh

  grep 'kubeadm join' /var/log/user-data.log | tail -n 1 > /nfs/worker.sh
  grep -- '--discovery-token-ca-cert-hash' /var/log/user-data.log | tail -n 1 >> /nfs/worker.sh
  set -x
  chmod 755 /nfs/worker.sh
fi

echo 'Done'
