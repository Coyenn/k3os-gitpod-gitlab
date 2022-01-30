#!/usr/bin/env bash

set -e
cd "$(dirname "$0")"

echo "Checking for gitpod-installer"
{
    which gitpod-installer && \
    echo "GitPod installer found"
} || {
    echo "GitPod installer not found. Installing..."
    curl -fsSLO https://github.com/gitpod-io/gitpod/releases/download/2022.01/gitpod-installer-linux-amd64
    sudo install -o root -g root gitpod-installer-linux-amd64 /usr/local/bin/gitpod-installer
    rm gitpod-installer-linux-amd64
}

echo "Cleaning up before install"
{
    bash uninstall.sh
} || {
    echo "Uninstallation failing is expected"
}

echo "Creating namespaces"
kubectl apply -f namespaces.yaml

echo "Getting Helm Repos"
helm repo add jetstack https://charts.jetstack.io
helm repo add gitlab https://charts.gitlab.io/
helm repo update

echo "Installing Cert-Manager"
kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.5.1/cert-manager.crds.yaml
helm upgrade \
    --atomic \
    --cleanup-on-fail \
    --install \
    --namespace='cert-manager' \
    --reset-values \
    --set 'extraArgs={--dns01-recursive-nameservers-only=true,--dns01-recursive-nameservers=8.8.8.8:53\,1.1.1.1:53}' \
    --wait \
    cert-manager \
    jetstack/cert-manager

echo "Installing HTTPS-Certificates"
kubectl apply -f https-certificates.yaml

echo "Installing GitLab"
helm upgrade --install gitlab gitlab/gitlab \
  --timeout 1200s \
  --set certmanager.install=false \
  --set gitlab-runner.install=false \
  --set global.ingress.configureCertmanager=false \
  --set global.ingress.tls.secretName=https-certificates \
  --set global.ingress.enabled=true \
  --set global.hosts.domain=home.local \
  -n gitlab

echo "Installing GitPod"
gitpod-installer validate config --config gitpod.config.yaml
gitpod-installer validate cluster --namespace gitpod --kubeconfig /etc/rancher/k3s/k3s.yaml --config gitpod.config.yaml
gitpod-installer render --config gitpod.config.yaml --namespace gitpod > gitpod.yaml
kubectl apply -f gitpod.yaml