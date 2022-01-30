#!/usr/bin/env bash

cd "$(dirname "$0")" || exit

echo "Uninstalling Cert-Manager"
helm --namespace cert-manager delete cert-manager
kubectl delete -f https://github.com/jetstack/cert-manager/releases/download/v1.5.1/cert-manager.crds.yaml
kubectl delete -f https-certificates.yaml

echo "Uninstalling GitLab"
helm uninstall gitlab -n gitlab

echo "Uninstalling GitPod"
kubectl get configmaps gitpod-app -n gitpod -o jsonpath='{.data.app\.yaml}' \
  | kubectl delete -n gitpod -f -

echo "Deleting namespaces"
kubectl delete -f namespaces.yaml