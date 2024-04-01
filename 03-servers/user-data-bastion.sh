#!/usr/bin/env bash

set -x -e

sudo dnf install -y nfsv4-client-utils nmap-ncat

exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
TOKEN=`curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600"`
INSTANCE_ID="$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -s http://169.254.169.254/latest/meta-data/instance-id)"
aws --region ${region} ec2 associate-address --instance-id $INSTANCE_ID --allocation-id ${eip_bastion_id}

sudo mkdir /nfs

while ! sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${efs_dns_name}:/ /nfs; do
  sleep 10
done

echo "DONE"
