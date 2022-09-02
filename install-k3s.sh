#curl -sfL https://get.k3s.io | sh -
#curl -sfL https://get.k3s.io  | INSTALL_K3S_VERSION=v1.17.3 sh -
#curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC_="--docker"  sh -s -

curl -sfL https://get.k3s.io | sh -s - --disable=traefik
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

mkdir -p $HOME/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config

k3s check-config

### 国内安装k3s
# curl -sfL http://rancher-mirror.cnrancher.com/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -

# curl -sfL http://rancher-mirror.cnrancher.com/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -s - --disable=traefik

# curl -sfL https://rancher-mirror.oss-cn-beijing.aliyuncs.com/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -

# curl -sfL https://rancher-mirror.oss-cn-beijing.aliyuncs.com/k3s/k3s-install.sh | \
#    INSTALL_K3S_MIRROR=cn \
#    K3S_TOKEN=devops \
#    sh -s - \
#    --system-default-registry "registry.cn-hangzhou.aliyuncs.com"


### 卸载
# /usr/local/bin/k3s-uninstall.sh
# /usr/local/bin/k3s-agent-uninstall.sh

#### https://github.com/k3s-io/k3s/releases/download/v1.24.4-rc1%2Bk3s1/k3s
#### nohup sudo k3s server &
#### kubectl --kubeconfig /etc/rancher/k3s/k3s.yaml get node


curl -sfL https://get.k3s.io | K3S_CLUSTER_SECRET=thisisverysecret sh -
k3s kubectl get node
until k3s kubectl get node 2>/dev/null | grep master | grep -q ' Ready'; do sleep 1; done; k3s kubectl get node

curl -sfL https://get.k3s.io | K3S_CLUSTER_SECRET=thisisverysecret K3S_URL=https://172.30.1.2:6443 sh -
k3s kubectl get node
until k3s kubectl get node | grep node01 | grep -q ' Ready'; do sleep 1; done; k3s kubectl get node


### docker run --name mysql --restart=unless-stopped -p 3306:3306 -e MYSQL_ROOT_PASSWORD=password -d mysql:5.7
