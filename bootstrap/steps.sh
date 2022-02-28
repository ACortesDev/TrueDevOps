####################################################
# Requirements:
#   - yq
#   - kubectl 
#   - helm
#   - k3d (k3s-based k8s cluster)
#   - argocd (Argo CD cli)
#   - argo (Argo Workflows cli)
#   - kubeseal (Bitnami's Sealed-secrets cli)
#   - cue (CUE cli)
#   - mc (Minio cli)

###################################################
# 1. Get a local cluster to use as a control plane
###################################################
k3d cluster create mycluster

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

sleep 5

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

git add -A
git commit -m "Sealed Secrets"
git push

################
# CIVO Cluster
################
# Join cluster to ArgoCD
kubectl get secrets -n crossplane-system cluster-details-product-team-a -o yaml \
    | yq eval '.data.kubeconfig' - \
    | base64 -d > product-team-a.kubeconfig

argocd cluster add product-team-a \
    --kubeconfig product-team-a.kubeconfig \
    --yes

k get deploy,po -A --kubeconfig product-team-a.kubeconfig

# Shutdown
k3d cluster delete mycluster

#######
# MISC
#######
kubectl run test \
    --image=alvarocortes/acortes:1.0.0 \
    --image-pull-policy='Always' \
    --rm -it -- /bin/bash

############################
# TODO:
# - Infra related:
#     - Test changing cluster node pool size when already running
#     - Auto-add crossplane clusters to ArgoCD
#     - Auto-rm crossplane cluters from ArgoCD
#
# - Argo Events + Workflows:
#     - Build on commit push (https://www.youtube.com/watch?v=XNXJtxkUKeY&t=1088s)
#     - https://k3d.io/v5.0.0/usage/exposing_services/
#
# - Argo Workflows:
#     - Better workflow that builds, **TESTS** and pushes to DockerHub
#     - Minio [Helm](https://github.com/minio/minio/tree/master/helm/minio)
#
# - Improvements:
#     - Controllers in their HA version. Kustomize instead of Helm charts (https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml)
#