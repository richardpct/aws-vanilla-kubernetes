#!/usr/bin/env bash

set -x -e

function install_packages() {
  apt-get update -y
  apt-get upgrade -y
  apt-get install -y \
    nfs-common \
    netcat-openbsd \
    unzip
}

function install_awscli() {
  if [ ${archi} == 'arm64' ]; then
    ARCH='aarch64'
  else
    ARCH='x86_64'
  fi

  cd /root
  curl "https://awscli.amazonaws.com/awscli-exe-linux-$ARCH.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  ./aws/install
  rm awscliv2.zip
  rm -r aws
}

function associate_eip() {
  TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
  INSTANCE_ID="$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)"
  aws --region ${region} ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${eip_bastion_id}
}

function mount_nfs() {
  mkdir /nfs

  while ! mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ /nfs; do
    sleep 10
  done
}

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
install_packages
install_awscli
associate_eip
mount_nfs
echo "Done"
