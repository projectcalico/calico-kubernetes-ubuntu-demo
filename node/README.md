copy environment variables to new file, and fill out
sudo ./install.sh

After starting calicoctl, add a pool
ETCD_AUTHORITY=$2 /usr/bin/calicoctl pool add 172.17.0.0/16