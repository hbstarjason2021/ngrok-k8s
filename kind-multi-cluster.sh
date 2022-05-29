#!/bin/bash

## https://kind.sigs.k8s.io/docs/user/ingress/

set -eux

set -o errexit
set -o nounset
set -o pipefail

## https://github.com/kubernetes-sigs/kind/releases

KIND_VESION="v0.13.0"
curl -Lo ./kind https://kind.sigs.k8s.io/dl/${KIND_VESION}/kind-linux-amd64
chmod +x ./kind
mv ./kind /usr/local/bin/kind
kind version

#####################################

KUBECONFIG_DIR=${KUBECONFIG_DIR:-"${HOME}/.kube/clusternet"}
KUBECONFIG_FILE=${KUBECONFIG_FILE:-"${HOME}/.kube/clusternet.config"}
PARENT_CLUSTER_NAME=${PARENT_CLUSTER_NAME:-"parent"}
CHILD_1_CLUSTER_NAME=${CHILD_1_CLUSTER_NAME:-"child1"}
CHILD_2_CLUSTER_NAME=${CHILD_2_CLUSTER_NAME:-"child2"}
CHILD_3_CLUSTER_NAME=${CHILD_3_CLUSTER_NAME:-"child3"}
KIND_IMAGE_VERSION=${KIND_IMAGE_VERSION:-"kindest/node:v1.22.0"}

function create_cluster() {
  local cluster_name=${1}
  local kubeconfig=${2}
  local image=${3}

  rm -f "${kubeconfig}"
  kind delete cluster --name="${cluster_name}" 2>&1
  kind create cluster --name "${cluster_name}" --kubeconfig="${kubeconfig}" --image="${image}" 2>&1

  kubectl config rename-context "kind-${cluster_name}" "${cluster_name}" --kubeconfig="${kubeconfig}"
  kind_server="https://$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${cluster_name}-control-plane"):6443"

  kubectl --kubeconfig="${kubeconfig}" config set-cluster "kind-${cluster_name}" --server="${kind_server}"
  echo "Cluster ${cluster_name} has been initialized"
}

function set_docker_desktop_address() {
  local cluster_name=${1}
  local kubeconfig=${2}

  server_url="https://$(docker inspect --format='{{(index (index .NetworkSettings.Ports "6443/tcp") 0).HostIp}}:{{(index (index .NetworkSettings.Ports "6443/tcp") 0).HostPort}}' "${cluster_name}-control-plane")"
  kubectl --kubeconfig="${kubeconfig}" config set-cluster "kind-${cluster_name}" --server="${server_url}"
}

mkdir -p KUBECONFIG_DIR

create_cluster "${PARENT_CLUSTER_NAME}" "${KUBECONFIG_DIR}/${PARENT_CLUSTER_NAME}.config" "${KIND_IMAGE_VERSION}"
PARENT_CLUSTER_SERVER=${kind_server}

create_cluster "${CHILD_1_CLUSTER_NAME}" "${KUBECONFIG_DIR}/${CHILD_1_CLUSTER_NAME}.config" "${KIND_IMAGE_VERSION}"
create_cluster "${CHILD_2_CLUSTER_NAME}" "${KUBECONFIG_DIR}/${CHILD_2_CLUSTER_NAME}.config" "${KIND_IMAGE_VERSION}"
create_cluster "${CHILD_3_CLUSTER_NAME}" "${KUBECONFIG_DIR}/${CHILD_3_CLUSTER_NAME}.config" "${KIND_IMAGE_VERSION}"

# for docker-desktop
if docker version | grep -q "Server: Docker Desktop"; then
   set_docker_desktop_address "${PARENT_CLUSTER_NAME}" "${KUBECONFIG_DIR}/${PARENT_CLUSTER_NAME}.config"
   set_docker_desktop_address "${CHILD_1_CLUSTER_NAME}" "${KUBECONFIG_DIR}/${CHILD_1_CLUSTER_NAME}.config"
   set_docker_desktop_address "${CHILD_2_CLUSTER_NAME}" "${KUBECONFIG_DIR}/${CHILD_2_CLUSTER_NAME}.config"
   set_docker_desktop_address "${CHILD_3_CLUSTER_NAME}" "${KUBECONFIG_DIR}/${CHILD_3_CLUSTER_NAME}.config"
fi
