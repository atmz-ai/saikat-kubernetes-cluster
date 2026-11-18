import io
import unittest
import urllib.error
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

import yaml

from exit_node import (
    exit_route,
    group_operation,
    request,
    route_operation,
    select_mac,
    verify_route,
)


class ExitNodeTests(unittest.TestCase):
    def setUp(self):
        self.user = {
            "id": "operator",
            "email": "saikat@atmz.ai",
            "idp_id": "google-operator",
            "role": "admin",
            "is_blocked": False,
        }
        self.mac = {
            "id": "existing-mac",
            "dns_label": "saikats-macbook-pro",
            "os": "Darwin 27.2.1",
            "user_id": "operator",
        }

    def test_selects_only_the_existing_operator_mac(self):
        self.assertEqual(select_mac([self.user], [self.mac]), "existing-mac")
        for peer in (
            dict(self.mac, user_id="someone-else"),
            dict(self.mac, os="Linux"),
            dict(self.mac, dns_label="another-mac"),
        ):
            with self.subTest(peer=peer), self.assertRaises(ValueError):
                select_mac([self.user], [peer])
        with self.assertRaises(ValueError):
            select_mac([self.user], [self.mac, self.mac])
        with self.assertRaises(ValueError):
            select_mac([dict(self.user, is_blocked=True)], [self.mac])

    def test_preserves_exit_group_and_scopes_distribution_to_mac(self):
        existing = {
            "id": "exit-group",
            "name": "cloud-vpn-exit-nodes",
            "peers": [{"id": "router"}],
        }
        self.assertEqual(
            group_operation([existing], existing["name"]), (None, None, existing)
        )
        method, path, body = group_operation([], "cloud-vpn-clients", ["existing-mac"])
        self.assertEqual(
            (method, path, body),
            (
                "POST",
                "/api/groups",
                {"name": "cloud-vpn-clients", "peers": ["existing-mac"]},
            ),
        )
        with self.assertRaises(ValueError):
            group_operation([existing, existing], existing["name"])

    def test_exit_route_is_opt_in_and_not_distributed_to_all(self):
        desired = exit_route("routers", "only-the-mac")
        self.assertEqual(desired["network"], "0.0.0.0/0")
        self.assertTrue(desired["masquerade"])
        self.assertTrue(desired["enabled"])
        self.assertTrue(desired["skip_auto_apply"])
        self.assertEqual(desired["groups"], ["only-the-mac"])
        self.assertEqual(desired["peer_groups"], ["routers"])
        self.assertNotIn("peer", desired)
        self.assertEqual(route_operation([], desired), ("POST", "/api/routes", desired))
        existing = dict(desired, id="route")
        self.assertEqual(
            route_operation([existing], desired), ("PUT", "/api/routes/route", desired)
        )
        verify_route(existing, desired)
        for key, wrong in (
            ("network", "10.0.0.0/8"),
            ("groups", ["All"]),
            ("skip_auto_apply", False),
            ("masquerade", False),
        ):
            with self.subTest(key=key), self.assertRaises(ValueError):
                verify_route(dict(existing, **{key: wrong}), desired)

    def test_upstream_errors_are_verbatim_and_tokens_are_not_logged(self):
        failure = urllib.error.HTTPError(
            "http://fixture",
            403,
            "Forbidden",
            {},
            io.BytesIO(b'{"message":"permission denied"}'),
        )
        output = io.StringIO()
        with (
            patch("urllib.request.urlopen", side_effect=failure),
            redirect_stdout(output),
        ):
            with self.assertRaisesRegex(
                RuntimeError, "NetBird HTTP 403:.*permission denied"
            ):
                request("GET", "/api/groups", "secret-token")
        self.assertNotIn("secret-token", output.getvalue())

    def test_pod_routing_does_not_modify_host_network_or_require_privileges(self):
        documents = list(
            yaml.safe_load_all(Path(__file__).with_name("exit-node.yaml").read_text())
        )
        deployment = next(
            document for document in documents if document["kind"] == "Deployment"
        )
        self.assertEqual(deployment["spec"]["strategy"]["type"], "Recreate")
        specification = deployment["spec"]["template"]["spec"]
        self.assertFalse(specification.get("hostNetwork", False))
        container = specification["containers"][0]
        self.assertFalse(container["securityContext"]["allowPrivilegeEscalation"])
        self.assertEqual(
            container["securityContext"]["capabilities"], {"drop": ["ALL"]}
        )
        self.assertEqual(
            container["readinessProbe"]["exec"]["command"],
            ["netbird", "status", "--check", "ready"],
        )
        policy = next(
            document for document in documents if document["kind"] == "NetworkPolicy"
        )
        denied = policy["spec"]["egress"][0]["to"][0]["ipBlock"]["except"]
        for network in (
            "10.0.0.0/8",
            "172.16.0.0/12",
            "192.168.0.0/16",
            "169.254.0.0/16",
            "100.64.0.0/10",
        ):
            self.assertIn(network, denied)


if __name__ == "__main__":
    unittest.main(verbosity=2)
