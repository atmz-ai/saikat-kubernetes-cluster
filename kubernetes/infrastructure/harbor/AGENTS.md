# Harbor Registry

Harbor at `harbor.saikat.dev` stores custom-built application images. Bootstrap infrastructure images remain on their upstream registries for disaster recovery. Harbor is reconciled by the `infrastructure-harbor` Flux Kustomization.

## Configuration Ownership

Use [kustomization.yaml](kustomization.yaml) and [helmrelease.yaml](helmrelease.yaml) as the sources of truth for chart version, enabled components, storage sizes, and runtime configuration. Do not duplicate those values in documentation or tune defaults without an observed reason.

The admin password is in [harbor-admin-secret.sops.yaml](harbor-admin-secret.sops.yaml). Edit encrypted credentials with the repository's SOPS mise tasks, never a raw text edit. Keep application pull/push credentials and Flux scanning credentials consistent with the registry credentials they actually consume.

Harbor's PostgreSQL database uses a dedicated low-privilege `harbor` role, not CNPG's `postgres` superuser. [databaserole.yaml](databaserole.yaml) owns its password relationship. [harbor-db-grants.yaml](harbor-db-grants.yaml) is also a fresh-bootstrap ownership-transfer input referenced by [cnpg-cluster.yaml](cnpg-cluster.yaml); do not remove it merely because the historical migration Job has finished.

## Browser and Registry Access

Native Google OIDC is declared in [oidc-values.sops.yaml](oidc-values.sops.yaml),
consumed through Helm `core.configureUserSettings`. The chart injects Harbor's
[CONFIG_OVERWRITE_JSON](https://goharbor.io/docs/2.15.0/install-config/configure-system-settings-cli/)
through a checksum-tracked Secret; authentication settings are then read-only in
the UI and must be changed in Git. Switching from database auth requires no added
local users; verify migration eligibility before changing the mode.

The Google client's audience must remain Internal in the atmz.ai Workspace
organization. Native OIDC does not enforce an exact-email allowlist. New Google
users onboard with their email as username and have no automatic system-admin
privileges. Preserve local administrator and robot credentials for registry access.
The native callback is `https://harbor.saikat.dev/c/oidc/callback`.

[operator-administrator.yaml](operator-administrator.yaml) grants system-admin
privileges only to the existing `saikat@atmz.ai` account through Harbor's native
API. It requires an exact username/email match and reads the grant back. It does
not grant administrator privileges to other Workspace users or create accounts.

The [Harbor HTTPRoute](../../networking/routes/harbor.yaml) sends every request
directly to Harbor. Do not reintroduce an oauth2-proxy gateway for this service.
Native browser OIDC and native registry credentials are separate; CLI clients
cannot follow Google login redirects. OIDC users use Harbor's CLI secret, while
the existing local administrator and robot accounts retain their credentials.

Use the established application image tasks for local build validation and the shared CI/CD pipeline for production image pushes. Credential input must remain out of chat, command history, and logs. Registry login alone does not prove image push or Kubernetes pull access works.

## Storage, Diagnostics, and Retirement

Registry persistence is declared in the HelmRelease; PostgreSQL persistence is declared in the CNPG Cluster. Inspect PVC usage read-only and declare storage changes in the owning manifests. Do not patch live PVCs or database roles imperatively.

Useful read-only diagnostics include:

```sh
mise exec -- kubectl get statefulset,deployment,pvc -n harbor
mise exec -- kubectl logs -n harbor deployment/harbor-core
```

For authentication failures, distinguish browser OAuth, registry credentials, and database role/password ownership before changing configuration. Removing an application's deployment does not automatically retire its stored registry images or external data; retention and deletion require a separate authorized decision.

Use an explicitly scoped GitOps Job for approved registry cleanup. Recheck all
declared and live image references, including ReplicaSet rollback images, before
each native API deletion. Retention must protect referenced OCI child manifests
as well as the newest versions. Freeze reviewed artifact digests, tags and push
timestamps; new references or retagging must stop the cleanup, not widen it.

Native [garbage collection](https://goharbor.io/docs/2.15.0/administration/garbage-collection/)
reclaims unreferenced blobs after logical deletion. Disable both untagged and
tagged artifact deletion when collecting blobs for a scoped cleanup, verify the
native execution status and log, and account for its two-hour upload protection
window. Remove the completed cleanup Job and its read-only RBAC from Git after
verification; do not leave a recurring destructive declaration behind.