# Application Deployment Declarations

Each application owns a directory here containing its Namespace, workload, Services, configuration, encrypted Secrets, and application-specific routing grants or build resources. Application source lives separately in the root `apps/<application>/` tree and may be in-repo or an independent submodule. Follow the root and parent Kubernetes `AGENTS.md` rules.

## Onboarding

1. Create the application's `kustomization.yaml` and its required manifests in `kubernetes/apps/<application>/`.
2. Declare a dedicated Flux Kustomization in `kubernetes/clusters/yral-k8s/app-<application>.yaml`, pointing to the application directory and declaring its dependencies and decryption requirements.
3. Include that Flux CR in `kubernetes/clusters/yral-k8s/kustomization.yaml`. There is no shared `kubernetes/apps/kustomization.yaml` entry point.
4. Add routes to `kubernetes/networking/routes/` and ReferenceGrants to each cross-namespace backend's target namespace. Register them in their owning resource lists.
5. Configure image pull credentials and, for custom-built applications, the existing Shipwright/Tekton/Harbor/Flux image-automation workflow described in the root `AGENTS.md`.
6. Validate local builds, tests, runtime, images, and affected manifests before pushing; then verify reconciliation and application health in production.

Shared cluster-scoped resources and shared Secrets must be declared once, not duplicated across application directories. Removing an application does not authorize deletion of shared services, credentials, or stored data. Follow the parent's two-stage procedure when retiring its Flux Kustomization.