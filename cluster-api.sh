### https://piotrminkowski.com/2021/12/03/create-kubernetes-clusters-with-cluster-api-and-argocd/

### https://cluster-api.sigs.k8s.io/user/quick-start.html


curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.5.0/clusterctl-linux-amd64 -o clusterctl
chmod +x ./clusterctl
mv ./clusterctl /usr/local/bin/clusterctl
clusterctl version

curl https://raw.githubusercontent.com/hbstarjason2021/ngrok-k8s/main/install-kubectl.sh | bash

    KIND_VESION="v0.20.0"
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VESION}/kind-linux-amd64
    chmod +x ./kind
    mv ./kind /usr/local/bin/kind
    kind version

cat <<EOF > mgmt-cluster-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
EOF

kind create cluster --config mgmt-cluster-config.yaml --name mgmt

export CLUSTER_TOPOLOGY=true
clusterctl init --infrastructure docker


### kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml


# The list of service CIDR, default ["10.128.0.0/12"]
export SERVICE_CIDR=["10.96.0.0/12"]

# The list of pod CIDR, default ["192.168.0.0/16"]
export POD_CIDR=["192.168.0.0/16"]

# The service domain, default "cluster.local"
export SERVICE_DOMAIN="k8s.test"

export ENABLE_POD_SECURITY_STANDARD="false"


clusterctl generate cluster c1 --flavor development \
  --infrastructure docker \
  --kubernetes-version v1.24.0 \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > c1-clusterapi.yaml
  
kubectl apply -f c1-clusterapi.yaml


kind get clusters

kind export kubeconfig --name c1


clusterctl describe cluster c1

kubectl get kubeadmcontrolplane


clusterctl get kubeconfig c1 > c1.kubeconfig

kubectl --kubeconfig=./c1.kubeconfig get nodes

### wget https://github.com/ahmetb/kubectx/releases/download/v0.9.4/kubectx

kubectl --kubeconfig=./c1.kubeconfig \
  apply -f https://docs.projectcalico.org/v3.21/manifests/calico.yaml


### clusterctl config repositories
