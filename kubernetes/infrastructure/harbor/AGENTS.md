# Harbor Registry

Harbor at `harbor.saikat.dev` stores custom-built application images. Bootstrap infrastructure images remain on their upstream registries for disaster recovery. Harbor is reconciled by the `infrastructure-harbor` Flux Kustomization.

## Configuration Ownership

Use [kustomization.yaml](kustomization.yaml) and [helmrelease.yaml](helmrelease.yaml) as the sources of truth for chart version, enabled components, storage sizes, and runtime configuration. Do not duplicate those values in documentation or tune defaults without an observed reason.

The admin password is in [harbor-admin-secret.sops.yaml](harbor-admin-secret.sops.yaml). Edit encrypted credentials with the repository's SOPS mise tasks, never a raw text edit. Keep application pull/push credentials and Flux scanning credentials consistent with the registry credentials they actually consume.

Harbor's PostgreSQL database uses a dedicated low-privilege `harbor` role, not CNPG's `postgres` superuser. [databaserole.yaml](databaserole.yaml) owns its password relationship. [harbor-db-grants.yaml](harbor-db-grants.yaml) is also a fresh-bootstrap ownership-transfer input referenced by [cnpg-cluster.yaml](cnpg-cluster.yaml); do not remove it merely because the historical migration Job has finished.

## Browser and Registry Access

The [Harbor HTTPRoute](../../networking/routes/harbor.yaml) sends browser UI requests through `oauth2-proxy-harbor`. Registry `/v2/` and `/service/token` requests go directly to Harbor so container clients can use native registry authentication; do not put browser OAuth redirects in that path.

The shared OAuth credentials are owned by the oauth2-proxy declarations. Its Google OAuth registration must include `https://harbor.saikat.dev/oauth2/callback`. The gateway's exact-email allowlist admits only `saikat@atmz.ai`; Harbor's native registry and browser credentials remain separate.

Use the established application image tasks for local build validation and the shared CI/CD pipeline for production image pushes. Credential input must remain out of chat, command history, and logs. Registry login alone does not prove image push or Kubernetes pull access works.

## Storage, Diagnostics, and Retirement

Registry persistence is declared in the HelmRelease; PostgreSQL persistence is declared in the CNPG Cluster. Inspect PVC usage read-only and declare storage changes in the owning manifests. Do not patch live PVCs or database roles imperatively.

Useful read-only diagnostics include:

```sh
mise exec -- kubectl get statefulset,deployment,pvc -n harbor
mise exec -- kubectl logs -n harbor deployment/harbor-core
mise exec -- kubectl logs -n oauth2-proxy deployment/oauth2-proxy-harbor
```

For authentication failures, distinguish browser OAuth, registry credentials, and database role/password ownership before changing configuration. Removing an application's deployment does not automatically retire its stored registry images or external data; retention and deletion require a separate authorized decision.