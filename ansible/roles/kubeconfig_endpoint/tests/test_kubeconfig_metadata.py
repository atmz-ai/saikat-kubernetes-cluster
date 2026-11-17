import base64
import copy
import importlib.util
import json
from pathlib import Path
import unittest


ROLE_DIRECTORY = Path(__file__).resolve().parents[1]
SPECIFICATION = importlib.util.spec_from_file_location("kubeconfig_metadata", ROLE_DIRECTORY / "files/inspect_kubeconfig.py")
METADATA = importlib.util.module_from_spec(SPECIFICATION)
SPECIFICATION.loader.exec_module(METADATA)


class KubeconfigMetadataTests(unittest.TestCase):
    def setUp(self):
        self.configuration = {
            "current-context": "administrator",
            "contexts": [{"name": "administrator", "context": {"cluster": "cluster", "user": "administrator"}}],
            "clusters": [
                {"name": "cluster", "cluster": {"server": "https://kubernetes-api.yral.com:6443",
                                                 "certificate-authority-data": base64.b64encode(b"public-ca\n").decode()}},
                {"name": "unrelated", "cluster": {"server": "https://unrelated.example.invalid"}},
            ],
            "users": [{"name": "administrator", "user": {"client-key-data": "private-fixture-key"}}],
        }

    def test_only_the_selected_server_can_change_without_changing_the_protected_fingerprint(self):
        original = METADATA.inspect_kubeconfig(self.configuration)
        updated = copy.deepcopy(self.configuration)
        updated["clusters"][0]["cluster"]["server"] = "https://kubernetes-api.saikat.dev:6443"
        result = METADATA.inspect_kubeconfig(updated)
        self.assertEqual(original["non_endpoint_sha256"], result["non_endpoint_sha256"])
        self.assertEqual(original["authority_sha256"], result["authority_sha256"])
        self.assertEqual(result["server"], "https://kubernetes-api.saikat.dev:6443")
        self.assertNotIn("private-fixture-key", json.dumps(result))
        for scenario in ("client-key", "unrelated-cluster"):
            candidate = copy.deepcopy(updated)
            if scenario == "client-key":
                candidate["users"][0]["user"]["client-key-data"] = "changed-key"
            else:
                candidate["clusters"][1]["cluster"]["server"] = "https://changed.example.invalid"
            self.assertNotEqual(original["non_endpoint_sha256"], METADATA.inspect_kubeconfig(candidate)["non_endpoint_sha256"])

    def test_ambiguous_context_and_insecure_clients_are_rejected(self):
        for scenario in ("missing-context", "duplicate-context", "duplicate-cluster", "insecure", "empty-ca"):
            candidate = copy.deepcopy(self.configuration)
            if scenario == "missing-context":
                candidate["current-context"] = "missing"
            elif scenario == "duplicate-context":
                candidate["contexts"].append(copy.deepcopy(candidate["contexts"][0]))
            elif scenario == "duplicate-cluster":
                candidate["clusters"].append(copy.deepcopy(candidate["clusters"][0]))
            elif scenario == "insecure":
                candidate["clusters"][0]["cluster"]["insecure-skip-tls-verify"] = True
            else:
                candidate["clusters"][0]["cluster"]["certificate-authority-data"] = ""
            with self.subTest(scenario=scenario), self.assertRaises(ValueError):
                METADATA.inspect_kubeconfig(candidate)


if __name__ == "__main__":
    unittest.main(verbosity=2)
