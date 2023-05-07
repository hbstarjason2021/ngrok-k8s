kubectl apply \
    --namespace argocd \
    --filename https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml &&
kubectl get secret argocd-initial-admin-secret \
    --namespace argocd \
    --output jsonpath="{.data.password}" \
    | base64 --decode \
    && echo
