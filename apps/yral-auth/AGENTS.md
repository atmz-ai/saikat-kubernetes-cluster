# Yral Authentication

`yral-auth` is a Leptos application with an Axum SSR server and a hydrated WASM client, deployed at `auth.yral.com`. The application entry view is in `src/app.rs`; server startup is in `src/main.rs`. The root `AGENTS.md` and `apps/AGENTS.md` supply shared engineering and operational rules.

## Build and Local Runtime

Use the root mise tasks, not starter-template installation commands or an application-local environment file.

- `mise run yral-auth-build` builds the server with `release-bin` and the WASM client with `release-lib`, including the production authentication-provider features.
- `mise run yral-auth-run` starts the release daemon at `http://localhost:8080`; its health endpoint is `/healthz`.
- `mise run yral-auth-test` runs tests with the authenticated local SpacetimeDB daemon and fnox-injected secrets.
- `mise run yral-auth-image` and `mise run yral-auth-image-run` build and start the container; its local health endpoint is `http://localhost:8082/healthz`.
- `mise run yral-auth-stop` stops the production-config local daemon and container. The separate `yral-auth-dev` daemon belongs to the root `dev` group.

The Rust toolchain is managed at the repository root. Do not install nightly merely because the original Leptos starter template recommended it.

Build output lives in the workspace-root `target/`: the native macOS server is `target/release/yral-auth`, the Linux server is `target/x86_64-unknown-linux-musl/release/yral-auth`, and the client assets are in `target/site`. A standalone distribution requires both server and site assets. Runtime site paths and packaging are defined by `Cargo.toml`, the root mise daemons, and `Dockerfile.buildkit`; do not copy obsolete `target/server/release` paths from the starter template.

## Authentication Contracts

OAuth client registrations and redirect allowlists live in `src/oauth/client_validation/whitelist.rs`. Changes must retain supported clients and reject unauthorized or retired redirects. The colocated tests exercise the retained clients and retired legacy frontend registrations:

```sh
mise exec -- cargo test -p yral-auth --features release-bin --lib oauth::client_validation::tests
```

Configuration and signing credentials remain in the root mise/fnox declarations. Do not expose private signing keys or replace upstream authentication failures with generic messages.

## Deployment

Cluster declarations live in `kubernetes/apps/yral-auth/`; routes live in `kubernetes/networking/routes/`. Use the shared GitOps build and image-automation workflow, and `mise run yral-auth-validate` for read-only production checks. Local execution does not imply permission to mutate the production SpacetimeDB database.