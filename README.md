# Purpose

This tutorial will show you how to build an infrastructure for building a
kubernetes cluster using kubeadm. It intends to show you how to build a more
complex architecture on AWS than the previous tutorials, but don't use this one
on production environment, instead prefer using EKS.

# Requirements

The requirements are the same as the previous tutorials, but you will in
addition need to have a domain name, you can go to route53 in your AWS account
and register one, it is the easiest way to proceed.
Also install the kubectl command and the cilium package, if you are on MacOS
perform the following command:

    $ brew install kubernetes-cli cilium

# Architecture

The purpose is to build a vanilla kubernetes using kubeadm in high availability,
using rook ceph as storage system, using cilium as cni, using gateway api for
exposing the services.

We will deploy 3 applications on our kubernetes cluster:

  * ArgoCD: for deploying some applications in the GitOps way
  * Metrics servers: deployed by ArgoCD for having some basics metrics on our
kubernetes cluster
  * Simple website: a simple website for testing rook ceph

Infrastructure:

  * 1 bastion: it is the only server that allows you to connect to all the servers
through ssh
  * 3 control planes (also named master in my OpenTofu source code)
  * 3 worker nodes
  * efs: I use it as a shared files system, when the first control plane is
initialized, it will generate and store the set of commands for the other control planes
and the worker nodes for joining the cluster, it also store the kube config that
we later get for talking with the kubernetes api server using kubectl.

The main difference compared to the previous tutorials, you will use
the spot instances instead of regular ec2 instances because we want to save
money, as you can imagine, spinning up 7 servers can be quite expensive.

We will request a wildcard certificate to Let's Encrypt for hosting our
applications in https. We will also need to create some DNS entry by using route53.

# Requesting a wildcard certificate for our domain

We make a challenge dns to Let's Encrypt for getting the certificates:

modules/certificate/main.tf
```
resource "tls_private_key" "private_key" {
  algorithm = "RSA"
}

resource "acme_registration" "reg" {
  account_key_pem = tls_private_key.private_key.private_key_pem
  email_address   = var.my_email
}

resource "acme_certificate" "wildcard" {
  account_key_pem = acme_registration.reg.account_key_pem
  common_name     = "*.${var.my_domain}"

  recursive_nameservers        = ["8.8.8.8:53"]
  disable_complete_propagation = true

  dns_challenge {
    provider = "route53"
  }
}
```

# Network and DNS

## Subnets

I splitted the subnets in 3:

  * private subnet: it hosts the 3 control planes, the 3 worker nodes and the
internal load balancer for reaching the kube api from the kubernetes cluster.
Its default route points to the Nat Gateway because these servers needs to reach
Internet.
  * private subnet efs: it hosts only efs, because this subnet does not need
to reach Internet
  * public subnet: it hosts the Nat Gateway, the bastion and the internet facing
Load Balancer

cluster-01/02-network/main.tf
```
module "network" {
  source             = "../../modules/network"
  aws_profile        = var.aws_profile
  region             = var.region
  env                = "cluster-01"
  my_domain          = var.my_domain
  my_ip_address      = var.my_ip_address
  vpc_cidr_block     = "10.0.0.0/16"
  subnet_private     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  subnet_private_efs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  subnet_public      = ["10.0.7.0/24", "10.0.8.0/24", "10.0.9.0/24"]
  record_dns         = ["argocd", "www2"]
}
```

## DNS

We also define 2 DNS entries pointing to the internet facing load balancer:

  * argocd.<your_domain>: the argocd
  * www2.<your_domain>: A simple website for testing rook ceph

modules/network/dns.tf
```
data "aws_route53_zone" "main" {
  name = var.my_domain
}

resource "aws_route53_record" "bastion" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "bastion"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.bastion.public_ip]
}

resource "aws_route53_record" "name" {
  count   = length(var.record_dns)
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.record_dns[count.index]
  type    = "CNAME"
  ttl     = 5

  weighted_routing_policy {
    weight = 10
  }

  set_identifier = var.record_dns[count.index]
  records        = [aws_lb.external.dns_name]
}
```

## Load balancers

There are 2 Load Balancers:

  * Internet facing load balancer (also named external loadbalancer): it forwards
the API requests from Internet to the control planes and it forwards the HTTPS
requests from Internet to the worker nodes.
  * Internal load balancer: It forwards the API requests from the kubernetes
