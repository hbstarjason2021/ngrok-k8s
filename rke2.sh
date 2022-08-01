#### https://github.com/risenforces/rke2-bootstrap

curl -sfL https://get.rke2.io | sh -
systemctl enable rke2-server.service
systemctl start rke2-server.service


curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=server sh -

## curl -sfL http://rancher-mirror.rancher.cn/rke2/install.sh | INSTALL_RKE2_MIRROR=cn sh -

systemctl enable rke2-server.service
systemctl start rke2-server.service

journalctl -u rke2-server -f

## /var/lib/rancher/rke2/:存放额外部署的集群插件（core-dns、网络插件、Ingress-Controller）、etcd数据库存放路径、其他worker连接的token
## /etc/rancher/rke2/：连接集群的kubeconfig文件，以及集群组件参数配置信息


mkdir ~/.kube
cp /etc/rancher/rke2/rke2.yaml ~/.kube/config
cp /var/lib/rancher/rke2/bin/* /usr/local/bin/

## 获取worker注册到server的token文件
cat /var/lib/rancher/rke2/server/token


# cert manager
## kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/v1.9.1/cert-manager.yaml


curl -sfL http://rancher-mirror.rancher.cn/rke2/install.sh | INSTALL_RKE2_MIRROR=cn INSTALL_RKE2_TYPE="agent"  sh -

systemctl enable rke2-agent.service

mkdir -p /etc/rancher/rke2/

vim /etc/rancher/rke2/config.yaml

server: https://<server>:9345
token: <token from server node>

## rke2 server 进程通过端口 9345 监听新节点的注册。Kubernetes API 仍然监听端口 6443。

systemctl start rke2-agent.service
journalctl -u rke2-agent -f

kubectl create deployment test --image=busybox:1.28  --replicas=2   -- sleep 30000


###########

nginx.conf

events {
  worker_connections  1024;  ## Default: 1024
} 
stream {
    upstream kube-apiserver {
        server host1:6443     max_fails=3 fail_timeout=30s;
        server host2:6443     max_fails=3 fail_timeout=30s;
        server host3:6443     max_fails=3 fail_timeout=30s;
    }
    upstream rke2 {
        server host1:9345     max_fails=3 fail_timeout=30s;
        server host2:9345     max_fails=3 fail_timeout=30s;
        server host3:9345     max_fails=3 fail_timeout=30s;
    }
    server {
        listen 6443;
        proxy_connect_timeout 2s;
        proxy_timeout 900s;
        proxy_pass kube-apiserver;
    }
    server {
        listen 9345;
        proxy_connect_timeout 2s;
        proxy_timeout 900s;
        proxy_pass rke2;
    }
}

docker run -itd -p 9345:9345  -p 6443:6443 -v ~/nginx.conf:/etc/nginx/nginx.conf nginx


mkdir /etc/rancher/rke2/ -p
touch config.yaml
tls-san:
  - xxx.xxx.xxx.xxx
  - www.xxx.com
  
## 此处填写LB的统一入口ip地址或域名，如果有多个换行分组方式隔开  

mkdir -p /etc/rancher/rke2/
vim /etc/rancher/rke2/config.yaml
server: https://<server>:9345
token: <token from server node>
tls-san:
  - xxx.xxx.xxx.xxx
  - www.xxx.com
  
## server地址可以填写第一台Server的地址，也可以填写外部统一入口的地址，最佳实践是填写统一入口地址，这样当第一个Server出现问题后，agent还可以通过统一入口地址通过其他Server获取集群信息。
## token填写第一台server的token
## tls-san跟第一台server一样，一般填写统一入口的ip地址或域名，用于TLS证书注册。


etcdctl --cert /var/lib/rancher/rke2/server/tls/etcd/server-client.crt --key /var/lib/rancher/rke2/server/tls/etcd/server-client.key --endpoints https://127.0.0.1:2379 --cacert /var/lib/rancher/rke2/server/tls/etcd/server-ca.crt member list


########

curl -sfL https://get.rke2.io --output install.sh
INSTALL_RKE2_ARTIFACT_PATH=/root/images sh install.sh

systemctl enable rke2-server.service
systemctl start rke2-server.service

cp lib/systemd/system/* /usr/local/lib/systemd/system/
cp bin/* /usr/local/bin/
cp share/* /usr/local/share/ -rf

## 配置config.yaml，指定默认拉取镜像
system-default-registry: xxx.xxx.xxx.xxx
