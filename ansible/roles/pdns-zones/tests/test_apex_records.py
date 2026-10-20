import hashlib
import json
import re
from pathlib import Path
import unittest

from jinja2 import Environment
import yaml


ROLE_DIRECTORY = Path(__file__).resolve().parents[1]


class ApexRecordsTests(unittest.TestCase):
    def setUp(self):
        self.environment = Environment()
        self.environment.filters["hash"] = lambda value, algorithm: hashlib.new(
            algorithm, value.encode()
        ).hexdigest()
        self.environment.filters["regex_replace"] = lambda value, pattern, replacement: re.sub(
            pattern, replacement, value
        )
        self.environment.filters["to_json"] = json.dumps
        self.environment.filters["comment"] = lambda value: "# " + value
        tasks = yaml.safe_load((ROLE_DIRECTORY / "tasks/main.yml").read_text())
        self.expressions = {
            name: expression
            for task in tasks
            for name, expression in task.get("ansible.builtin.set_fact", {}).items()
        }
        self.node_addresses = ["20.198.74.224", "20.219.32.205", "20.235.109.17"]
        self.external_addresses = ["20.219.36.211", "20.219.222.27", "20.235.107.58"]

    def test_external_apex_excludes_cluster_addresses_and_changes_job_identity(self):
        previous_zone = {"name": "oleole.ai", "snapshot": False}
        external_zone = dict(previous_zone, apex_ipv4_addresses=self.external_addresses)
        rendered_manifests = []
        checksums = []
        for zone in [previous_zone, external_zone]:
            with self.subTest(zone=zone):
                record_lines = yaml.safe_load(
                    self.environment.from_string(
                        self.expressions["pdns_apex_record_lines"]
                    ).render(
                        zone=zone,
                        pdns_all_node_ips=self.node_addresses,
                        pdns_nameservers=[{"prefix": "ns1"}],
                    )
                )
                checksum = self.environment.from_string(
                    self.expressions["pdns_apex_checksum"]
                ).render(pdns_apex_record_lines=record_lines, pdns_zones=[zone])
                checksums.append(checksum)
                self.assertEqual(len(checksum), 12)
                manifest = self.environment.from_string(
                    (ROLE_DIRECTORY / "templates/pdns-apex-records.yaml.j2").read_text()
                ).render(
                    ansible_managed="Ansible managed",
                    pdns_apex_record_lines=record_lines,
                    pdns_apex_checksum=checksum,
                )
                configuration, job = list(yaml.safe_load_all(manifest))
                expected_name = "pdns-apex-records-" + checksum
                self.assertEqual(configuration["metadata"]["name"], expected_name)
                self.assertEqual(job["metadata"]["name"], expected_name)
                self.assertEqual(
                    job["spec"]["template"]["spec"]["volumes"][0]["configMap"]["name"],
                    expected_name,
                )
                rendered_manifests.append(configuration["data"]["apex-records"])
        self.assertNotEqual(checksums[0], checksums[1])
        self.assertIn("|A|300|" + " ".join(self.node_addresses), rendered_manifests[0])
        self.assertIn("|A|300|" + " ".join(self.external_addresses), rendered_manifests[1])
        for address in self.node_addresses:
            self.assertNotIn(address, rendered_manifests[1])
        self.assertIn("oleole.ai|oleole.ai|NS|300|ns1.oleole.ai", rendered_manifests[1])

    def test_inventory_retains_requested_external_apex(self):
        repository_directory = ROLE_DIRECTORY.parents[2]
        inventory = yaml.safe_load(
            (repository_directory / "ansible/inventory/group_vars/all/vars.yml").read_text()
        )
        zone = next(zone for zone in inventory["pdns_zones"] if zone["name"] == "oleole.ai")
        self.assertEqual(zone["apex_ipv4_addresses"], self.external_addresses)
        self.assertFalse(set(zone["apex_ipv4_addresses"]) & set(self.node_addresses))


if __name__ == "__main__":
    unittest.main(verbosity=2)