cluster to the control planes

# Servers and EFS

## Servers

Compared to the previous tutorials, we will use spot instances for building the EC2 
instances, we set the maximum price that we want to pay according the instance type:

modules/servers/variables.tf
```
locals {
  ...
  instance_type_bastion = local.archi == "arm64" ? "t4g.nano" : "t3.nano"
  bastion_price         = local.archi == "arm64" ? "0.0025" : "0.001"
  instance_type_master  = local.archi == "arm64" ? "t4g.small" : "t3.small"
  master_price          = local.archi == "arm64" ? "0.010" : "0.010"
  instance_type_worker  = local.archi == "arm64" ? "t4g.medium" : "t3.medium"
  worker_price          = local.archi == "arm64" ? "0.025" : "0.020"
  ...
}
```

Then here is how we declare the EC2 as spot instance (for example the control plane):

modules/servers/main.tf
```
resource "aws_launch_template" "kubernetes_master" {
  name      = "kubernetes_master"
  image_id  = data.aws_ami.linux.id
  user_data = base64encode(templatefile("${path.module}/${local.distribution}/user-data-master.sh",
                                        { linux_user        = local.linux_user,
                                          archi             = local.archi,
                                          efs_dns_name      = aws_efs_file_system.efs.dns_name,
                                          kube_api_external = data.terraform_remote_state.network.outputs.aws_lb_external_dns_name,
                                          kube_api_internal = data.terraform_remote_state.network.outputs.aws_lb_internal_dns_name }))
  instance_type = local.instance_type_master
  key_name      = aws_key_pair.my_key.key_name

  block_device_mappings {
    device_name = data.aws_ami.linux.root_device_name

    ebs {
      volume_size           = var.root_size_master
      volume_type           = "gp2"
      delete_on_termination = true
    }
  }

  network_interfaces {
    security_groups = [data.terraform_remote_state.network.outputs.aws_security_group_kubernetes_master_id]
  }

  instance_market_options {
    market_type = "spot"

    spot_options {
      max_price = local.master_price
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

## EFS

Building the EFS is quite straightforward:

modules/servers/efs.tf
```
resource "aws_efs_file_system" "efs" {
  tags = {
    Name = "efs"
  }
}

resource "aws_efs_mount_target" "mount_target" {
  count           = length(data.terraform_remote_state.network.outputs.subnet_private_efs)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = data.terraform_remote_state.network.outputs.subnet_private_efs[count.index]
  security_groups = [data.terraform_remote_state.network.outputs.aws_security_group_efs_id]
}
```

## Kubeadm

The setup of kubeadm are located in 2 scripts, both are executed when the
EC2 instances are initialized at the first boot:

  * The control planes execute at boot modules/servers/amazonlinux/user-data-master.sh
  * The worker nodes execute at boot modules/servers/amazonlinux/user-data-worker.sh

### The primary control plane

The control plane that boot the fastest will launch this script first, we can
call this server the `primary control plane`, it will create a file on the EFS
mounted at /nfs/first for letting know to the 2 remaining control planes that
a primary control plane is already setting up using the `kubeadm init` command.
When the primary control plane has completely configured, it will provide
2 scripts at /nfs/master.sh and /nfs/worker.sh containing the full `kubeadm join`
command for being used by the secondary control planes and all the worker nodes.

### The secondaries control plane

When a control plane boots and finds a file at /nfs/first, it knows a primary control
plane is already setting up with the `kubeadm init` command, it will wait until the
primary control plane will copy the full script containing the `kubeadm join`
at /nfs/master.sh. When this script is present, it will execute this script to
be added to the kubernetes cluster.

### The worker nodes

The worker nodes wait until the primary control plane provide the /nfs/worker.sh
script containing the full `kubeadm join` command. When this script is present,
it will execute this script to be added to the kubernetes cluster.

# Kubernetes post configuration

## Cilium

Cilium is a modern CNI, I disable the kube-proxy because I want a full ebpf
CNI without any IPtables/NFtables rules.

We install Cilium by using the helm chart, we also enable Hubble:

modules/kubernetes/main.tf
```
resource "helm_release" "cilium" {
  name         = "cilium"
  repository   = "https://helm.cilium.io/"
  chart        = "cilium"
  namespace    = "kube-system"
  force_update = true

  values = [
    "${file("${path.module}/helm-values/cilium.yaml")}"
  ]

  set = [
    {
      name  = "k8sServiceHost"
      value = data.terraform_remote_state.network.outputs.aws_lb_internal_dns_name
    }
  ]

  depends_on = [kubectl_manifest.gateway]
}
```

modules/kubernetes/helm-values/cilium.yaml
```
---
kubeProxyReplacement: true
gatewayAPI:
  enabled: true
  hostNetwork:
    enabled: true
