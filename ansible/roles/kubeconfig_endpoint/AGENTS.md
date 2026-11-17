# Administrative Client Endpoint Cutover

Use the native kubeconfig merge editor to change only the active cluster's server
URL. Refuse unrelated CA identities, ambiguous contexts and insecure clients.
Private client material stays on its owning machine: inspection returns public
metadata and a hash of all protected configuration fields, never raw credentials.

Verify the new endpoint before editing, compare protected hashes afterward, and
restore only the previous URL if verification fails. Do not overwrite unrelated
contexts or regenerate client credentials.
