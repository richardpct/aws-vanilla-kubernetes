#!/usr/bin/env bash

set -e -x

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

function encrypt_etcd() {
  local encrypt_key=$(head -c 32 /dev/urandom | base64)
  mkdir -p /etc/kubernetes/enc

  cat > /etc/kubernetes/enc/enc.yaml <<EOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: $encrypt_key
      - identity: {}
EOF

  sed -i '/- --advertise-address/ i \ \ \ \ - --encryption-provider-config=/etc/kubernetes/enc/enc.yaml' /etc/kubernetes/manifests/kube-apiserver.yaml
  sed -i '/hostNetwork: true/ i \ \ \ \ - name: enc\n      mountPath: /etc/kubernetes/enc\n      readOnly: true' /etc/kubernetes/manifests/kube-apiserver.yaml
  sed -i '/status: {}/ i \ \ - name: enc\n    hostPath:\n      path: /etc/kubernetes/enc\n      type: DirectoryOrCreate' /etc/kubernetes/manifests/kube-apiserver.yaml
}

function audit() {
  mkdir -p /etc/kubernetes/audit
  mkdir -p /var/log/audit

  cat > /etc/kubernetes/audit/audit-policy.yaml <<EOF
apiVersion: audit.k8s.io/v1
kind: Policy
rules:
- level: Metadata
EOF

  sed -i '/- --advertise-address/ i \ \ \ \ - --audit-policy-file=/etc/kubernetes/audit/audit-policy.yaml\n    - --audit-log-path=/var/log/audit/audit.log\n    - --audit-log-maxage=30\n    - --audit-log-maxbackup=10\n    - --audit-log-maxsize=100' /etc/kubernetes/manifests/kube-apiserver.yaml
  sed -i '/hostNetwork: true/ i \ \ \ \ - mountPath: /etc/kubernetes/audit/audit-policy.yaml\n      name: audit\n      readOnly: true\n    - mountPath: /var/log/audit/\n      name: audit-log\n      readOnly: false' /etc/kubernetes/manifests/kube-apiserver.yaml
  sed -i '/status: {}/ i \ \ - name: audit\n    hostPath:\n      path: /etc/kubernetes/audit/audit-policy.yaml\n      type: File\n  - name: audit-log\n    hostPath:\n      path: /var/log/audit/\n      type: DirectoryOrCreate' /etc/kubernetes/manifests/kube-apiserver.yaml
}

function install_kubebench() {
  local KUBE_BENCH_VERS=$(curl -s https://github.com/aquasecurity/kube-bench | grep '/releases/tag/v' | grep '/releases/tag/v' | sed -e 's/.*\(.[0-9]*\.[0-9]*\.[0-9]\).*/\1/')

  curl -L -O https://github.com/aquasecurity/kube-bench/releases/download/v$KUBE_BENCH_VERS/kube-bench_$${KUBE_BENCH_VERS}_linux_${archi}.deb
  apt install ./kube-bench_$${KUBE_BENCH_VERS}_linux_${archi}.deb -f
  rm -f ./kube-bench_$${KUBE_BENCH_VERS}_linux_${archi}.deb
}

function enforce_security() {
  sed -i '/- --advertise-address/ i \ \ \ \ - --profiling=false' /etc/kubernetes/manifests/kube-apiserver.yaml
  sed -i '/image:/ i \ \ \ \ - --profiling=false' /etc/kubernetes/manifests/kube-controller-manager.yaml
  sed -i '/image:/ i \ \ \ \ - --profiling=false' /etc/kubernetes/manifests/kube-scheduler.yaml
  chmod 600 /lib/systemd/system/kubelet.service
  chmod 600 /var/lib/kubelet/config.yaml
}

function configure_system() {
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
    bash-completion \
    bsdmainutils

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

  apt-get update -y
  apt-get install -y kubelet kubeadm kubectl
  apt-mark hold kubelet kubeadm kubectl
}

function create_cluster() {
  mkdir /nfs

  while ! nc -w1 ${efs_dns_name} ${nfs_port}; do
    sleep 5
  done

  while ! mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ /nfs; do
    sleep 5
  done

  if [ ! -f /nfs/first ]; then
    touch /nfs/first
    CONTROL_PLANE='first'
  fi

  if [[ $CONTROL_PLANE == 'first' ]]; then
    if ${use_cilium}; then
      kubeadm init \
      --control-plane-endpoint "${kube_api_internal}:6443" \
      --skip-phases=addon/kube-proxy \
      --apiserver-cert-extra-sans=${kube_api_internet},${kube_api_internal} \
      --upload-certs
    else
    kubeadm init \
      --control-plane-endpoint "${kube_api_internal}:6443" \
      --apiserver-cert-extra-sans=${kube_api_internet},${kube_api_internal} \
      --pod-network-cidr=10.0.0.0/16 \
      --upload-certs
    fi

    install -m 644 /etc/kubernetes/admin.conf /nfs/config

    set +x
    grep 'kubeadm join' /var/log/user-data.log | head -n 1 > /nfs/master.sh
    grep -- '--discovery-token-ca-cert-hash' /var/log/user-data.log | head -n 1 >> /nfs/master.sh
    grep -- '--control-plane --certificate-key' /var/log/user-data.log | head -n 1 >> /nfs/master.sh

    grep 'kubeadm join' /var/log/user-data.log | tail -n 1 > /nfs/worker.sh
    grep -- '--discovery-token-ca-cert-hash' /var/log/user-data.log | tail -n 1 >> /nfs/worker.sh
    set -x
    chmod 755 /nfs/worker.sh
  else
    while [ ! -f /nfs/master.sh ]; do sleep 10; done
    /nfs/master.sh
  fi
}

function configure_kube_env() {
  mkdir /root/.kube
  cp /etc/kubernetes/admin.conf /root/.kube/config
  mkdir /home/${linux_user}/.kube
  install -m 600 /etc/kubernetes/admin.conf /home/${linux_user}/.kube/config
  chown -R ubuntu:ubuntu /home/${linux_user}/.kube
  echo 'alias k=kubectl' >> /root/.bash_aliases
  echo 'alias k=kubectl' >> /home/${linux_user}/.bash_aliases
  chown ubuntu:ubuntu /home/${linux_user}/.bash_aliases
  echo 'source /usr/share/bash-completion/bash_completion' >> /root/.bashrc
  [ -d /etc/bash_completion.d ] || mkdir /etc/bash_completion.d
  kubectl completion bash | tee /etc/bash_completion.d/kubectl > /dev/null
  echo 'complete -o default -F __start_kubectl k' >> /root/.bashrc
}

configure_system
install_containerd
install_runc
install_cni
install_kube_tools
create_cluster
configure_kube_env
#encrypt_etcd
audit
install_kubebench
enforce_security

echo 'Done'
