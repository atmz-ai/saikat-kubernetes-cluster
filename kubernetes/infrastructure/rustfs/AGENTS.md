# RustFS Declarations

Console and S3 exposure are independent. A Console hostname change updates the
browser origin and named-provider callback in [helmrelease.yaml](helmrelease.yaml)
and the Google client's exact authorized callback before rollout. Preserve the
S3 route and storage declarations until their own migration is approved.

Follow the [native OIDC contract](https://docs.rustfs.com/en/security-compliance/oidc).
Authentication does not grant authorization: retain the IAM policy and Console
Service routing in [google-authorization.yaml](google-authorization.yaml).
Validate real login and administrator reads before retiring the old route,
listener and callback. Update the dashboard shortcut only after that verification.
