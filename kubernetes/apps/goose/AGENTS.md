# Goose Workstation

KubeVirt and cloud-init own the Ubuntu disk, access prerequisites, and initial mise seed. Guest software and services belong in root mise tasks; never introduce a guest Ansible role or controller-side file synchronization workflow.

Mise must be user-writable for self-updates. Its auto-update setting is global-only, as prescribed at https://mise.jdx.dev/installing-mise.html#updating-mise; keep default release-age safeguards. Automatic checks happen during eligible interactive commands, not unattended daemon execution.

Use `mise run workstation-setup` inside the guest, with `workstation-tunnel-login` for first-time human GitHub consent. Start Goose separately with `mise run goose-run`. Preserve existing tunnel credentials, repositories, and sessions during bootstrap changes.

Cloud-init runs once per instance; changing its declaration does not bootstrap an already-running guest. Apply current-guest changes through mise without rebooting or cleaning cloud-init. The public container and its home remain until their separate data migration is validated.