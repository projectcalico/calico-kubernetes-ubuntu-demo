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
- `calico-node`

On each Node Agent:
- `kube-proxy`
- `kube-kubelet`
- `calico-node` 

## Prerequisites
1. This guide uses `systemd` and thus uses Ubuntu 15.04 which supports systemd natively.
2. All kubernetes nodes should have the latest docker stable version installed. At the time of writing, that is Docker 1.7.0
3. All hosts should be able to communicate with each other. Internet access is recommended in order to speed up dependency installation.
4. This demo assumes that none of the hosts have been configured with any kubernetes or Calico software yet.

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

4.) Move the `network-environment` into `/etc`
```
sudo mv -f network-environment /etc
```

#### Install Calico on Master
In order to allow the master to speak to the containers on each node, we will launch a calico-node which speaks BGP with the calico-node on the nodes. The calico-node.service will take care of this for us, we only need to install the binary for it to use.
```
wget https://github.com/Metaswitch/calico-docker/releases/download/v0.5.0/calicoctl
chmod +x calicoctl
sudo cp -f calicoctl /usr/bin
```

#### Install Kubernetes on Master
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
sudo systemctl enable /etc/systemd/etcd.service
sudo systemctl enable /etc/systemd/kube-apiserver.service
sudo systemctl enable /etc/systemd/kube-controller-manager.service
sudo systemctl enable /etc/systemd/kube-scheduler.service
sudo systemctl enable /etc/systemd/calico-node.service
```

3.) Launch the processes.
```
sudo systemctl start etcd.service
sudo systemctl start kube-apiserver.service
sudo systemctl start kube-controller-manager.service
sudo systemctl start kube-scheduler.service
sudo systemctl start calico-node.service
```

> *You may want to consider checking their status after to ensure everything is running.*

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
3.) Edit `network-environment` to represent your current host's settings.

4.) Move `netework-environment` into `/etc`
```
sudo mv -f network-environment /etc
```

#### Configure Docker
##### Create the veth
Instead of using docker's default interface (docker0), we will configure a new one to use desired IP ranges
```
sudo brctl add cbr0
sudo ifconfig cbr0 up
sudo ifconfig cbr0 <IP>/24
```
> Replace \<IP\>  with the subnet for this host's containers. Example topology:

  Node   |   cbr0 IP
-------- | -------------
node-1  | 192.168.1.1/24
node-2  | 192.168.2.1/24
node-X  | 192.168.X.1/24

##### Start docker on cbr0
The Docker daemon must be started and told to use the already configured cbr0 instead of using the usual docker0, as well as disabling ip-masquerading and modification of the ip-tables. We've provided a `docker-cbr0.service` to quickly start the docker daemon with these settings. (Ensure docker isn't already running!)
```
sudo cp calico-kubernetes-ubuntu-demo/node/docker-cbr.service /etc/systemd
sudo systemctl enable /etc/systemd/docker-cbr.service
sudo systemctl start /etc/systemd/docker-cbr.service
```

#### Install Calico on the Node
1.) Install calico and the kubernetes plugin
```
# Get the calicoctl binary
wget https://github.com/Metaswitch/calico-docker/releases/download/v0.5.0/calicoctl
chmod +x calicoctl
sudo cp -f calicoctl /usr/bin

# Install the calico-kubernetes plugin
wget https://github.com/Metaswitch/calico-docker/releases/download/v0.4.8/calico_kubernetes
sudo mkdir -p /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico
sudo mv -f calico_kubernetes /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico/calico
sudo chmod +x /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico/calico

# Start calico on this node
sudo systemctl enable /etc/systemd/calico-node.service
sudo systemctl start calico-node.service
```
2.) Use calicoctl to add an IP Pool. We must specify where the etcd daemon is in order for calicoctl to communicate with it.
**NOTE: This step only needs to be performed once per kubernetes deployment, as it covers all the node's IP ranges.**
```
ETCD_AUTHORITY=<MASTER_IP>:4001 calicoctl pool add 192.168.0.0/16
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
sudo cp -f binaries/minion/* /usr/bin
```

2.) Install the sample systemd processes settings for launching kubernetes services
```
sudo systemctl enable /etc/systemd/kube-proxy.service
sudo systemctl enable /etc/systemd/kube-kubelet.service
```

3.) Launch the processes.
```
sudo systemctl start kube-proxy.service
sudo systemctl start kube-kubelet.service
```
>*You may want to consider checking their status after to ensure everything is running*


## Custom Networking Topologies
Depending on your networking setup, you may want to configure things differently, depending on:
- If you are operating kubernetes across a network fabric that you control
- If you own the addressable IP ranges
- If you want containers to be accessible from the outside world

#### Launch other Services With Kubernetes
At this point, you have a fully functioning cluster running on kubernetes with a master and 2 nodes networked with Calico. Lets start some services and see that things work.

`$ kubectl get nodes`
