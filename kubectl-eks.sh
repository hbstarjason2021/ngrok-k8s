#!/bin/bash

function help() {
    echo "Usage: $(basename "$0") [COMMAND] [OPTIONS]"
    echo
    echo "A utility script to retrieve and display information about EKS clusters."
    echo
    echo "Commands:"
    echo "  node, nodes    Get detailed information about nodes in the cluster."
    echo
    echo "Options:"
    echo "  --selector     Specify a node selector to filter the Kubernetes nodes"
    echo
    echo "Examples:"
    echo "  $(basename "$0") nodes                                # Get node info from current context"
    echo "  $(basename "$0") nodes --selector NodePurpose=system  # Get node info for nodes with specific label"
    echo
    echo "Note: This script can be extended to support additional Kubernetes operations and details. Ensure you're operating within the expected cluster context."
    exit 1
}

function hasTools() {
  local COMMANDS ERR
  COMMANDS=(kubectl jq)
  for CMD in "${COMMANDS[@]}"; do
    command -v "$CMD" &>/dev/null || { echo "${CMD} command not found" && ERR=1; }
  done
  if [[ $ERR -gt 0 ]]; then
    exit 1
  fi
}

function isEKS() {
  local SERVER
  SERVER=$(kubectl config view --minify  -ojson | jq -r '.clusters[0].cluster.server')
  if ! [[ "$SERVER" == *"eks.amazonaws.com" ]]; then
    echo "Not an EKS cluster"
    exit 1
  fi
}

function getNodesInfo() {
  kubectl get nodes "$@" -o json | \
  jq -r '["NAME", "STATUS", "REGION", "ZONE", "INTERNAL-IP", "INSTANCE-ID", "INSTANCE-TYPE", "LIFECYCLE", "VERSION"],
         (.items[] | [
                      .metadata.name,
                      (.status.conditions[-1] | if .status == "True" and .type == "Ready" and .reason == "KubeletReady" then "Ready" else "Not Ready" end),
                      (.metadata.labels["topology.kubernetes.io/region"]),
                      (.metadata.labels["topology.kubernetes.io/zone"]),
                      (.status.addresses[] | select(.type=="InternalIP").address),
                      (.spec.providerID | split("/")[-1]),
                      (.metadata.labels["node.kubernetes.io/instance-type"]),
                      (.metadata.labels["node.kubernetes.io/lifecycle"]),
                      (.status.nodeInfo.kubeletVersion)
                    ]) | @tsv' | \
  column -t -s$'\t'
}

case "$1" in
  (node|nodes)
    hasTools
    isEKS
    getNodesInfo "${@:2}"
    ;;
  *)
    help
    ;;
esac

######################################
:<<COMMENT

 kubectl eks nodes
NAME                                    STATUS  REGION     ZONE        INTERNAL-IP  INSTANCE-ID         INSTANCE-TYPE  LIFECYCLE  VERSION
ip-XXXX-161.eu-west-1.compute.internal  Ready   eu-west-1  eu-west-1c  XXXX.161     i-XXXXXXXcafa83983  m5.4xlarge     spot       v1.26.6-eks-a5565ad
ip-XXXX-135.eu-west-1.compute.internal  Ready   eu-west-1  eu-west-1c  XXXX.135     i-XXXXXXX8e13ffb61  c5a.2xlarge    normal     v1.26.6-eks-a5565ad
ip-XXXX-16.eu-west-1.compute.internal   Ready   eu-west-1  eu-west-1c  XXXX.16      i-XXXXXXXddae0f330  m5d.4xlarge    spot       v1.26.6-eks-a5565ad
ip-XXXX-215.eu-west-1.compute.internal  Ready   eu-west-1  eu-west-1c  XXXX.215     i-XXXXXXXf27950a10  m5.4xlarge     spot       v1.26.6-eks-a5565ad
ip-XXXX-115.eu-west-1.compute.internal  Ready   eu-west-1  eu-west-1a  XXXX.115     i-XXXXXXX803ffb76c  c5a.2xlarge    normal     v1.26.6-eks-a5565ad
ip-XXXX-5.eu-west-1.compute.internal    Ready   eu-west-1  eu-west-1a  XXXX.5       i-XXXXXXX321da8a30  c5a.2xlarge    normal     v1.26.6-eks-a5565ad
ip-XXXX-227.eu-west-1.compute.internal  Ready   eu-west-1  eu-west-1a  XXXX.227     i-XXXXXXXb78588f78  m5.4xlarge     spot       v1.26.6-eks-a5565ad
ip-XXXX-37.eu-west-1.compute.internal   Ready   eu-west-1  eu-west-1a  XXXX.37      i-XXXXXXXb15a62d6d  m5d.4xlarge    spot       v1.26.6-eks-a5565ad
ip-XXXX-115.eu-west-1.compute.internal  Ready   eu-west-1  eu-west-1b  XXXX.115     i-XXXXXXXecdd029a7  m5.4xlarge     spot       v1.26.6-eks-a5565ad
ip-XXXX-51.eu-west-1.compute.internal   Ready   eu-west-1  eu-west-1b  XXXX.51      i-XXXXXXXdd7e21638  m5d.4xlarge    spot       v1.26.6-eks-a5565ad
ip-XXXX-53.eu-west-1.compute.internal   Ready   eu-west-1  eu-west-1b  XXXX.53      i-XXXXXXXac39081d5  m5.4xlarge     spot       v1.26.6-eks-a5565ad
ip-XXXX-131.eu-west-1.compute.internal  Ready   eu-west-1  eu-west-1b  XXXX.131     i-XXXXXXXd9afd5ab7  c5a.2xlarge    normal     v1.26.6-eks-a5565ad
ip-XXXX-176.eu-west-1.compute.internal  Ready   eu-west-1  eu-west-1b  XXXX.176     i-XXXXXXX9facd1234  c5a.2xlarge    normal     v1.26.6-eks-a5565ad

COMMENT
