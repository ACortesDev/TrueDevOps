# Clusters

## Controller (CTL)

Cluster name: `controller-cluster`
Namespaces:

- `argocd`
- `crossplane-system`
- `argo`
- `argo-events`

## Continuous Integration (CI)

Cluster name: `ci-cluster`
Namespaces:

- `argo-workflows`
- `argo-events`

## Development (DEV)

Cluster name: `development-cluster`
Namespaces:

- `development`: Latest changes.
- `demo`: Frozen image tags.

## Preproduction (PREPROD) aka Staging

Cluster name: `preprod-cluster`

## Production (PROD)

Clusters' names:

- `production-eu`
- `production-us`
- `production-au`
- ...
