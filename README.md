Kubernetes Deployment On Bare-metal Ubuntu Nodes with Calico Networking
------------------------------------------------

## Introduction

This document describes how to deploy kubernetes on ubuntu bare metal nodes with Calico Networking plugin. See [projectcalico.org](http://projectcalico.org) for more information on what Calico is, and [the calicoctl github](https://github.com/Metaswitch/calico-docker) for more information on the command-line tool, `calicoctl`.

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
2. All kubernetes nodes should have the latest docker stable version installed. At the time of writing, that is Docker 1.7.0.
3. All hosts should be able to communicate with each other, as well as the internet, to download the necessary files.
4. This demo assumes that none of the hosts have been configured with any kubernetes or Calico software yet.

## Starting a Cluster
In this tutorial, we will provide sample systemd services to quickly get the core kubernetes services up and running.

### Setup Master
First, get the sample configurations for this tutorial
```
wget https://github.com/Metaswitch/calico-kubernetes-ubuntu-demo/archive/v1.0.tar.gz
tar -xvf v1.0.tar.gz
```

#### Setup environment variables for systemd services
Many of the sample systemd services provided rely on environment variables on a per-node basis. Here we'll edit those environment variables and move them into place.

1.) Copy the network-environment-template from the `master` directory for editing.
```
cp calico-kubernetes-ubuntu-demo-1.0/master/network-environment-template network-environment
```
2.) Edit `network-environment` to represent your current host's settings.

3.) Move the `network-environment` into `/etc`
```
sudo mv -f network-environment /etc
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

2.) Install the sample systemd processes settings for launching kubernetes services
```
sudo cp -f calico-kubernetes-ubuntu-demo-1.0/master/*.service /etc/systemd
sudo systemctl enable /etc/systemd/etcd.service
sudo systemctl enable /etc/systemd/kube-apiserver.service
sudo systemctl enable /etc/systemd/kube-controller-manager.service
sudo systemctl enable /etc/systemd/kube-scheduler.service
```

3.) Launch the processes.
```
sudo systemctl start etcd.service
sudo systemctl start kube-apiserver.service
sudo systemctl start kube-controller-manager.service
sudo systemctl start kube-scheduler.service
```
> *You may want to consider checking their status after to ensure everything is running.*

#### Install Calico on Master
In order to allow the master to speak to the containers on each node, we will launch a calico-node which speaks BGP with the calico-node on the nodes. The calico-node.service will take care of this for us, we only need to install the binary for it to use.
```
# Install the calicoctl binary, which will be used to launch calico
wget https://github.com/Metaswitch/calico-docker/releases/download/v0.4.8/calicoctl
chmod +x calicoctl
sudo cp -f calicoctl /usr/bin

# Install and start the calico service
sudo cp -f calico-kubernetes-ubuntu-demo-1.0/master/calico-node.service /etc/systemd
sudo systemctl enable /etc/systemd/etcd.service
sudo systemctl start calico-node.service
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
cp calico-kubernetes-ubuntu-demo-1.0/node/network-environment-template network-environment
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
sudo brctl addbr cbr0
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
The Docker daemon must be started and told to use the already configured cbr0 instead of using the usual docker0, as well as disabling ip-masquerading and modification of the ip-tables. 

1.) Edit the ubuntu-15.04 docker.service for systemd at: `/lib/systemd/system/docker.service`

2.) Find the line that reads `ExecStart=/usr/bin/docker -d -H fd://` and append the following flags: `--bridge=cbr0 --iptables=false --ip-masq=false`

3.) Reload systemctl with `sudo systemctl daemon-reload`

#### Install Calico on the Node
1.) Install calico and the kubernetes plugin
```
# Get the calicoctl binary
wget https://github.com/Metaswitch/calico-docker/releases/download/v0.4.8/calicoctl
chmod +x calicoctl
sudo cp -f calicoctl /usr/bin

# Install the calico-kubernetes plugin
wget https://github.com/Metaswitch/calico-docker/releases/download/v0.4.8/calico_kubernetes
sudo mkdir -p /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico
sudo mv -f calico_kubernetes /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico/calico
sudo chmod +x /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico/calico

# Start calico on this node
cp calico-kubernetes-ubuntu-demo-1.0/node/calico-node.service /etc/systemd
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

2.) Install and launch the sample systemd processes settings for launching kubernetes services
```
sudo cp calico-kubernetes-ubuntu-demo-1.0/node/kube-proxy.service
sudo cp calico-kubernetes-ubuntu-demo-1.0/node/kube-kubelet.service
sudo systemctl enable /etc/systemd/kube-proxy.service
sudo systemctl enable /etc/systemd/kube-kubelet.service
sudo systemctl start kube-proxy.service
sudo systemctl start kube-kubelet.service
```
>*You may want to consider checking their status after to ensure everything is running*

#### Launch other Services With Calico-Kubernetes
At this point, you have a fully functioning cluster running on kubernetes with a master and 2 nodes networked with Calico.


## Connectivity to outside the cluster

With this sample configuration, because the containers have private `192.168.0.0/16` IPs, you will need NAT to allow   connectivity between containers and the internet. However, in a full datacenter deployment, NAT is not necessary, since Calico can peer with the border routers over BGP.

#### NAT on the nodes

The simplest method for enabling connectivity from containers to the internet is to use an iptables masquerade rule. This is the standard mechanism [recommended](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/admin/networking.md#google-compute-engine-gce) in the Kubernetes GCE environment.

We need to NAT traffic that has a destination outside of the cluster. Internal traffic includes the nodes, and the container IP pools. Assuming that the master and nodes are in the `172.25.0.0/24` subnet, the cbr0 IP ranges are all in the `192.168.0.0/16` network, and the nodes use the interface `eth0` for external connectivity, a suitable masquerade chain would look like this:

```
sudo iptables -t nat -N KUBE-OUTBOUND-NAT
sudo iptables -t nat -A KUBE-OUTBOUND-NAT -d 192.168.0.0/16 -o eth0 -j RETURN
sudo iptables -t nat -A KUBE-OUTBOUND-NAT -d 172.25.0.0/24 -o eth0 -j RETURN
sudo iptables -t nat -A KUBE-OUTBOUND-NAT -j MASQUERADE
sudo iptables -t nat -A POSTROUTING -j KUBE-OUTBOUND-NAT
```

This chain should be applied on the master and all nodes. In production, these rules should be persisted, e.g. with `iptables-persistent`.

#### NAT at the border router

In a datacenter environment, it is recommended to configure Calico to peer with the border routers over BGP. This means that the container IPs will be routable anywhere in the datacenter, and so NAT is not needed on the nodes (though it may be enabled at the datacenter edge to allow outbound-only internet connectivity).
