####################################################
# Requirements:
#   - yq
#   - kubectl 
#   - helm
#   - k3d (k3s-based k8s cluster)
#   - argocd (Argo CD cli)
#   - argo (Argo Workflows cli)
#   - vela (KubeVela cli)
#   - kubeseal (bitnami sealed-secrets cli)
#   - [optional] cue (CUE cli)
#
#   - mc (minio cli)
#

###################################################
# 1. Get a local cluster to use as a control plane
###################################################
k3d cluster create mycluster

# k3d cluster create -p "8081:80@loadbalancer"

################################################
# 2. Get the external IP of the Ingress service
################################################
export INGRESS_HOST=$(kubectl \
    get svc traefik \
    --namespace kube-system \
    -o=jsonpath='{$.status.loadBalancer.ingress[0].ip}')

export BASE_HOST="$INGRESS_HOST.nip.io"
echo $BASE_HOST

####################################
# 3. Install ArgoCD in the cluster
####################################
helm repo add argo \
    https://argoproj.github.io/argo-helm

helm repo update

helm upgrade --install \
    argocd argo/argo-cd \
    --namespace argocd \
    --create-namespace \
    --set server.ingress.hosts="{argo-cd.$BASE_HOST}" \
    --set server.ingress.enabled=true \
    --set server.extraArgs="{--insecure}" \
    --set controller.args.appResyncPeriod=30 \
    --wait

export PASS=$(kubectl \
    --namespace argocd \
    get secret argocd-initial-admin-secret \
    --output jsonpath="{.data.password}" \
    | base64 --decode)

argocd login \
    --insecure \
    --username admin \
    --password $PASS \
    --grpc-web \
    argo-cd.$BASE_HOST

argocd account update-password \
    --current-password $PASS \
    --new-password admin123

echo http://argo-cd.$BASE_HOST
echo "admin:admin123"

##########################
# Setup Secrets and Hosts
##########################
echo "CHECK OUT platform-team/gitops/argo-workflows.yaml HOST!!!"
echo http://argo-workflows.$BASE_HOST

###############
# GitOps Time
###############
kubectl apply -f bootstrap/init.yaml

# Sealed Secrets
source bootstrap/creds.sh

kubectl --namespace argo \
    create secret \
    docker-registry registry-credentials \
    --docker-server=$REGISTRY_SERVER \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_TOKEN \
    --docker-email=$REGISTRY_EMAIL \
    --output json \
    --dry-run=client \
    | kubeseal \
        --controller-name=sealedsecrets-sealed-secrets \
        --format yaml \
    | tee platform-team/gitops/secrets/registry.yaml


echo "apiVersion: v1
kind: Secret
metadata:
  name: github-access
  namespace: argo
type: Opaque
data:
  token: $(echo -n $GH_TOKEN | base64)
  user: $(echo -n $GH_USER | base64)
  email: $(echo -n $GH_EMAIL | base64)" \
    | kubeseal \
        --controller-name=sealedsecrets-sealed-secrets \
        --format yaml \
    | tee platform-team/gitops/secrets/github-argoworkflows.yaml

echo "apiVersion: v1
kind: Secret
metadata:
  namespace: crossplane-system
  name: civo-provider-secret
type: Opaque
data:
  credentials: $(echo -n $CIVO_API_KEY | base64)" \
    | kubeseal \
        --controller-name=sealedsecrets-sealed-secrets \
        --format yaml \
    | tee platform-team/gitops/secrets/civo-provider-secret.yaml

echo "
---

apiVersion: civo.crossplane.io/v1alpha1
kind: ProviderConfig
metadata:
  name: civo-config
  namespace: crossplane-system
spec:
  region: lon1
  credentials:
    source: Secret
    secretRef:
      namespace: crossplane-system
      name: civo-provider-secret
      key: credentials
" >> platform-team/gitops/secrets/civo-provider-secret.yaml


# echo "apiVersion: v1
# kind: Secret
# metadata:
#   name: github-access
#   namespace: argo-events
# type: Opaque
# data:
#   token: $(echo -n $GH_TOKEN | base64)" \
#     | kubeseal \
#         --controller-name=sealedsecrets-sealed-secrets \
#         --format yaml \
#     | tee platform-team/gitops/secrets/github-events.yaml

