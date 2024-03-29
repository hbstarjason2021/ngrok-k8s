#!/usr/bin/env sh

#### https://github.com/gravitational/teleport/blob/master/examples/k8s-auth/get-kubeconfig.sh

set -eux

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

## USER=$1
USER="${USE:-zhang-sa}"
## NAMESPACE="${NAMESPACE:-default}"
NAMESPACE="${NAMESPACE:-default}"

##############
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${NAMESPACE}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ${USER}
  namespace: ${NAMESPACE}
EOF

##############
SA_SECRET_NAME=$(kubectl get -n ${NAMESPACE} sa/${USER} -o "jsonpath={.secrets[0]..name}")
if [ -z $SA_SECRET_NAME ]
then
# Create the secret and bind it to the desired SA
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: ${USER}
  namespace: ${NAMESPACE}
  annotations:
    kubernetes.io/service-account.name: "${USER}"
EOF

SA_SECRET_NAME=${USER}
fi

#################
SA_TOKEN=$(kubectl get -n ${NAMESPACE} secrets/${SA_SECRET_NAME} -o "jsonpath={.data['token']}" | base64 --decode)
CA_CERT=$(kubectl get -n ${NAMESPACE} secrets/${SA_SECRET_NAME} -o "jsonpath={.data['ca\.crt']}")

# Extract cluster IP from the current context
CURRENT_CONTEXT=$(kubectl config current-context)
CURRENT_CLUSTER=$(kubectl config view -o jsonpath="{.contexts[?(@.name == \"${CURRENT_CONTEXT}\"})].context.cluster}")
CURRENT_CLUSTER_ADDR=$(kubectl config view -o jsonpath="{.clusters[?(@.name == \"${CURRENT_CLUSTER}\"})].cluster.server}")

echo "Writing kubeconfig."
cat > kubeconfig <<EOF
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${CA_CERT}
    server: ${CURRENT_CLUSTER_ADDR}
  name: ${CURRENT_CLUSTER}
contexts:
- context:
    cluster: ${CURRENT_CLUSTER}
    user: ${CURRENT_CLUSTER}-${USER}
  name: ${CURRENT_CONTEXT}
current-context: ${CURRENT_CONTEXT}
kind: Config
preferences: {}
users:
- name: ${CURRENT_CLUSTER}-${USER}
  user:
    token: ${SA_TOKEN}
EOF

########

# Create roles
cat <<EOF | kubectl -n "$NAMESPACE" apply -f -
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: limited-user
rules:
  - apiGroups: [""]
    resources:
      - nodes
    verbs:
      - get
      - list
      - watch
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: limited-user
rules:
  - apiGroups:
      - ""
      - apps
      - extensions
    resources:
      - deployments
      - cronjobs
      - jobs
      - secrets
      - services
      - persistentvolumeclaims
      - pods
      - pods/attach
      - pods/exec
      - pods/log
      - configmaps
      - ingresses
    verbs:
      - get
      - list
      - watch
      - create
      - update
      - patch
      - delete
      - edit
      - exec

EOF

# Create role bindings
cat <<EOF | kubectl -n "$NAMESPACE" apply -f -
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $USER-limited-user
subjects:
  - kind: ServiceAccount
    name: $USER
    namespace: $NAMESPACE
roleRef:
  kind: ClusterRole
  name: limited-user
  apiGroup: rbac.authorization.k8s.io
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: $USER-limited-user
subjects:
  - kind: ServiceAccount
    name: $USER
    namespace: $NAMESPACE
roleRef:
  kind: Role
  name: limited-user
  apiGroup: rbac.authorization.k8s.io
EOF
