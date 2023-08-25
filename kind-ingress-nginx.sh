#!/bin/bash

## https://kind.sigs.k8s.io/docs/user/ingress/

set -eux

curl https://raw.githubusercontent.com/hbstarjason2021/ngrok-k8s/main/install-kubectl.sh | bash

## https://github.com/kubernetes-sigs/kind/releases

KIND_VESION="v0.20.0"
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

# kubectl wait --namespace ingress-nginx  --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s

kubectl get po -A

#############################
<<'COMMENT'

kubectl create deployment nginx --image=nginx:alpine
kubectl create service nodeport nginx --tcp=80:80

kubectl run curl --image=hbstarjason/busyboxplus:curl -i --tty
nslookup kubernetes

kubectl attach <podname> -c curl -i -t 


# Ingress IP
INGRESS_IP=$(docker inspect kind | jq -r '.. | .IPv4Address? | select(type != "null") | split("/")[0]')
INGRESS_DOMAIN="${INGRESS_IP}.nip.io"

NODE_IP=$(kubectl get node -o wide|tail -1|awk {'print $6'})
NODE_PORT=$(kubectl get svc nginx -o go-template='{{range.spec.ports}}{{if .nodePort}}{{.nodePort}}{{"\n"}}{{end}}{{end}}')
sleep 30
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
