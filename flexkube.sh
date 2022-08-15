### https://flexkube.github.io/documentation/guides/kubernetes/creating-single-node-cluster-on-local-machine-using-flexkube-cli/

export IP=$(ip addr show dev $(ip r | grep default | tr ' ' \\n | grep -A1 dev | tail -n1) | grep 'inet ' | awk '{print $2}' | cut -d/ -f1); echo $IP
export POD_CIDR=10.0.0.0/24
export SERVICE_CIDR=11.0.0.0/24
export KUBERNETES_SERVICE_IP=11.0.0.1
export DNS_SERVICE_IP=11.0.0.10
export FLEXKUBE_VERSION=v0.8.0
export HELM_VERSION=3.9.3
export PATH="$(pwd):${PATH}"
##export TOKEN_ID=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 6 | head -n 1)
##export TOKEN_SECRET=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 16 | head -n 1)
export TOKEN_ID=1234.abcd
export TOKEN_SECRET=abcd.1234
export KUBECONFIG=$(pwd)/kubeconfig
export API_SERVER_PORT=6443

umask 077

[ ! -f flexkube ] && wget -O- https://github.com/flexkube/libflexkube/releases/download/${FLEXKUBE_VERSION}/flexkube_${FLEXKUBE_VERSION}_linux_amd64.tar.gz | tar zxvf -
[ ! -f kubectl ] && curl -LO https://storage.googleapis.com/kubernetes-release/release/`curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl && chmod +x kubectl
[ ! -f helm ] && wget -O- https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz | tar -zxvf - linux-amd64/helm && mv linux-amd64/helm ./ && rmdir linux-amd64


cat <<EOF | sed '/^$/d' > config.yaml
pki:
  etcd:
    clientCNs:
    - kube-apiserver
    peers:
      testing: ${IP}
  kubernetes:
    kubeAPIServer:
      serverIPs:
      - ${IP}
      - ${KUBERNETES_SERVICE_IP}
etcd:
  members:
    testing:
      peerAddress: ${IP}
controlplane:
  apiServerAddress: ${IP}
  apiServerPort: ${API_SERVER_PORT}
  kubeAPIServer:
    serviceCIDR: ${SERVICE_CIDR}
    etcdServers:
    - https://${IP}:2379
  kubeControllerManager:
    flexVolumePluginDir: /var/lib/kubelet/volumeplugins
kubeletPools:
  default:
    bootstrapConfig:
      token: ${TOKEN_ID}.${TOKEN_SECRET}
      server: ${IP}:${API_SERVER_PORT}
    adminConfig:
      server: ${IP}:${API_SERVER_PORT}
    privilegedLabels:
      node-role.kubernetes.io/master: ""
    volumePluginDir: /var/lib/kubelet/volumeplugins
    kubelets:
    - name: testing
      address: ${IP}
EOF

flexkube --yes pki
flexkube --yes etcd
flexkube --yes controlplane
flexkube --yes kubeconfig | grep -v "Trying to read" > ${KUBECONFIG}
helm repo add flexkube https://flexkube.github.io/charts/
helm upgrade --install -n kube-system tls-bootstrapping flexkube/tls-bootstrapping --set tokens[0].token-id=$TOKEN_ID --set tokens[0].token-secret=$TOKEN_SECRET
flexkube --yes kubelet-pool default
helm upgrade --install --wait -n kube-system kube-proxy flexkube/kube-proxy --set "podCIDR=${POD_CIDR}" --set apiServers="{${IP}:${API_SERVER_PORT}}"
helm upgrade --install --wait -n kube-system calico flexkube/calico --set flexVolumePluginDir=/var/lib/kubelet/volumeplugins --set podCIDR=$POD_CIDR
helm upgrade --install --wait -n kube-system coredns flexkube/coredns --set rbac.pspEnable=true --set service.ClusterIP=$DNS_SERVICE_IP
helm upgrade --install --wait -n kube-system kubelet-rubber-stamp flexkube/kubelet-rubber-stamp