k8sServicePort: 6443
hubble:
  enabled: true
  metrics:
    enabled:
    - dns
    - drop
    - tcp
    - flow
    - port-distribution
    - httpV2
  relay:
    enabled: true
  ui:
    enabled: true
encryption:
  enabled: true
  type: wireguard
prometheus:
  enabled: true
operator:
  prometheus:
    enabled: true
ipam:
  operator:
    clusterPoolIPv4PodCIDRList: ["10.42.0.0/16"]
```

You can notice we setup the gateway API in hostnetwork mode

## Rook Ceph

We install Rook Ceph by using the helm chart, there are 2 components to install:
the operator and the rook-ceph-cluster.

We firstly download the default values from the github repository, then we
remove all request resources cpu and memory, because by default they are to high
for our small cluster:

modules/servers/main.tf
```
resource "null_resource" "get_rook_ceph_operator_values" {
  provisioner "local-exec" {
    command = <<EOF
curl -s -o /tmp/rook-ceph-operator-values.yaml https://raw.githubusercontent.com/rook/rook/refs/tags/v${var.rook_version}/deploy/charts/rook-ceph/values.yaml
sed -i -e 's/cpu:.*/cpu:/' /tmp/rook-ceph-operator-values.yaml
sed -i -e 's/memory:.*/memory:/' /tmp/rook-ceph-operator-values.yaml
    EOF
  }
}

resource "null_resource" "get_rook_ceph_cluster_values" {
  provisioner "local-exec" {
    command = <<EOF
curl -s -o /tmp/rook-ceph-cluster-values.yaml https://raw.githubusercontent.com/rook/rook/refs/tags/v${var.rook_version}/deploy/charts/rook-ceph-cluster/values.yaml
sed -i -e 's/cpu:.*/cpu:/' /tmp/rook-ceph-cluster-values.yaml
sed -i -e 's/memory:.*/memory:/' /tmp/rook-ceph-cluster-values.yaml
    EOF
  }
}
```

Then we apply the helm chart

modules/kubernetes/main.tf
```
resource "helm_release" "rook-ceph-operator" {
  name             = "rook-ceph"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph"
  version          = data.terraform_remote_state.servers.outputs.rook_version
  namespace        = "rook-ceph"
  create_namespace = true
  force_update     = true

  values = [
    "${file("/tmp/rook-ceph-operator-values.yaml")}"
  ]

  depends_on = [helm_release.cilium]
}

resource "helm_release" "rook-ceph-cluster" {
  name             = "rook-ceph-cluster"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph-cluster"
  version          = data.terraform_remote_state.servers.outputs.rook_version
  namespace        = "rook-ceph"
  create_namespace = true
  force_update     = true

  values = [
    "${file("/tmp/rook-ceph-cluster-values.yaml")}"
  ]

  set = [
    {
      name  = "toolbox.enabled"
      value = "true"
    }
  ]

  depends_on = [helm_release.rook-ceph-operator]
}
```

## Gateway API

We install Gateway API for exposing the services, instead of using an
Ingress controller.
Firstly we have to install the CRDs, then we install Gateway API using a kubernetes
manifest.

modules/kubernetes/main.tf
```
resource "null_resource" "install-gateway-crds" {
  provisioner "local-exec" {
    command = <<EOF
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_gatewayclasses.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_gateways.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_httproutes.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_referencegrants.yaml
      kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/v${var.gateway_api_version}/config/crd/standard/gateway.networking.k8s.io_grpcroutes.yaml
    EOF
  }

  depends_on = [kubernetes_secret_v1.default_tls_cert]
}

