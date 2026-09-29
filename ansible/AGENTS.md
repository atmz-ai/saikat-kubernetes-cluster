# Agent Guidelines for Ansible (this directory)

Ansible-specific rules. Repo-wide rules live in the root `AGENTS.md`; this file carries
only what is particular to working inside `ansible/`, and exists so those rules sit
next to the code they govern.

## Prefer collection modules over raw `uri` / `command` (Hard Rule)

**If a maintained collection module exists for the API or system being touched, use
it — never hand-roll the HTTP request.** Collection modules carry retries, rate-limit
handling, `check_mode` support, idempotency logic and error decoding that a raw `uri`
call does not, and their maintainers test them across versions. That is work we do not
have to redo, and cannot validate as thoroughly ourselves.

`community.hrobot` covers the Hetzner Robot API comprehensively — `server`,
`server_info`, `firewall`, `failover_ip`, `ssh_key`, `reverse_dns`, **`v_switch`**,
`reset`, `storagebox*`. Check before writing any Robot API call.

**Check availability first, and read the module's own docs for parameter names** — do
not assume the shape:

```sh
ls ansible/collections/ansible_collections/<namespace>/<collection>/plugins/modules/
sed -n '/^DOCUMENTATION/,/^EXAMPLES/p' ansible/collections/ansible_collections/community/hrobot/plugins/modules/v_switch.py
```

Two concrete traps found the hard way while writing the vSwitch role:

- **`hetzner_user` / `hetzner_password`**, NOT `api_user` / `api_key` (which is what
  the Namecheap role uses — different API, different names).
- **`servers:` is the list of server identifiers to ADD to the vSwitch.** An empty or
  omitted `servers` does not mean "no change" — it means *no servers added*, so a bare
  create and a create-with-membership are the same call. Omitting it on a
  `state: present` task is correct for creation and wrong for membership.

### Raw `uri` is legacy, not precedent

Roles that call an API with `ansible.builtin.uri` (e.g. `provision` against
`robot-ws.your-server.de`) predate the collection being vendored here. **They are not
a pattern to copy.** When you touch such a call, convert it in the same change.

Fall back to `uri`/`command` **only** when no module exists — and say so in a comment
at the task, naming what you checked, so the next reader does not have to re-derive it.

## Hand-rolled HTTP error handling is a smell

A raw `curl`/`uri` call needs its own status handling and body parsing, and getting
that wrong fails silently. Observed while adding a server to a Hetzner vSwitch by
hand (that role has since been removed, but the lesson is general):

```sh
curl -s -X POST .../vswitch/86224/server --data-urlencode "server=2863794"
# HTTP/2 201, content-length: 0
```

The call **succeeded** (201, empty body) but a `json.load` on the response body threw,
and the follow-up "did it work?" check reported `none` — because the membership takes
a moment to appear. Two false negatives in a row, from code that looked like it was
checking. A collection module returns a structured result and handles the empty-body
201 itself; this is exactly the class of bug the Hard Rule above exists to prevent.

## Duplicate YAML keys are silent — and untested in `.j2` templates

A YAML mapping with a key repeated within it keeps only the **last** occurrence. A second
`extraArgs:` block under kubeadm's `etcd` does not merge — it *replaces* the first, so the
dropped args vanish with no error anywhere. This happened: the etcd listen URLs never
reached a node, which is invisible on Hetzner (the public IP is on the interface) and
fatal on a NAT'd cloud VM.

`ansible-lint` already has `yaml[key-duplicates]` and it catches this in `.yml`/`.yaml`.
**It does not check `.j2` templates** (verified: the same duplicate key is a failure in a
`.yaml` and passes silently in a `.j2`). `ansible/manifests/kubeadm-cluster-configuration.yaml.j2`
is the file that matters here, so check it by hand when editing it — render it and parse
the result, or read the rendered output:

```sh
./.venv/bin/python3 -c "
import yaml,sys; from jinja2 import Environment,FileSystemLoader
e=Environment(loader=FileSystemLoader('ansible/manifests'),trim_blocks=True,lstrip_blocks=True)
yaml.safe_load(e.get_template('kubeadm-cluster-configuration.yaml.j2').render(
    kubernetes_version='1.36.4', control_plane_endpoint='x:6443', pod_network_cidr='10.244.0.0/16',
    service_node_port_range='30000-32767', etcd_heartbeat_interval_milliseconds=250,
    etcd_election_timeout_milliseconds=2500, api_server_cert_sans=['x']))
print('renders as valid YAML')"
```

