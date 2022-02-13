####################################################
# Requirements:
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

################################################
# 2. Get the external IP of the Ingress service
################################################
export INGRESS_HOST=$(kubectl \
    get svc traefik \
    --namespace kube-system \
    -o=jsonpath='{$.status.loadBalancer.ingress[0].ip}')

export BASE_HOST="$INGRESS_HOST.nip.io"

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
echo "CHECK OUT gitops/platform/argo-workflows.yaml HOST!!!"
echo http://argo-workflows.$BASE_HOST

###############
# GitOps Time
###############
kubectl apply -f bootstrap/init-gitops.yaml

# Sealed Secrets
source bootstrap/creds.sh

kubectl --namespace argo \
    create secret \
    docker-registry regcred \
    --docker-server=$REGISTRY_SERVER \
    --docker-username=$REGISTRY_USER \
    --docker-password=$REGISTRY_TOKEN \
    --docker-email=$REGISTRY_EMAIL \
    --output json \
    --dry-run=client \
    | kubeseal \
        --controller-name=sealedsecrets-sealed-secrets \
        --format yaml \
    | tee gitops/platform/secrets/registry.yaml


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
    | tee gitops/platform/secrets/github.yaml

git add -A
git commit -m "Sealed Secrets"
git push

##############
# KubeVela UX
##############
vela addon enable velaux serviceType=NodePort

vela status addon-velaux -n vela-system --endpoint

# Shutdown
k3d cluster delete mycluster

# TODO:
- Workflow that builds and pushes to DockerHub
    - [Optional] Minio [Helm](https://github.com/minio/minio/tree/master/helm/minio)
        - use the test.yaml workflow

- KubeVela to deploy the apps
    - Annotations: Feature Toggles

- Question: ArgoCD application vs project??

- Argo Events: Build on commit push

- Two apps
    - Only build changes
- Communicate the apps
    - [Pulsar](https://pulsar.apache.org/docs/en/kubernetes-helm/)

- Infra party:
    - Provide a cluster [Civo](https://www.civo.com/pricing)
        - [Optional] Auto join the cluster to KubeVela:
            - Declarative? Crossplane Composite?
    - Deploy apps to the provided cluster


#######
# MISC
#######
kubectl run test \
    --image=alvarocortes/acortes:1.0.0 \
    --image-pull-policy='Always' \
    --rm -it -- /bin/bash