resource "kubectl_manifest" "gateway" {
  yaml_body = templatefile("${path.module}/manifests/gateway.yaml.tftpl",
    {
      gateway_port = local.gateway_port
    }
  )

  depends_on = [null_resource.install-gateway-crds]
}
```

We set the Gateway API by listening the requests on port 30443 on all worker
nodes, then the external load balancer forwards the HTTPS requests on it.
The wildcard certificate is also associated with it.

modules/kubernetes/manifests/gateway.yaml.tftpl
```
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: tls-gateway
  namespace: kube-system
spec:
  gatewayClassName: cilium
  listeners:
  - name: https
    protocol: HTTPS
    port: ${gateway_port}
    allowedRoutes:
      namespaces:
        from: All
    tls:
      certificateRefs:
      - kind: Secret
        name: default-tls-cert
```

## ArgoCD

We deploy argocd and argocd apps by using the Helm chart:

modules/kubernetes/main.tf
```
resource "helm_release" "argo_cd" {
  name             = "argo-cd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    "${file("${path.module}/helm-values/argocd.yaml")}"
  ]

  set = [
    {
      name  = "global.domain"
      value = "argocd.${var.my_domain}"
    },
    {
      name  = "server.httproute.hostnames[0]"
      value = "argocd.${var.my_domain}"
    }
  ]

  depends_on = [helm_release.rook-ceph-cluster]
}

resource "helm_release" "argocd_apps" {
  name             = "argocd-apps"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argocd-apps"
  namespace        = "argocd"
  create_namespace = true
  force_update     = true

  values = [
    "${file("${path.module}/helm-values/argocd-apps.yaml")}"
  ]

  depends_on = [helm_release.argo_cd]
}
```

modules/kubernetes/helm-values/argocd.yaml
```
configs:
  params:
    server.insecure: true

repoServer:
  name: repo-server
  replicas: 2
  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 3
    targetCPUUtilizationPercentage: 50
    targetMemoryUtilizationPercentage: 50

server:
  replicas: 2
  ingress:
    enabled: false
  httproute:
    enabled: true
    parentRefs:
      - name: tls-gateway
        namespace: kube-system
        sectionName: https
    rules:
      - matches:
          - path:
              type: PathPrefix
              value: /
```

In the Argo CD application, we declare how to deploy the metrics-server:

kubernetes/helm-values/argocd-apps.yaml
```
applications:
  metrics-server:
    namespace: argocd
    finalizers:
    - resources-finalizer.argocd.argoproj.io
    project: default
    source:
      repoURL: https://kubernetes-sigs.github.io/metrics-server
      chart: metrics-server
      targetRevision: 3.13.0
      helm:
        values: |
          args:
            - '--kubelet-insecure-tls=true'
          replicas: 2
    destination:
      server: https://kubernetes.default.svc
      namespace: metrics
    syncPolicy:
      automated:
        prune: false
        selfHeal: false
      syncOptions:
      - CreateNamespace=true
    revisionHistoryLimit: null
