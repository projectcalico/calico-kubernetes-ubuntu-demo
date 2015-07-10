Kubernetes Deployment On Bare-metal Ubuntu Nodes with Calico Networking
------------------------------------------------

## Introduction

This document describes how to deploy kubernetes on ubuntu bare metal nodes with Calico Networking plugin. See [projectcalico.org](http://projectcalico.org) for more information on what Calico is, and [calico-docker](https://github.com/Metaswitch/calico-docker) for more information on the command-line tool, `calicoctl`.

This guide will get a simple kubernetes architecture running across a master node and two node agents by starting the following processes with systemd:

On the Master node:
- `etcd`
- `kube-apiserver`
- `kube-controller-manager`
- `kube-scheduler`
 
On each Node Agent:
- `kube-proxy`
- `kube-kubelet`
- `calico-node` 

## Prerequisites
1. This guide uses `systemd` and thus uses Ubuntu 15.04 which supports systemd natively.
2. All kubernetes nodes should have the latest docker stable version installed. At the time of writing, that is Docker 1.7.0
3. All hosts should be able to communicate with each other. Internet access is recommended in order to speed up dependency installation.


## Starting a Cluster
### Setup Master
The calico networking plugin for kubernetes is run on each node agent, so the master node setup process is not unlike any other standard Kubernetes deployment. In this tutorial, we'll provide sample systemctl services files to quickly get all the required kubernetes processes running on the host.

#### Setup environment variables for systemd services
1.) Get the sample configurations for this tutorial
```
git clone https://github.com/Metaswitch/calico-kubernetes-ubuntu-demo.git
```

2.) Copy the network-environment-template from the `master` directory
```
cp calico-kubernetes-ubuntu-demo/master/network-environment-template network-environment
```
3.) Edit `network-environment` to represent your current host's settings.
```
4.) Move the settings into `/etc`
```
sudo mv -f network-environment /etc
```

#### Install Kubernetes

1.) Build & Install Kubernetes binaries
```
# Get the Kubernetes Source
wget https://github.com/GoogleCloudPlatform/kubernetes/releases/download/v0.20.2/kubernetes.tar.gz
# Untar it
tar -xf kubernetes.tar.gz
tar -xf kubernetes/server/kubernetes-server-linux-amd64.tar.gz
kubernetes/cluster/ubuntu/build.sh
# Add binaries to /usr/bin
sudo cp -f binaries/master/* /usr/bin
sudo cp -f binaries/kubectl /usr/bin
```
>You can customize your etcd version,  k8s version by changing variable `ETCD_VERSION` and `K8S_VERSION` in build.sh, default etcd version is 2.0.9, and K8s version is 0.18.0.

2.) Install the sample systemd processes settings for launching kubernetes services
```
sudo cp -f calico-kubernetes-demo/master/*.service /etc/systemd
systemctl enable /etc/systemd/etcd.service
systemctl enable /etc/systemd/kube-apiserver.service
systemctl enable /etc/systemd/kube-controller-manager.service
systemctl enable /etc/systemd/kube-scheduler.service
```

3.) Launch the processes. (You may want to consider checking their status after to ensure everything is running)
```
systemctl start etcd.service
systemctl start kube-apiserver.service
systemctl start kube-controller-manager.service
systemctl start kube-scheduler.service
```

### Setup Nodes
Perform these steps once on each node, ensuring you appropriately set the environment variables on each node

#### Setup environment variables for systemd services
1.) Get the sample configurations for this tutorial
```
git clone https://github.com/Metaswitch/calico-kubernetes-ubuntu-demo.git
```

2.) Copy the network-environment-template from the `node` directory
```
cp calico-kubernetes-ubuntu-demo/node/network-environment-template network-environment
```
3.) Edit  `network-environment` to represent your current host's settings.
```
4.) Move the settings into `/etc`
```
sudo mv -f network-environment /etc
```

#### Install Kubernetes & Calico

1.) Build & Install Kubernetes binaries
```
# Get the Kubernetes Source
wget https://github.com/GoogleCloudPlatform/kubernetes/releases/download/v0.20.2/kubernetes.tar.gz
# Untar it
tar -xf kubernetes.tar.gz
tar -xf kubernetes/server/kubernetes-server-linux-amd64.tar.gz
kubernetes/cluster/ubuntu/build.sh
# Add binaries to /usr/bin
sudo cp -f binaries/minion/* /usr/bin
```

2.) Install calicoctl
```
wget https://github.com/Metaswitch/calico-docker/releases/download/v0.5.0/calicoctl
chmod +x calicoctl
sudo cp -f calicoctl /usr/bin
```

3.) Install calico kubernetes plugin
```
wget https://github.com/Metaswitch/calico-docker/releases/download/v0.4.8/calico_kubernetes
sudo mkdir -p /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico
sudo mv -f calico_kubernetes /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico/calico
```
>Note: we change the name of the plugin to 'calico' as the plugin must share the same name as the directory it is placed in.

4.) Install the sample systemd processes settings for launching kubernetes services
```
sudo cp -f calico-kubernetes-ubuntu-demo/node/*.service /etc/systemd
sudo systemctl enable /etc/systemd/calico-node.service
sudo systemctl enable /etc/systemd/kube-proxy.service
sudo systemctl enable /etc/systemd/kube-kubelet.service
```

5.) Launch the processes. (You may want to consider checking their status after to ensure everything is running)
```
sudo systemctl start calico-node.service
sudo systemctl start kube-proxy.service
sudo systemctl start kube-kubelet.service
```

6.) Use calicoctl to add an IP Pool. We must specify where the etcd daemon is in order for calicoctl to communicate with it.
```
ETCD_AUTHORITY=<MASTER_IP>:4001 calicoctl pool add 172.17.0.0/16
```

#### Launch other Services With Kubernetes
At this point, you have a fully functioning cluster running on kubernetes with a master and 2 nodes networked with Calico. Lets start some services and see that things work.

`$ kubectl get nodes`
