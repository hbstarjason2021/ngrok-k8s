#!/bin/bash

set -eux

red="\033[31m"
green="\033[32m"
yellow="\033[33m"
white="\033[0m"

if [[ "$(whoami)" != "root" ]]; then
	echo "please run this script as root ." >&2
	exit 1
fi

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

function install_kubectl() {
    ## sudo snap install kubectl --classic
    ## curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    curl -sLO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/$_platform/amd64/kubectl
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
    cat >  /etc/docker/daemon.json <<EOF
    {
      "registry-mirrors": ["https://docker.mirrors.ustc.edu.cn"]
    }
EOF
      systemctl restart docker
      echo "docker mirror change successful"
}

function install_kind(){
    echo "Installing Kind"
    KIND_VESION="v0.12.0"
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VESION}/kind-linux-amd64
    chmod +x ./kind
    mv ./kind /usr/local/bin/kind
    kind version
    echo -e "${green}kind is already installed${white}"
}


## install_git
install_kubectl
install_kubecolor
install_helm
install_minikube
install_compose
## change_docker_mirror
install_kind
