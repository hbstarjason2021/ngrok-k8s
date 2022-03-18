#!/bin/bash
set -eux

### https://docs.flagger.app/tutorials/kubernetes-blue-green

kubectl create ns flagger
helm repo add flagger https://flagger.app

helm upgrade -i flagger flagger/flagger \
--namespace flagger \
--set prometheus.install=true \
--set meshProvider=kubernetes
## --set metricsServer=http://prometheus.monitoring:9090
## --set slack.url=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK \
## --set slack.channel=general \
## --set slack.user=flagger


kubectl create ns test

kubectl apply -k https://github.com/fluxcd/flagger//kustomize/podinfo?ref=main

kubectl apply -k https://github.com/fluxcd/flagger//kustomize/tester?ref=main


kubectl apply -f ./podinfo-blue-green-flagger.yaml


### kubectl -n test set image deployment/podinfo  podinfod=ghcr.io/stefanprodan/podinfo:6.0.1

### kubectl -n test describe canary/podinfo

### kubectl get canaries --all-namespaces




