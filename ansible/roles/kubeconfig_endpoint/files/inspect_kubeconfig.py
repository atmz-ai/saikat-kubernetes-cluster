import base64
import copy
import hashlib
import json
import subprocess
import sys


def inspect_kubeconfig(configuration):
    contexts = [context for context in configuration["contexts"]
                if context["name"] == configuration["current-context"]]
    if len(contexts) != 1:
        raise ValueError("Expected exactly one current kubeconfig context")
    cluster_name = contexts[0]["context"]["cluster"]
    clusters = [cluster for cluster in configuration["clusters"] if cluster["name"] == cluster_name]
    if len(clusters) != 1:
        raise ValueError("Expected exactly one cluster for the current context")
    cluster = clusters[0]["cluster"]
    if cluster.get("insecure-skip-tls-verify", False):
        raise ValueError("Refusing a kubeconfig that disables TLS verification")
    authority = base64.b64decode(cluster["certificate-authority-data"], validate=True)
    if not authority:
        raise ValueError("Current cluster has no pinned certificate authority")
    non_endpoint_configuration = copy.deepcopy(configuration)
    for entry in non_endpoint_configuration["clusters"]:
        if entry["name"] == cluster_name:
            del entry["cluster"]["server"]
    return {
        "cluster_name": cluster_name,
        "server": cluster["server"],
        "authority_sha256": hashlib.sha256(authority.strip()).hexdigest(),
        "non_endpoint_sha256": hashlib.sha256(json.dumps(
            non_endpoint_configuration, sort_keys=True, separators=(",", ":")).encode()).hexdigest(),
    }


if __name__ == "__main__":
    result = subprocess.run(["kubectl", "config", "view", "--raw", "--flatten", "--kubeconfig", sys.argv[1], "-o", "json"],
                            capture_output=True, text=True, check=False)
    if result.returncode:
        raise RuntimeError("Native kubeconfig inspection failed: " + result.stderr)
    print(json.dumps(inspect_kubeconfig(json.loads(result.stdout))))
