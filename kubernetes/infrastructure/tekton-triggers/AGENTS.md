# Tekton Triggers

Keep the vendored release and interceptor declarations aligned with one explicit
release from the [official installation manifests](https://tekton.dev/docs/triggers/install/).
An image-only update is not a complete release upgrade. Run
`mise run tekton-triggers-configuration-checks` before deploying changes.

The startup ConfigMap in `config/` has its own Flux Kustomization. Keep it outside
the admission-resource reconciliation unit: a webhook that cannot start must not
block the all-resource dry-run needed to create its own configuration.
