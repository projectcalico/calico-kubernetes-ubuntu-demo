Kubernetes Deployment On Bare-metal Ubuntu Nodes with Calico Networking
------------------------------------------------


## Introduction

This document describes how to deploy kubernetes on ubuntu nodes, including 1 master node and 3 minion nodes, and people uses this approach can scale to **any number of minion nodes** by changing some settings with ease. The original idea was heavily inspired by @jainvipin 's ubuntu single node work, which has been merge into this document.

## Authors
[Calico-Docker team at Metaswitch Networks](projectcalico.org)

## Prerequisites
1. This guide was written with Ubuntu 15.04 which supports systemd natively
2. All kubernetes nodes should have the latest docker stable version installed. At the time of writing, that is Docker 1.7.0
3. All machines can communicate with each other. Internet access is recommended in order to speed up dependency installation.


## Starting a Cluster
### Setup Master
No calico process needs to run on the Master Node - only the normal kubernetes processes. Set the environment variables first, as some of these processes rely on them.

#### Install the systemd environment variables

1. Get our sample configs
```
wget https://github.com/Metaswitch/calico-kubernetes-demo/archive/master.zip
unzip calico-kubernetes-demo.zip
cp calico-kubernetes-demo/ubuntu/master/network-environment-template ./network-environment
```
 
2. Edit your environment variables to match your current system setup
3. "Install" the environment variables
```
sudo mv -f network-environment /etc
```

#### Install Kubernetes

1. Build & Install Kubernetes binaries
```
# Get the Kubernetes Source
wget https://github.com/GoogleCloudPlatform/kubernetes/releases/download/v0.20.2/kubernetes.tar.gz
# Untar it
tar -xf kubernetes.tar.gz
tar -xf kubernetes/server/kubernetes-server-linux-amd64.tar.gz
# DJO-TODO: clean up the make process
cd kubernetes/cluster/ubuntu
./build.sh
# Add binaries to /usr/bin
sudo cp -f kubernetes/server/bin/* /usr/bin
```
>You can customize your etcd version, flannel version, k8s version by changing variable `ETCD_VERSION` , `FLANNEL_VERSION` and `K8S_VERSION` in build.sh, default etcd version is 2.0.9, flannel version is 0.4.0 and K8s version is 0.18.0.

2. Install etcd
```
wget  https://github.com/coreos/etcd/releases/download/v2.0.13/etcd-v2.0.13-linux-amd64.tar.gz
tar -xf etcd-v2.0.13-linux-amd64.tar.gz
sudo cp -f etcd-v2.0.13-linux-amd64/etcd /usr/bin
```

3. Install the sample systemd processes settings for launching kubernetes services
```
sudo cp -f calico-kubernetes-demo/ubuntu/master/*.service /etc/systemd
systemctl enable /etc/systemd/etcd.service
systemctl enable /etc/systemd/kube-apiserver.service
systemctl enable /etc/systemd/kube-controller-manager.service
systemctl enable /etc/systemd/kube-scheduler.service
```

4. Launch the processes. (You may want to consider checking their status after to ensure everything is running)
```
systemctl start etcd.service
systemctl start kube-apiserver.service
systemctl start kube-controller-manager.service
systemctl start kube-scheduler.service
```

### Setup Nodes
Perform these steps once on each node, ensuring you appropriately set the environment variables on each node

#### Install the systemd environment variables

1. Get our sample configs
```
wget https://github.com/Metaswitch/calico-kubernetes-demo/archive/master.zip
unzip calico-kubernetes-demo.zip
cp calico-kubernetes-demo/ubuntu/master/network-environment-template ./network-environment
```
 
2. Edit your environment variables to match your current system setup
3. "Install" the environment variables
```
sudo mv -f network-environment /etc
```

#### Install Kubernetes & Calico

1. Build & Install Kubernetes binaries
```
# Get the Kubernetes Source
wget https://github.com/GoogleCloudPlatform/kubernetes/releases/download/v0.20.2/kubernetes.tar.gz
# Untar it
tar -xf kubernetes.tar.gz
tar -xf kubernetes/server/kubernetes-server-linux-amd64.tar.gz
# DJO-TODO: clean up the make process
cd kubernetes/cluster/ubuntu
./build.sh
# Add binaries to /usr/bin
sudo cp -f kubernetes/server/bin/* /usr/bin
```

2. Install calicoctl
```
wget https://github.com/Metaswitch/calico-docker/releases/download/v0.5.0/calicoctl
sudo cp -f calicoctl /usr/bin
```

3. Install calico kubernetes plugin
```
wget <TODO: KUBERNETES PLUGIN DOWNLOAD LINK>/calico_kubernetes
mkdir -p /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico
sudo mv -f calico_kubernetes /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico
```

3. Install the sample systemd processes settings for launching kubernetes services
```
sudo cp -f calico-kubernetes-demo/ubuntu/master/*.service /etc/systemd
systemctl enable /etc/systemd/calico-node.service
systemctl enable /etc/systemd/kube-proxy.service
systemctl enable /etc/systemd/kube-kubelet.service
```

4. Launch the processes. (You may want to consider checking their status after to ensure everything is running)
```
systemctl start calico-node.service
systemctl start kube-proxy.service
systemctl start kube-kubelet.service
```

5. Use calicoctl to add an IP Pool. We must specify where the etcd daemon is in order for calicoctl to communicate with it.
```
ETCD_AUTHORITY=<MASTER_IP>:4001 calicoctl pool add 172.17.0.0/16
```

#### Launch other Services With Kubernetes
At this point, you have a fully functioning cluster running on kubernetes with a master and 2 nodes networked with Calico. Lets start some services and see that things work.

`$ kubectl get nodes`
