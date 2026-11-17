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

S3 signatures bind the hostname and request path. Add a TLS alias without Host
rewrites, path rewrites, redirects, or browser-auth proxies. Verify native signed
object reads and a fresh [AWS CLI presigned GET](https://docs.aws.amazon.com/cli/latest/reference/s3/presign.html)
before retiring an old public hostname; confirm no external clients or unexpired
presigned URLs still depend on it. Keep presigned URLs out of logs. In-cluster
backups and Loki continue using Kubernetes Service DNS, not the public Gateway.
