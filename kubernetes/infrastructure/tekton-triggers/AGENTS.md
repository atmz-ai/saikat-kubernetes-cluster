# Tekton Triggers

Consume the release and interceptor bundles from one explicit upstream
release from the [official installation manifests](https://tekton.dev/docs/triggers/install/).
Renovate updates both bundles and the startup configuration reference together.
Do not copy bundles or override their images locally. Run
`mise run tekton-triggers-configuration-checks` before deploying changes.

The startup ConfigMap in `config/` has its own Flux Kustomization. Keep it outside
the admission-resource reconciliation unit: a webhook that cannot start must not
block the all-resource dry-run needed to create its own configuration.
