# NetBird

Deploy the combined server and dashboard through Flux. Preserve independent
public-IP SSH; NetBird is not the cluster's node-to-node transport.

The [versioned server config](https://github.com/netbirdio/netbird/blob/v0.83.1/combined/config.yaml.example)
and [Google integration](https://docs.netbird.io/selfhosted/identity-providers/managed/google-workspace)
are the authoritative contracts. Google is a native embedded-IdP connector,
not an oauth2-proxy layer around the dashboard or peer APIs. Preserve mandatory
approval for additional users; the initial owner is the operator's exact email.

Run `mise run netbird-contract-generate` when upgrading the server. It downloads
the complete byte-verbatim OpenAPI document and uses
[datamodel-code-generator](https://datamodel-code-generator.koxudaxi.dev/openapi/)
to generate standard-library TypedDict bindings. Do not edit generated models
or maintain a subset of the upstream contract. Run `mise run netbird-checks`
and `mise run renovate-configuration-checks` before deployment.

The bootstrap Job creates the owner and configures Google using the official
API. Its PAT is persisted with mode 0600 on the encrypted Longhorn volume and
expires after 365 days. Preserve it in volume backups. Before rerunning bootstrap
after expiration, rotate the token through a reviewed declarative workflow;
never discard the database to repeat initial setup. A lost token after setup
is an explicit recovery failure, not permission to create another account.

The separate exposure Kustomization depends on successful bootstrap so an
unclaimed setup endpoint is never public. Google Cloud's existing client must
include `https://netbird.saikat.dev/oauth2/callback`; changing this existing
console-managed client is an operator-approved exception to GitOps. Preserve
all of its other callback URLs and do not rotate its shared secret.

STUN needs public UDP 3478 independently of HTTPS. Coturn runs STUN-only on
every node's host network so Cilium's cross-node SNAT cannot corrupt the mapped
device address. The operator-approved Ansible firewall fallback uses
`reconcile-netbird-firewall.yml`; Kubernetes cannot configure the Azure NSG.
Verify STUN binding responses at every authoritative public address,
not only DaemonSet readiness. gRPC uses a separate h2c Service; relay WebSockets
and signal streams require unlimited request timeouts on their routes.
