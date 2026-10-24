# PowerDNS Zone Generation

Run `mise run dns-generate` to render inventory-owned DNS manifests locally; commit the output for Flux to apply. Follow the repository root and `ansible/AGENTS.md` operating rules.

Each entry in `pdns_zones` defaults its apex A records to the cluster nodes. For an externally hosted apex, declare `apex_ipv4_addresses` on that zone in [the inventory variables](../../inventory/group_vars/all/vars.yml). Wildcard records, nameserver records, and the DNS Service remain cluster-owned. Never hand-edit the generated apex manifest.

The apex records and zone settings determine the checksum in the ConfigMap and Job names. Changing apex targets creates a new Job on reconciliation; editing only the old ConfigMap would leave its completed Job untouched.

Regression tests exercise task expressions and rendered Job references, including external targets, the cluster default, and changed Job identities:

```sh
mise exec -- .venv/bin/python -m unittest discover -s ansible/roles/pdns-zones/tests -v
```

Validation uses the canonical [Ansible assertion expressions](https://docs.ansible.com/projects/ansible/latest/collections/ansible/builtin/assert_module.html) for generated artifacts. Verify deployment using authoritative DNS queries, not only Flux readiness.