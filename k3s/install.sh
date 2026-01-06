# k3s/install.sh
#!/bin/bash
set -e

# Install Docker
apt update
apt install -y ca-certificates curl gnupg

curl -fsSL https://get.docker.com | sh
usermod -aG docker $SUDO_USER

# Install k3s
curl -sfL https://get.k3s.io | sh -

# Configure kubeconfig
mkdir -p /home/$SUDO_USER/.kube
cp /etc/rancher/k3s/k3s.yaml /home/$SUDO_USER/.kube/config
chown $SUDO_USER:$SUDO_USER /home/$SUDO_USER/.kube/config