# echo "apiVersion: v1
# data:
#   PRIVATEKEY: $(echo -n $PULSAR_PRIVATE)
#   PUBLICKEY: $(echo -n $PULSAR_PUBLIC)
# kind: Secret
# type: Opaque
# metadata:
#   name: pulsar-mini-token-asymmetric-key
#   namespace: pulsar" \
#     | kubeseal \
#         --controller-name=sealedsecrets-sealed-secrets \
#         --format yaml \
#     | tee platform-team/gitops/secrets/pulsar-mini-token-asymmetric-key.yaml

# echo "apiVersion: v1
# data:
#   TOKEN: $(echo -n $PULSAR_TOKEN_BROKER)
#   TYPE: $(echo -n $PULSAR_TYPE)
# kind: Secret
# type: Opaque
# metadata:
#   name: pulsar-mini-token-broker-admin
#   namespace: pulsar" \
#     | kubeseal \
#         --controller-name=sealedsecrets-sealed-secrets \
#         --format yaml \
#     | tee platform-team/gitops/secrets/pulsar-mini-token-broker-admin.yaml

# echo "apiVersion: v1
# data:
#   TOKEN: $(echo -n $PULSAR_TOKEN_ADMIN)
#   TYPE: $(echo -n $PULSAR_TYPE)
# kind: Secret
# type: Opaque
# metadata:
#   name: pulsar-mini-token-admin
#   namespace: pulsar" \
#     | kubeseal \
#         --controller-name=sealedsecrets-sealed-secrets \
#         --format yaml \
#     | tee platform-team/gitops/secrets/pulsar-mini-token-admin.yaml

# echo "apiVersion: v1
# data:
#   TOKEN: $(echo -n $PULSAR_TOKEN_PROXY)
#   TYPE: $(echo -n $PULSAR_TYPE)
# kind: Secret
# type: Opaque
# metadata:
#   name: pulsar-mini-token-proxy-admin
#   namespace: pulsar" \
#     | kubeseal \
#         --controller-name=sealedsecrets-sealed-secrets \
#         --format yaml \
#     | tee platform-team/gitops/secrets/pulsar-mini-token-proxy-admin.yaml

git add -A
git commit -m "Sealed Secrets"
git push

##############
# KubeVela UX
##############
# vela addon enable velaux serviceType=NodePort
# vela status addon-velaux -n vela-system --endpoint
# kubectl get app.core.oam.dev -n development

#######
# CIVO Cluster
#######

# Join cluster to ArgoCD
kubectl get secrets cluster-details-civo-london -o yaml \
    | yq eval '.data.kubeconfig' - \
    | base64 -d > civo-london.kubeconfig

argocd cluster add civo-london \
    --kubeconfig civo-london.kubeconfig \
    --yes 

rm civo-london.kubeconfig

# Shutdown
k3d cluster delete mycluster

# TODO:
- Services (Teams):
    - Communicate the apps
        - Pulsar
            https://pulsar.apache.org/docs/en/kubernetes-helm/
            https://github.com/apache/pulsar-helm-chart

        - Document with Async API
    - Play with Prisidio

- Infra party:
    - Provide a cluster [Civo](https://www.civo.com/pricing)
        - [Optional] Auto join the cluster to KubeVela:
            - Declarative? Crossplane Composite?
    - Deploy apps to the provided cluster

- Argo CD:
    - Kustomize instead of Helm charts (https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml)

- Argo Events + Workflows:
    - Build on commit push (https://www.youtube.com/watch?v=XNXJtxkUKeY&t=1088s)
    - https://k3d.io/v5.0.0/usage/exposing_services/

- Argo Workflows:
    - Better workflow that builds, **TESTS** and pushes to DockerHub
    - Minio [Helm](https://github.com/minio/minio/tree/master/helm/minio)

#######
# MISC
#######
kubectl run test \
    --image=alvarocortes/acortes:1.0.0 \
    --image-pull-policy='Always' \
    --rm -it -- /bin/bash
