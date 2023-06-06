#!/bin/bash

########## wget -qO-  https://raw.githubusercontent.com/hbstarjason2021/ngrok-k8s/main/init-tools.sh | bash

####  github.com--->hub.fastgit.xyz

####  gcr.io--->gcr.lank8s.cn
####  hcr.io--->ghcr.lank8s.cn


###### https://github.com/anjia0532/gcr.io_mirror
###### https://github.com/zhangguanzhang/google_containers

###### https://github.com/DaoCloud/public-image-mirror


<< CONTENT

########
## "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn/","https://hub-mirror.c.163.com","https://registry.docker-cn.com"]

sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://gap9aif6.mirror.aliyuncs.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker


function docker_daemon() {
sudo mkdir -p /etc/docker
cat >/etc/docker/daemon.json <<-EOF
{
    "registry-mirrors": ["https://qndprgwv.mirror.aliyuncs.com"],
    "runtimes": {
        "nvidia": {
            "path": "/usr/bin/nvidia-container-runtime",
            "runtimeArgs": []
         }  
    }
}
EOF


##### https://gitee.com/SuperManito/LinuxMirrors
##### bash <(curl -sSL https://gitee.com/SuperManito/LinuxMirrors/raw/main/ChangeMirrors.sh)


## centos
mv /etc/yum.repos.d /etc/yum.repos.d.orig.$(date -Iseconds)
mkdir -p /etc/yum.repos.d/
curl -sSLo /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo
sed "s/keepcache=0/keepcache=1/" -i /etc/yum.conf
yum install -y git

## rhel7
mv /etc/yum.repos.d /etc/yum.repos.d.orig.$(date -Iseconds)
mkdir -p /etc/yum.repos.d/
wget -qO /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo
sed -i 's/$releasever/7/g' /etc/yum.repos.d/CentOS-Base.repo
sed -i 's/PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
systemctl restart sshd

## debian
cp /etc/apt/sources.list /etc/apt/sources.list.orig.$(date -Iseconds)
sed -i 's http://.*.debian.org http://mirrors.aliyun.com g' /etc/apt/sources.list

## ubuntu
cp /etc/apt/sources.list /etc/apt/sources.list.orig.$(date -Iseconds)
sed -i 's http://.*.ubuntu.com http://mirrors.aliyun.com g' /etc/apt/sources.list

CONTENT

############################################################

set -eux

red="\033[31m"
green="\033[32m"
yellow="\033[33m"
white="\033[0m"

<< CONTENT
if [[ "$(whoami)" != "root" ]]; then
	echo "please run this script as root ." >&2
	exit 1
fi
CONTENT

set _platform=""
if [ "$(uname)" == "Darwin" ]; then
    # Do something under Mac OS X platform        
    _platform="darwin"
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    # Do something under GNU/Linux platform
    _platform="linux"
fi


function install_git () {
  set +e
  if [[ $(command -v snap >/dev/null; echo $?) -eq 0 ]];
  then
    sudo snap install git-ubuntu --classic
  elif [[ $(command -v apt-get >/dev/null; echo $?) -eq 0 ]];
  then
    sudo apt-get install git -y
  else
    sudo yum install git -y
  fi
  set -e
}

function install_docker() {
    curl -fsSL https://get.docker.com | bash -
    ## sudo sh -c "$(wget https://get.docker.com -O -)" 
    ## curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
    ## apt install docker.io -y
    echo -e "${green}docker is already installed${white}"
}

function install_kubectl() {
    ## sudo snap install kubectl --classic
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    ## curl -s -Lo /usr/local/bin/kubectl "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    ## curl -sLO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/$_platform/amd64/kubectl
    chmod +x ./kubectl
    mv ./kubectl /usr/local/bin/kubectl
    /usr/local/bin/kubectl version --client
    ## kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
    echo -e "${green}kubectl is already installed${white}"
}

function install_kubecolor() {
    KUBECOLOR_VERSION=0.0.20
    curl -sSL https://github.com/hidetatz/kubecolor/releases/download/v${KUBECOLOR_VERSION}/kubecolor_${KUBECOLOR_VERSION}_Linux_x86_64.tar.gz | sudo tar xz -C /usr/local/bin kubecolor
    kubecolor version --client
    echo -e "${green}kubecolor is already installed${white}"
}

function install_helm() {
    echo "Installing Helm"
    curl -s https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    #HELMVERSION=helm-v3.8.1
    #curl -sSL https://get.helm.sh/${HELMVERSION}-linux-amd64.tar.gz | sudo tar xz -C /usr/local/bin --strip-components=1 linux-amd64/helm
    helm version --client
    echo -e "${green}Helm is already installed${white}"
}

function install_minikube() {
    echo "Installing Minikube"
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    #MINIKUBEVERESION=
    #curl -sSL "https://storage.googleapis.com/minikube/releases/${MINIKUBEVERESION#minikube-}/minikube-linux-amd64"
    minikube version
    echo -e "${green}Minikube is already installed${white}"
}

function install_compose() {
    echo "Installing docker-compose"
    ## v2.2.3
    COMPOSE_VESION="1.29.2"
    curl -L "https://github.com/docker/compose/releases/download/${COMPOSE_VESION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    ## curl -L "http://rancher-mirror.cnrancher.com/docker-compose/v1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose 
    docker-compose version
    echo -e "${green}docker-compose is already installed${white}"
}

function change_docker_mirror(){
    ## sudo mkdir -p /etc/docker
    cat >  /etc/docker/daemon.json <<EOF
    {
      "registry-mirrors": [
      "https://docker.mirrors.ustc.edu.cn",
      "http://hub-mirror.c.163.com"
      ]
    }
EOF
      systemctl restart docker
      echo "docker mirror change successful"
}

function install_kind(){
    echo "Installing Kind"
    KIND_VESION="v0.17.0"
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VESION}/kind-linux-amd64
    chmod +x ./kind
    mv ./kind /usr/local/bin/kind
    kind version
    echo -e "${green}kind is already installed${white}"
}

