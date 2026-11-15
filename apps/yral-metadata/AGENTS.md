# Metadata Service

The service has no persistence or user-profile operations. Metadata reads/writes,
bulk operations, email/signup updates, device notifications, and registration
mutation endpoints are removed, including `/v2/update_session_as_registered`.
Removed paths return HTTP 404; do not reintroduce successful no-op responses.

`GET /session` verifies an ES256 bearer token from `https://auth.yral.com`, rejects
anonymous and expired tokens, and returns its verified claims in `ApiResult`.
It does not register a user or update a session. `GET /healthz` and the OpenAPI
explorer remain available. Startup requires only `BIND_ADDRESS` and
`YRAL_AUTH_PUBLIC_KEY`; administrative metadata credentials are no longer used.

The client exposes health and token verification only. The types crate retains
independent identity/signature utilities; it has no profile or notification
contracts. Validate all three crates with `mise run yral-metadata-test` and
targeted Cargo checks through `mise exec rust --`.

Swagger UI builds download their archive. For offline validation, use the
documented `SWAGGER_UI_DOWNLOAD_URL=file:///absolute/repository/path/archive.zip`
override with an existing matching archive; do not alter the embedded UI version.
See the [upstream build configuration](https://docs.rs/utoipa-swagger-ui/latest/utoipa_swagger_ui/#build-config).

Deployment cleanup is a separate GitOps change: retire obsolete backend/admin
environment and secret references after auditing consumers. Retain this service
only while consumers need its token-verification endpoint or identity library.
