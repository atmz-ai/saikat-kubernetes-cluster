# Yral Authentication

`yral-auth` is a Leptos application with an Axum SSR server and a hydrated WASM client, deployed at `auth.yral.com`. The application entry view is in `src/app.rs`; server startup is in `src/main.rs`. The root `AGENTS.md` and `apps/AGENTS.md` supply shared engineering and operational rules.

## Build and Local Runtime

Use the root mise tasks, not starter-template installation commands or an application-local environment file.

The shared application/server library builds as `rlib`; `client/` owns the
`cdylib` browser hydration entry. Root Cargo workspace Leptos metadata pairs them,
and build commands select `--project yral-auth`. Do not add `cdylib` to the shared
library: the static musl server target cannot produce that output.

- `mise run yral-auth-build` builds the server with `release-bin` and the WASM client with `release-lib`, including the production authentication-provider features.
- `mise run yral-auth-run` starts the release daemon at `http://localhost:8080`; its health endpoint is `/healthz`.
- `mise run yral-auth-test` runs authentication regression tests without an external database. Tests create their own signing-key fixtures and need no production credentials.
- `mise run yral-auth-image` and `mise run yral-auth-image-run` build and start the container; its local health endpoint is `http://localhost:8082/healthz`.
- `mise run yral-auth-stop` stops the production-config local daemon and container. The separate `yral-auth-dev` daemon belongs to the root `dev` group.

The Rust toolchain is managed at the repository root. Do not install nightly merely because the original Leptos starter template recommended it.

Build output lives in the workspace-root `target/`: the native macOS server is `target/release/yral-auth`, the Linux server is `target/x86_64-unknown-linux-musl/release/yral-auth`, and the client assets are in `target/site`. A standalone distribution requires both server and site assets. Runtime site paths and packaging are defined by `Cargo.toml`, the root mise daemons, and `Dockerfile.buildkit`; do not copy obsolete `target/server/release` paths from the starter template.

## Authentication Contracts

OAuth client registrations and redirect allowlists live in `src/oauth/client_validation/whitelist.rs`. Changes must retain supported clients and reject unauthorized or retired redirects. The colocated tests exercise the retained clients and retired legacy frontend registrations:

```sh
mise exec -- cargo test -p yral-auth --features release-bin --lib oauth::client_validation::tests
```

Configuration and age-encrypted signing credentials remain in the root mise declarations. Required secrets are checked before startup or tests; do not expose private signing keys or replace upstream authentication failures with generic messages.

## Database-Free Authentication

Account management/deletion and AI-account creation are disabled. There are no
account registrations, persistent user mappings, or revocation markers. Verified
provider subjects remain OAuth subjects; anonymous grants use fresh UUIDs, and
authenticated backend clients use `backend:<client_id>` as their stable subject.
ID tokens contain authentication claims only, not database/account extensions.

OAuth CSRF states and signed authorization codes are registered in separate
process-local pending-grant stores with ten-minute expiry. Redemption removes the
entry atomically, after cookie/client/redirect/PKCE validation, so concurrent
requests cannot reuse a grant. A code must have been issued by this process;
a valid signature alone does not make it redeemable. Codes carry random `jti`
values to prevent otherwise identical concurrent logins from sharing a grant.

**Run exactly one serving process/replica with Recreate deployment strategy.**
Never overlap old/new processes or use independent workers behind a load balancer.
Restart loses all pending states/codes, which fail closed and require login again.
Refresh/access/ID tokens remain signed and stateless across restarts while signing
keys remain stable; there is no per-user revocation/deletion API. Keep their
existing audience, issuer, key ID and lifetime policies. `token_use` distinguishes
authorization codes, access, ID and refresh tokens; only `refresh` is accepted by
the refresh endpoint. Legacy refresh tokens without this discriminator require
a fresh login. JWT validation follows the official `jsonwebtoken::Validation`
contract (https://docs.rs/jsonwebtoken/latest/jsonwebtoken/struct.Validation.html);
authorization codes also expire strictly with no clock-skew leeway.

## Deployment

Cluster declarations live in `kubernetes/apps/yral-auth/`; routes live in `kubernetes/networking/routes/`. Use the shared GitOps build and image-automation workflow, and `mise run yral-auth-validate` for read-only production checks.