# Kubernetes Declarations

This tree owns Kubernetes workload, networking, operator, and GitOps declarations. Ansible owns provisioning and node lifecycle operations; its bootstrap inputs live in `ansible/manifests/`. Follow the repository-root [operating rules](../AGENTS.md), including the prohibition on imperative mutations of Flux-managed resources.

## Sources of Truth

- [clusters/yral-k8s/kustomization.yaml](clusters/yral-k8s/kustomization.yaml) is the cluster reconciliation entry point. Bootstrap targets this directory, not the whole `kubernetes/` tree.
- `infrastructure/` owns shared operators and infrastructure services.
- `apps/` owns application deployment declarations, separate from application source in the root `apps/` tree.
- [networking/gateway.yaml](networking/gateway.yaml) owns the shared Gateway and its listeners; `networking/routes/` owns service routes.

Ordering is declared through the individual Flux Kustomizations' `dependsOn` fields. Do not substitute manual apply sequences or forced reconciliation for those dependencies.

## Networking and TLS

External traffic reaches the shared Cilium Gateway through inventory-generated DNS and the declared exposure model. Node addresses, regional placement, and component versions are maintained in inventory and manifests, not copied into documentation tables.

Add services through Gateway API routes attached to the appropriate existing listener, with an HTTP-to-HTTPS redirect where needed. Check the Gateway's actual hostname coverage and certificate references before assuming a new hostname is covered. TLS issuance and renewal are managed declaratively by cert-manager; never delete a live certificate Secret to force reissuance.

Cross-namespace backend references require a ReferenceGrant in the target namespace. Follow the root network-policy rules for gateway-originated traffic. Add every new route and grant to its owning Kustomize resource list.

## Validation and Retirement

Render the affected tree locally with `mise exec -- kubectl kustomize <directory>` before pushing. After a push, verify the exact source revision, Kustomization readiness, workload health, and public endpoints. Validate DNS against authoritative nameservers rather than only recursive caches or controller status.

Remove ordinary resources from Git and let Flux prune them. For complete removal of a Flux Kustomization, first reconcile an empty resource set with the CR resumed, verify its inventory and resources are gone, then remove the empty CR. Deleting a suspended CR orphans its resources. Stateful storage and external data require their own explicit retention or migration decision.