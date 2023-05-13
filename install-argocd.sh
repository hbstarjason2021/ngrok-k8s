kubectl create namespace argocd

kubectl apply \
    --namespace argocd \
    --filename https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml &&
kubectl get secret argocd-initial-admin-secret \
    --namespace argocd \
    --output jsonpath="{.data.password}" \
    | base64 --decode \
    && echo

### kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

### https://killercoda.com/mabusaa/course/argocd-endusers-scenarios/01-setting-up-argocd
