# Bootstrap
Automatically provide all things needed to start the party:

- K8s Cluster (control plane)
- Code Repository
- Artifact Registry

...and start it:

- ArgoCD
  - then Crossplane
  - then Argo Workflows & Events
  - then KubeVela
---

script that:
  - setups everything
  - stops everything

dependencies:
  - docker (or local k8s cluster to run containers)
    - aws cli
    - gcloud cli
    - terraform
    - helm
    - kubectl

inputs:
  - creds
  - urls
  - ...
