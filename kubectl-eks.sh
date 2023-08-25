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