function install_terraform(){
    echo "Installing terraform"
    TERRAFORM_VESION="1.2.5"
    curl -LO https://releases.hashicorp.com/terraform/${TERRAFORM_VESION}/terraform_${TERRAFORM_VESION}_linux_amd64.zip
    unzip terraform_${TERRAFORM_VESION}_linux_amd64.zip
    chmod +x ./terraform
    mv terraform /usr/local/bin
    terraform version
    echo -e "${green}terraform is already installed${white}"
}

## https://cluster-api.sigs.k8s.io/user/quick-start.html
function install_clusterctl(){
    echo "Installing clusterctl"
    #CLUSTERCTL_VESION="1.2.0"
    #curl -L "https://github.com/kubernetes-sigs/cluster-api/releases/download/${CLUSTERCTL_VESION}/clusterctl-linux-amd64" -O ./clusterctl
    curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/v1.2.0/clusterctl-linux-amd64 -o clusterctl
    chmod +x ./clusterctl
    mv clusterctl /usr/local/bin
    clusterctl version
    echo -e "${green}clusterctl is already installed${white}"
}

## https://krew.sigs.k8s.io/docs/user-guide/setup/install/
function install_krew(){
    echo "Installing krew"
    set -x; cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    KREW="krew-${OS}_${ARCH}" &&\
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" && \
    tar zxvf "${KREW}.tar.gz" && \
    ./"${KREW}" install krew
    cp ~/.krew/bin/kubectl-krew /usr/local/bin/
    export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"
    kubectl krew version
    echo -e "${green}krew is already installed${white}"
}

## install_git
## install_docker
install_kubectl
install_kubecolor
install_helm
install_minikube
install_compose
## change_docker_mirror
install_kind
install_terraform
install_clusterctl
install_krew

