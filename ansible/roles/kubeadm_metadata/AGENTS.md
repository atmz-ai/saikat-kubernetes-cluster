# Kubeadm Metadata Publication

Publish the canonical ClusterConfiguration through kubeadm's upload-config phase
only after all serving certificates and the explicit endpoint DNS are verified.
This role changes metadata, not static manifests, certificates or etcd membership.
Administrative kubeconfig cutover follows publication as a separate serial step.