```

# Building the Infrastructure

## Creating

Prepare a file at ~/terraform/kubernetes-vanilla/terraform_vars_cluster-01_secrets:

```
export TF_VAR_aws_profile="dev"
export TF_VAR_region="eu-north-1"
export TF_VAR_bucket="XXXX-tofu-state-kubeadm-${TF_VAR_region}"
export TF_VAR_key_certificate="kubeadm/cluster-01/certificate/tofu.tfstate"
export TF_VAR_key_network="kubeadm/cluster-01/network/tofu.tfstate"
export TF_VAR_key_servers="kubeadm/cluster-01/servers/tofu.tfstate"
export TF_VAR_key_kubernetes="kubeadm/cluster-01/kubernetes/tofu.tfstate"
export TF_VAR_key_monitoring="kubeadm/cluster-01/monitoring/tofu.tfstate"
export TF_VAR_key_vault="kubeadm/cluster-01/vault/tofu.tfstate"
export TF_VAR_ssh_public_key="ssh-ed25519 XXXX"
export TF_VAR_my_domain="your_domain"
export TF_VAR_my_email="your_mail"
MY_IP=$(curl -s ifconfig.co/)
export TF_VAR_my_ip_address="$MY_IP/32"
```

    $ cd cluster-01/00-bucket
    $ make apply
    $ cd ../01-certificate
    $ make apply
    $ cd ../02-network
    $ make apply
    $ cd ../03-servers
    $ make apply

Check the logs, and wait until all your 6 instances display 'Done':

    $ ssh -J ec2-user@bastion.<your_domain> ec2-user@<your_instance_ip> tail -f /var/log/user-data.log

The OpenTofu code copies the kube config at ~/.kube/config-aws on your local
machine, set the KUBECONFIG variable:

    $ export KUBECONFIG=~/.kube/config-aws

You can check if you can communicate with the kubernetes API:

    $ kubectl cluster-info

Wait until all nodes are ready:

    $ kubectl get no

should return:
```
NAME              STATUS     ROLES           AGE     VERSION
control-plane-1   NotReady   control-plane   6m26s   v1.36.0
control-plane-2   NotReady   control-plane   6m22s   v1.36.0
control-plane-3   NotReady   control-plane   7m7s    v1.36.0
worker-1          NotReady   <none>          6m50s   v1.36.0
worker-2          NotReady   <none>          6m50s   v1.36.0
worker-3          NotReady   <none>          6m51s   v1.36.0
```

Wait until all pods are running except the coredns pods, because they need a CNI
that we will install later:

    $ kubectl get po -A

Should return:
```
NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
kube-system   coredns-589f44dc88-hhf7x                  0/1     Pending   0          7m52s
kube-system   coredns-589f44dc88-svrst                  0/1     Pending   0          7m52s
kube-system   etcd-control-plane-1                      1/1     Running   0          7m17s
kube-system   etcd-control-plane-2                      1/1     Running   0          7m13s
kube-system   etcd-control-plane-3                      1/1     Running   0          7m57s
kube-system   kube-apiserver-control-plane-1            1/1     Running   0          7m17s
kube-system   kube-apiserver-control-plane-2            1/1     Running   0          7m13s
kube-system   kube-apiserver-control-plane-3            1/1     Running   0          7m58s
kube-system   kube-controller-manager-control-plane-1   1/1     Running   0          7m17s
kube-system   kube-controller-manager-control-plane-2   1/1     Running   0          7m13s
kube-system   kube-controller-manager-control-plane-3   1/1     Running   0          7m57s
kube-system   kube-scheduler-control-plane-1            1/1     Running   0          7m17s
kube-system   kube-scheduler-control-plane-2            1/1     Running   0          7m13s
kube-system   kube-scheduler-control-plane-3            1/1     Running   0          7m57s
```

When the pods are in running state, you can continue:

    $ cd ../04-kubernetes
    $ make apply

## Testing ArgoCD

Get the default argo cd password located in the `password:` field:

    $ kubectl -n argocd get secrets argocd-initial-admin-secret -o yaml

Decode the password in base64:

    $ echo <password> | base64 -d

Point your browser to https://argocd.<your_domain>, the user is `admin`, as you
can see you have one application deployed, you also check it using kubectl:

    $ kubectl -n argocd get applications

should return:
```
NAME             SYNC STATUS   HEALTH STATUS
metrics-server   Synced        Healthy
```

## Testing the metrics server

Check if the metrics server work:

    $ kubectl top no

should return:
```
NAME              CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
control-plane-1   133m         6%       1297Mi          71%
control-plane-2   168m         8%       1384Mi          76%
control-plane-3   188m         9%       1366Mi          75%
worker-1          241m         12%      1901Mi          50%
worker-2          268m         13%      2274Mi          60%
worker-3          248m         12%      1612Mi          43%
```

### Testing Cilium

Check the status:

    $ cilium status

should return:
```
    /¯¯\
 /¯¯\__/¯¯\    Cilium:             OK
 \__/¯¯\__/    Operator:           OK
 /¯¯\__/¯¯\    Envoy DaemonSet:    OK
 \__/¯¯\__/    Hubble Relay:       OK
    \__/       ClusterMesh:        disabled

DaemonSet              cilium                   Desired: 6, Ready: 6/6, Available: 6/6
DaemonSet              cilium-envoy             Desired: 6, Ready: 6/6, Available: 6/6
Deployment             cilium-operator          Desired: 2, Ready: 2/2, Available: 2/2
Deployment             hubble-relay             Desired: 1, Ready: 1/1, Available: 1/1
Deployment             hubble-ui                Desired: 1, Ready: 1/1, Available: 1/1
Containers:            cilium                   Running: 6
                       cilium-envoy             Running: 6
                       cilium-operator          Running: 2
                       clustermesh-apiserver
                       hubble-relay             Running: 1
                       hubble-ui                Running: 1
