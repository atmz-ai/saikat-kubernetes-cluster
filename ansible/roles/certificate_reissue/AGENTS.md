# API Serving Certificate Reissuance

This role is an explicitly approved, one-time serving-certificate operation, not
a node replacement or a recurring certificate backfill. Use
[reissue-api-serving-certificates.yml](../../playbooks/operations/reissue-api-serving-certificates.yml)
with one target at a time, or its serial control-plane default.

The ClusterConfiguration comes from the canonical kubeadm template. Preserve
every existing SAN, the existing cluster CA, node identity, etcd membership and
all storage. Generate and validate a candidate before stopping the API server.
Private keys stay on the node; controller-side crypto modules receive public
certificates only.

Only the API static manifest is temporarily removed. Recovery copies live
outside the manifest watch directory, with private material protected by root
permissions. Activation failure restores the old pair and manifest, verifies
recovery, and aborts the serial play. Candidate CA copies are always removed.

Verify the real serving certificate fingerprint, all SANs, readiness and etcd
health before proceeding. Do not publish API DNS or change clients until all
serving nodes pass. Keep the original-pair backups until cutover is confirmed.
