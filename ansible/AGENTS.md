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
