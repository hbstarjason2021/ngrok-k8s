#!/bin/bash

## https://kind.sigs.k8s.io/docs/user/ingress/

set -eux

## https://github.com/kubernetes-sigs/kind/releases

KIND_VESION="v0.13.0"
curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VESION}/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/local/bin/kind
kind version

### https://kind.sigs.k8s.io/docs/user/ingress/

cat <<EOF | kind create cluster --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  kubeProxyMode: "ipvs"
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
EOF

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

kubectl get po -A

#############################
<<'COMMENT'

NODE_IP=$(kubectl get node -o wide|tail -1|awk {'print $6'})
NODE_PORT=$(kubectl get svc nginx-service -o go-template='{{range.spec.ports}}{{if .nodePort}}{{.nodePort}}{{"\n"}}{{end}}{{end}}')
sleep 60
SUCCESS=$(curl $NODE_IP:$NODE_PORT)
if [[ "${SUCCESS}" != "Hello World" ]]; 
then
 kind -q delete cluster
 exit 1;
else
 kind -q delete cluster
 echo "Component test succesful"
fi

COMMENT
#############################
