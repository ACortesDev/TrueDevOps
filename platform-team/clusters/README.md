# Clusters

## Controller (CTL)

Cluster name: `controller-cluster`
Namespaces:

- `argocd`
- `kubevela-system`
- `crossplane-system`

## Continuous Integration (CI)

Cluster name: `ci-cluster`
Namespaces:

- `argo-workflows`
- `argo-events`

## Experimental (EXP)

Cluster name: `experimental-cluster`
Namespaces:

- `development`: Latest changes.
- `demo`: Frozen image tags.

## Preproduction (PREPROD)

Cluster name: `preprod-cluster`

## Production (PROD)

Clusters' names:

- `production-eu`
- `production-us`
