### https://piotrminkowski.com/2021/12/03/create-kubernetes-clusters-with-cluster-api-and-argocd/

### https://cluster-api.sigs.k8s.io/user/quick-start.html


mgmt-cluster-config.yaml

kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
      

kind create cluster --config mgmt-cluster-config.yaml --name mgmt

clusterctl init --infrastructure docker


kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

clusterctl generate cluster c1 --flavor development \
  --infrastructure docker \
  --kubernetes-version v1.21.1 \
  --control-plane-machine-count=3 \
  --worker-machine-count=3 \
  > c1-clusterapi.yaml
  

c1-clusterapi.yaml
