#!/bin/bash
# Install the environment variables
cp -f network-environment /etc

# Get Kubernetes Binaries
wget --no-verbose --show-progress --directory-prefix=tmp https://github.com/GoogleCloudPlatform/kubernetes/releases/download/v0.20.2/kubernetes.tar.gz
tar -xf tmp/kubernetes.tar.gz -C tmp/
# TODO: fix that this gets put in the same folder as kubernetes/ 
tar -xf tmp/kubernetes/server/kubernetes-server-linux-amd64.tar.gz -C tmp/

# Install Calico service
wget --no-verbose --show-progress --directory-prefix=tmp https://github.com/Metaswitch/calico-docker/releases/download/v0.5.0/calicoctl
cp -f tmp/calicoctl /usr/bin
cp -f ./calico-node.service /etc/systemd/calico-node.service
systemctl enable /etc/systemd/calico-node.service
systemctl start calico-node.service


# Install kube-proxy
cp -f tmp/kubernetes/server/bin/kube-proxy /usr/bin
cp -f ./kube-proxy.service /etc/systemd/kube-proxy.service
systemctl enable /etc/systemd/kube-proxy.service
systemctl start kube-proxy.service

# Get the calico_kubernetes binary
mkdir -p /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico

wget --no-verbose \
	 --show-progress \
	 --directory-prefix=/usr/libexec/kubernetes/kubelet-plugins/net/exec/calico \
	 http://172.24.114.228/calico_kubernetes
mv /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico/calico_kubernetes /usr/libexec/kubernetes/kubelet-plugins/net/exec/calico/calico



# Install kube-kubelet
cp -f tmp/kubernetes/server/bin/kubelet /usr/bin
cp -f ./kube-kubelet.service /etc/systemd/kube-kubelet.service
systemctl enable /etc/systemd/kube-kubelet.service
systemctl start kube-kubelet.service

# # Install kube-scheduler
# cp -f tmp/kubernetes/server/bin/kube-scheduler /usr/bin
# cp -f ./kube-scheduler.service /etc/systemd/kube-scheduler.service
# systemctl enable /etc/systemd/kube-scheduler.service
# systemctl start kube-scheduler.service
