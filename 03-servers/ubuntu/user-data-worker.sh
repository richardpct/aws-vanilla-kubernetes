#!/usr/bin/env bash

set -e -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

function install_kubebench() {
  local KUBE_BENCH_VERS=$(curl -s https://github.com/aquasecurity/kube-bench | grep '/releases/tag/v' | grep '/releases/tag/v' | sed -e 's/.*\(.[0-9]*\.[0-9]*\.[0-9]\).*/\1/')

  curl -L -O https://github.com/aquasecurity/kube-bench/releases/download/v$KUBE_BENCH_VERS/kube-bench_$${KUBE_BENCH_VERS}_linux_${archi}.deb
  apt install ./kube-bench_$${KUBE_BENCH_VERS}_linux_${archi}.deb -f
  rm -f ./kube-bench_$${KUBE_BENCH_VERS}_linux_${archi}.deb
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

function configure_system() {
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
}

function install_containerd() {
  local CONTAINERD_VERS=$(curl -s https://github.com/containerd/containerd | grep '/releases/tag/v' | sed -e 's/.*\(.[0-9]*\.[0-9]*\.[0-9]\).*/\1/')

  cd /root

  curl -L -O https://github.com/containerd/containerd/releases/download/v$CONTAINERD_VERS/containerd-$CONTAINERD_VERS-linux-${archi}.tar.gz
  tar Cxzf /usr/local containerd-$CONTAINERD_VERS-linux-${archi}.tar.gz
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

  systemctl daemon-reload
  systemctl start containerd
  systemctl enable containerd
}

function install_runc() {
  local RUNC_VERS=$(curl -s https://github.com/opencontainers/runc | grep '/releases/tag/v' | sed -e 's/.*\(.[0-9]*\.[0-9]*\.[0-9]\).*/\1/')

  cd /root

  curl -L -O https://github.com/opencontainers/runc/releases/download/v$RUNC_VERS/runc.${archi}
  install -m 755 runc.${archi} /usr/local/sbin/runc
  rm runc.${archi}
}

function install_cni() {
  local CNI_PLUGINS_VERS=$(curl -s https://github.com/containernetworking/plugins | grep '/releases/tag/v' | sed -e 's/.*\(.[0-9]*\.[0-9]*\.[0-9]\).*/\1/')

  cd /root

  curl -L -O https://github.com/containernetworking/plugins/releases/download/v$CNI_PLUGINS_VERS/cni-plugins-linux-${archi}-v$CNI_PLUGINS_VERS.tgz
  mkdir -p /opt/cni/bin
  tar Cxzf /opt/cni/bin cni-plugins-linux-${archi}-v$CNI_PLUGINS_VERS.tgz
  rm cni-plugins-linux-${archi}-v$CNI_PLUGINS_VERS.tgz
}

function install_kube_tools() {
  local KUBE_VERS=$(curl -s https://github.com/kubernetes/kubernetes | grep '/releases/tag/v' | sed -e 's/.*\(.[0-9]*\.[0-9]*\)\..*/\1/')

  [ -d /etc/apt/keyrings ] || mkdir -m 755 /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBE_VERS/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBE_VERS/deb/ /" | tee /etc/apt/sources.list.d/kubernetes.list

  apt-get update
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
}

function configure_disk() {
  if ! ${use_rook}; then
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
  fi
}

function join_node() {
  mkdir /nfs

  while ! nc -w1 ${efs_dns_name} ${nfs_port}; do
    sleep 30
  done

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
}

configure_system
install_containerd
install_runc
install_cni
install_kube_tools
configure_disk
join_node
install_kubebench
#install_falco

echo 'Done'