```

Launch the cilium network test:

    $ cilium connectivity test

Test Hubble:

    $ cilium hubble ui

It will open automatically a page on your browser

### Testing Rook Ceph

Check if the storage class are created:

    $ kubectl get sc

should return:
```
NAME                   PROVISIONER                     RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
ceph-block (default)   rook-ceph.rbd.csi.ceph.com      Delete          Immediate           true                   15m
ceph-bucket            rook-ceph.ceph.rook.io/bucket   Delete          Immediate           false                  15m
ceph-filesystem        rook-ceph.cephfs.csi.ceph.com   Delete          Immediate           true                   15m
```

We will use the ceph-filesystem storage class, this one will allow to share
a volume by multiple pods.

We will create a simple web page, with a deployment of 2 pods, they will share
a volume of 1GB containing the HTML page. This application is exposed by a
gateway api http route rule.

Apply the following kubernetes manifest:

```
apiVersion: v1
kind: Namespace
metadata:
  name: www2
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cephfs-pvc
  namespace: www2
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 1Gi
  storageClassName: ceph-filesystem
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: www2
  name: www2
  namespace: www2
spec:
  replicas: 2
  selector:
    matchLabels:
      app: www2
  template:
    metadata:
      labels:
        app: www2
    spec:
      containers:
      - image: nginx
        name: nginx
        volumeMounts:
          - name: mypvc
            mountPath: /usr/share/nginx/html
      volumes:
        - name: mypvc
          persistentVolumeClaim:
            claimName: cephfs-pvc
            readOnly: false
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: www2
  name: www2
  namespace: www2
spec:
  ports:
  - name: http
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: www2
  type: ClusterIP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: https-www2
  namespace: www2
spec:
  parentRefs:
  - name: tls-gateway
    namespace: kube-system
  hostnames:
  - "www2.unixworld.io"
  rules:
  - matches:
    - path:
        type: PathPrefix
        value: /
    backendRefs:
    - name: www2
      port: 80
```

    $ kubectl apply -f www2-manifest.yaml

Check the pvc:

    $ kubectl -n www2 get pvc

should return:
```
NAME         STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS      VOLUMEATTRIBUTESCLASS   AGE
cephfs-pvc   Bound    pvc-7727178b-d785-428d-a7d1-58a59987118c   1Gi        RWX            ceph-filesystem   <unset>                 15s
```

Check the volume:

    $ kubectl get pv

should return:
```
NAME                                       CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM             STORAGECLASS      VOLUMEATTRIBUTESCLASS   REASON   AGE
pvc-7727178b-d785-428d-a7d1-58a59987118c   1Gi        RWX            Delete           Bound    www2/cephfs-pvc   ceph-filesystem   <unset>                          104s
```

Notice the state `Bound`, it does mean this volume is mounted by one or multiple pods.

Check if the pods are up and running:

    $ kubectl -n www2 get po

should return:
```
NAME                    READY   STATUS    RESTARTS   AGE
www2-6bd7d5f745-8n8ht   1/1     Running   0          4m54s
www2-6bd7d5f745-xh7bh   1/1     Running   0          4m54s
```

Create a simple web page, pickup a pod in the www2 namespace:

    $ kubectl -n www2 exec -it www2-6bd7d5f745-8n8ht -- sh -c 'echo "hello world" > /usr/share/nginx/html/index.html'

Check the page:

    $ curl https://www2.<your_domain>

should return:
```
hello world
```

## Check the Gateway api

    $ kubectl -n kube-system get gateways

should return:
```
NAME          CLASS    ADDRESS   PROGRAMMED   AGE
tls-gateway   cilium             False        30m
```

Check the httproutes:

    $ kubectl get httproutes -A

should return:
```
NAMESPACE   NAME                    HOSTNAMES                 AGE
argocd      argo-cd-argocd-server   ["argocd.unixworld.io"]   23m
www2        https-www2              ["www2.unixworld.io"]     9m6s
```

## Destroying

    $ cd cluster-01/04-kubernetes
    $ make destroy
    $ cd ../03-servers
    $ make destroy
    $ cd ../02-network
    $ make destroy
    $ cd ../01-certificate
    $ make destroy
    $ cd ../00-bucket
    $ make destroy

# Summary

By using the spot instance you know now how to save some money!