Note `yaml.safe_load` cannot detect the duplicate itself — it drops the key while parsing.
Only `yaml.compose_all` (which walks the node graph) or ansible-lint's own check sees it.

## Secrets and vault

- Ansible vault is the source for cluster-ops secrets; roles consume `vault_*` vars.
- Use the mise tasks (`mise run ansible-vault-view -- <key>`) rather than piping
  `ansible-vault view` through `grep` — see the root `AGENTS.md`.
- Never edit a SOPS file outside `sops`; a stray edit breaks the MAC.

## Running things

Use the mise tasks, never `ansible-playbook` / `ansible-lint` / `ansible-vault`
directly (the root `AGENTS.md` lists them). They ensure the `.venv` is used, the
vault password file is found via `ansible.cfg`, and runs are reproducible.

Run playbooks in the foreground. Lint before PRs: `mise run ansible-lint`.

## Waiting

Short poll loops (≤10s sleep) when waiting for something to converge. Never a long
`sleep` — poll, re-check, or stop and let the operator reinitiate.

## Roles and playbooks

The structural rules (atomic roles, thin playbooks, no `include_role` inside roles,
immutable nodes, per-component verification) are in the root `AGENTS.md` under
"Core Architecture Principles" and "Deployment / Upgrade Workflow". They are not
repeated here.

## Inventory: one node list, derived role groups

Every node is declared **once** in `ansible/inventory/00-hosts.yml` under a single
`nodes:` group. `control_plane` and `worker_nodes` are **derived** from each host's
`node_role` by `ansible/inventory/10-role-groups.yml` (the `constructed` inventory
plugin), so the two views cannot drift from the list — which a hand-maintained second
list could not guarantee.

**One operation per lifecycle stage, not one per node kind.** `add-node.yml` and
`upgrade-node.yml` each handle both control planes and workers; the host's `node_role`
decides which roles run. This replaced `add-worker`/`add-control-plane` and
`upgrade-worker`/`upgrade-control-plane`, which had already drifted apart (different
`storage-longhorn` placement; only the control-plane path ran `node_provider_address`,
so a cloud *worker* would have joined advertising an address kubelet cannot use).

Attributes, and what each is actually for:

| Attribute | Set on | Means |
|---|---|---|
| `node_role` | every host (workers inherit `worker` from group vars) | control-plane vs worker — drives the derived groups |
| `stacked_control_plane` | every control plane | CP that **also runs workloads** (taint removed). NOT the same fact as `node_role` |
| `provider` | every host | `hetzner` (Robot API + installimage) vs a cloud VM (image is already ready) |

**Traps, each measured rather than assumed:**

- **`node_role` omission is silent for a control plane.** A CP without it inherits
  `worker`, drops out of `control_plane`, and is then left out of the API server endpoint
  records and skipped by the control-plane path — while the node reports Ready. New
  control planes must set both `node_role: control-plane` and `stacked_control_plane: true`.
- **`stacked_control_plane` is not the control-plane marker.** A dedicated CP is a control
  plane *without* it. Use `node_role` to answer "is this a control plane".
- **The plugin's filename is load-bearing.** Ansible loads inventory sources in filename
  order and a plugin only sees hosts from sources loaded *before* it, so the file is named
  `10-` to sort after `00-hosts.yml`. Renamed below that, every derived group comes out
  empty and nothing errors — 0 control planes, 0 workers, playbooks that "succeed" having
  done nothing. `constructed` is also not enabled by default; `inventory_enabled` in
  `ansible.cfg` lists it.
- **A play's `hosts:` cannot be templated from `hostvars`.** It works at runtime but fails
  `--list-hosts` (`'hostvars' is undefined`), which is why the role views exist as groups
  rather than as a `hosts:` expression computed from host attributes. A `when:` can filter
  tasks but cannot select hosts for a play or produce a set for a cluster-wide aggregate
  (`groups['control_plane'][0]` as the kubectl delegate, `loop: groups['worker_nodes']`,
  the etcd quorum count).
