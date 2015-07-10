#!/bin/bash
# Install the environment variables
cp -f network-environment /etc

# Install etcd binary
wget --no-verbose --show-progress --directory-prefix=tmp https://github.com/coreos/etcd/releases/download/v2.0.13/etcd-v2.0.13-linux-amd64.tar.gz
tar -xf tmp/etcd-v2.0.13-linux-amd64.tar.gz -C tmp/
cp -f tmp/etcd-v2.0.13-linux-amd64/etcd /usr/bin
# Install etcd systemd service
cp -f ./etcd.service /etc/systemd/
systemctl enable /etc/systemd/etcd.service
systemctl start etcd.service

# Install kube-apiserver
wget --no-verbose --show-progress --directory-prefix=tmp https://github.com/GoogleCloudPlatform/kubernetes/releases/download/v0.20.2/kubernetes.tar.gz
tar -xf tmp/kubernetes.tar.gz -C tmp/
# TODO: fix that this gets put in the same folder as kubernetes/ 
tar -xf tmp/kubernetes/server/kubernetes-server-linux-amd64.tar.gz -C tmp/
cp -f tmp/kubernetes/server/bin/kube-apiserver /usr/bin
# Install kube-apiserver systemd service
cp -f ./kube-apiserver.service /etc/systemd/kube-apiserver.service
systemctl enable /etc/systemd/kube-apiserver.service
systemctl start kube-apiserver.service

# Install kube-controller-manager
cp -f tmp/kubernetes/server/bin/kube-controller-manager /usr/bin
cp -f ./kube-controller-manager.service /etc/systemd/kube-controller-manager.service
systemctl enable /etc/systemd/kube-controller-manager.service
systemctl start kube-controller-manager.service

# Install kube-scheduler
cp -f tmp/kubernetes/server/bin/kube-scheduler /usr/bin
cp -f ./kube-scheduler.service /etc/systemd/kube-scheduler.service
systemctl enable /etc/systemd/kube-scheduler.service
systemctl start kube-scheduler.service
