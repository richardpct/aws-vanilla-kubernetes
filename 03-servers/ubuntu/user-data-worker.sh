#!/usr/bin/env bash

set -e -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

function install_kubebench() {
  curl -L -O https://github.com/aquasecurity/kube-bench/releases/download/v${kube_bench_vers}/kube-bench_${kube_bench_vers}_linux_${archi}.deb
  apt install ./kube-bench_${kube_bench_vers}_linux_${archi}.deb -f
  rm -f ./kube-bench_${kube_bench_vers}_linux_${archi}.deb
}

function install_falco() {
  curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | \
    gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | \
    tee -a /etc/apt/sources.list.d/falcosecurity.list
  apt-get update -y
  apt-get install -y falco

  cat > /etc/falco/falco_rules.local.yaml <<EOF
- list: suspect_binaries
  items: [mv, rm, chmod, chown, unlink, ln, touch]

- macro: suspect_procs
  condition: (proc.name in (suspect_binaries))

- rule: suspects commands
  desc: >
    Some commands can be considered suspects
  condition: >
    spawned_process
    and container
    and suspect_procs
    and proc.tty != 0
  output: A suspect command was performed (evt_type=%evt.type user=%user.name user_uid=%user.uid user_loginuid=%user.loginuid process=%proc.name proc_exepath=%proc.exepath command=%proc.cmdline %container.info)
  priority: NOTICE
EOF

  systemctl restart falco-modern-bpf
}

cd /root

NUM=`echo $(hostname) | awk -F '-' '{print $4}'`
NODENAME=worker-$NUM
hostnamectl set-hostname $NODENAME

apt-get update
apt-get upgrade -y
apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg \
  ncat \
  nvme-cli \
  nfs-common \
  netcat-openbsd \
  open-iscsi \
  vim \
  less

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

curl -L -O https://github.com/containernetworking/plugins/releases/download/v${cni_plugins_vers}/cni-plugins-linux-${archi}-v${cni_plugins_vers}.tgz
sudo mkdir -p /opt/cni/bin
sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-${archi}-v${cni_plugins_vers}.tgz

systemctl daemon-reload
systemctl start containerd
systemctl enable containerd

[ -d /etc/apt/keyrings ] || mkdir -m 755 /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v${kube_vers}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${kube_vers}/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list

apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

mkdir /var/lib/longhorn
longhorn_disk=''

for disk in $(nvme list | awk '/nvme/{print $1}'); do
  if ! blkid $disk > /dev/null 2>&1; then
    longhorn_disk=$disk
    break
  fi
done

if [ $longhorn_disk == '' ]; then
  echo 'No additional disk found'
  exit 1
fi

mkfs.ext4 $longhorn_disk
tune2fs -L "longhorn" $longhorn_disk
echo 'LABEL=longhorn    /var/lib/longhorn    ext4    defaults    0 0' >> /etc/fstab
mount /var/lib/longhorn

mkdir /nfs

while ! nc -w1 ${efs_dns_name} ${nfs_port}; do
  sleep 10
done

while ! mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ /nfs; do
  sleep 10
done

while [ ! -f /nfs/worker.sh ]; do
  sleep 10
done

/nfs/worker.sh
umount /nfs

install_kubebench
#install_falco

echo 'Done'
