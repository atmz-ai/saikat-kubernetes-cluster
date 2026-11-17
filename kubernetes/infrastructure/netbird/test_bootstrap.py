import copy
import io
import os
import subprocess
import sys
import unittest
import urllib.error
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

import yaml

from api_models import IdentityProviderRequest, SetupRequest
from bootstrap import (
    Phase,
    Request,
    SaveToken,
    account_update,
    main,
    provider_update,
    transition,
)


class BootstrapTests(unittest.TestCase):
    def test_bootstrap_imports_without_site_packages(self):
        directory = str(Path(__file__).parent.resolve())
        subprocess.run(
            [
                sys.executable,
                "-I",
                "-S",
                "-c",
                "import sys; sys.path.insert(0, "
                + repr(directory)
                + "); import bootstrap",
            ],
            check=True,
        )

    def setUp(self):
        self.setup = SetupRequest(
            email="saikat@atmz.ai",
            password="fixture-password",
            name="Operator",
            create_pat=True,
            pat_expire_in=365,
        )
        self.provider = IdentityProviderRequest(
            type="google",
            name="ATMZ Google",
            issuer="https://accounts.google.com",
            client_id="fixture-client",
            client_secret="fixture-secret",
        )
        self.account = {
            "id": "account",
            "settings": {
                "peer_login_expiration": 86400,
                "extra": {"peer_approval_enabled": False},
            },
        }
        self.provider_response = {
            key: value for key, value in self.provider.items() if key != "client_secret"
        } | {"id": "google-fixture"}

    def test_initial_setup_and_restart_use_one_operator(self):
        request = transition(
            Phase.INSTANCE, {"setup_required": True}, self.setup, self.provider, False
        )
        self.assertEqual(
            request, Request(Phase.SETUP, "POST", "/api/setup", self.setup)
        )
        effect = transition(
            Phase.SETUP,
            {"email": "saikat@atmz.ai", "personal_access_token": "nbp_fixture"},
            self.setup,
            self.provider,
            False,
        )
        self.assertEqual(
            effect,
            SaveToken("nbp_fixture", Request(Phase.ACCOUNTS, "GET", "/api/accounts")),
        )
        restarted = transition(
            Phase.INSTANCE, {"setup_required": False}, self.setup, self.provider, True
        )
        self.assertEqual(restarted, Request(Phase.ACCOUNTS, "GET", "/api/accounts"))

    def test_missing_token_or_wrong_operator_never_recreates_owner(self):
        for phase, response in (
            (Phase.INSTANCE, {"setup_required": False}),
            (Phase.INSTANCE, {"setup_required": "false"}),
            (
                Phase.SETUP,
                {"email": "another@atmz.ai", "personal_access_token": "nbp_fixture"},
            ),
            (Phase.SETUP, {"email": "saikat@atmz.ai"}),
        ):
            with (
                self.subTest(phase=phase, response=response),
                self.assertRaises(ValueError),
            ):
                transition(phase, response, self.setup, self.provider, False)

    def test_user_approval_preserves_all_other_settings(self):
        original = copy.deepcopy(self.account)
        request = transition(
            Phase.ACCOUNTS, [self.account], self.setup, self.provider, True
        )
        self.assertIs(request.phase, Phase.ACCOUNT_UPDATED)
        self.assertEqual(request.body["settings"]["peer_login_expiration"], 86400)
        self.assertEqual(
            request.body["settings"]["extra"],
            {"peer_approval_enabled": False, "user_approval_required": True},
        )
        self.assertEqual(self.account, original)
        next_request = transition(
            request.phase,
            {"settings": request.body["settings"]},
            self.setup,
            self.provider,
            True,
        )
        self.assertIs(next_request.phase, Phase.PROVIDERS)

    def test_ambiguous_accounts_and_unpersisted_approval_fail(self):
        for accounts in ([], [self.account, self.account], [{"id": "account"}]):
            with self.subTest(accounts=accounts), self.assertRaises(ValueError):
                account_update(accounts)
        with self.assertRaises(ValueError):
            transition(
                Phase.ACCOUNT_UPDATED, self.account, self.setup, self.provider, True
            )

    def test_google_creation_and_reconciliation_preserve_provider_identity(self):
        created = transition(Phase.PROVIDERS, [], self.setup, self.provider, True)
        self.assertEqual(
            created,
            Request(
                Phase.PROVIDER_UPDATED, "POST", "/api/identity-providers", self.provider
            ),
        )
        updated = provider_update([self.provider_response], self.provider)
        self.assertEqual(updated.method, "PUT")
        self.assertEqual(updated.path, "/api/identity-providers/google-fixture")
        verify = transition(
            created.phase, self.provider_response, self.setup, self.provider, True
        )
        self.assertIs(verify.phase, Phase.PROVIDER_VERIFIED)
        self.assertIsNone(
            transition(
                verify.phase, self.provider_response, self.setup, self.provider, True
            )
        )
        self.assertIsNone(transition(Phase.DONE, {}, self.setup, self.provider, True))

    def test_wrong_or_duplicate_provider_is_never_accepted(self):
        for providers in (
            [self.provider_response, self.provider_response],
            [dict(self.provider_response, name="Another provider")],
            [dict(self.provider_response, type="oidc")],
        ):
            with self.subTest(providers=providers), self.assertRaises(ValueError):
                provider_update(providers, self.provider)
        for key in ("issuer", "client_id", "id"):
            candidate = dict(self.provider_response)
            candidate[key] = "" if key == "id" else "wrong"
            with self.subTest(key=key), self.assertRaises(ValueError):
                transition(
                    Phase.PROVIDER_VERIFIED, candidate, self.setup, self.provider, True
                )

    def test_http_failures_include_upstream_status_and_body(self):
        environment = {
            "NETBIRD_OPERATOR_EMAIL": self.setup["email"],
            "NETBIRD_BOOTSTRAP_PASSWORD": self.setup["password"],
            "NETBIRD_GOOGLE_CLIENT_ID": self.provider["client_id"],
            "NETBIRD_GOOGLE_CLIENT_SECRET": self.provider["client_secret"],
        }
        failure = urllib.error.HTTPError(
            "http://fixture",
            403,
            "Forbidden",
            {},
            io.BytesIO(b'{"message":"provider rejected"}'),
        )
        output = io.StringIO()
        with (
            patch.dict(os.environ, environment),
            patch.object(Path, "exists", return_value=False),
            patch("urllib.request.urlopen", side_effect=failure),
            redirect_stdout(output),
        ):
            with self.assertRaisesRegex(
                RuntimeError, "NetBird HTTP 403:.*provider rejected"
            ):
                main()
        self.assertNotIn(self.provider["client_secret"], output.getvalue())

    def test_request_shapes_match_the_unmodified_contract(self):
        import jsonschema

        contract = yaml.safe_load(Path(__file__).with_name("openapi.yaml").read_text())
        schemas = contract["components"]["schemas"]
        for name, body in (
            ("SetupRequest", self.setup),
            ("IdentityProviderRequest", self.provider),
        ):
            schema = dict(schemas[name], components=contract["components"])
            jsonschema.Draft4Validator(schema).validate(body)

    def test_source_preserving_stun_and_bootstrap_exposure_order(self):
        directory = Path(__file__).parent
        stun, configuration = yaml.safe_load_all((directory / "stun.yaml").read_text())
        self.assertTrue(stun["spec"]["template"]["spec"]["hostNetwork"])
        self.assertIn(
            "stun-only", configuration["data"]["turnserver.conf"].splitlines()
        )
        self.assertNotIn("no-dtls", configuration["data"]["turnserver.conf"])
        self.assertNotIn(
            "--no-dtls", stun["spec"]["template"]["spec"]["containers"][0]["args"]
        )
        services = list(yaml.safe_load_all((directory / "service.yaml").read_text()))
        grpc_service = next(
            service
            for service in services
            if service["metadata"]["name"] == "netbird-grpc"
        )
        self.assertEqual(
            grpc_service["spec"]["ports"][0]["appProtocol"], "kubernetes.io/h2c"
        )
        self.assertNotIn(
            "netbird-stun", [service["metadata"]["name"] for service in services]
        )
        root = directory.parents[1]
        exposure = yaml.safe_load(
            (
                root
                / "clusters/saikat-kubernetes-cluster/infrastructure-netbird-exposure.yaml"
            ).read_text()
        )
        self.assertIn({"name": "infrastructure-netbird"}, exposure["spec"]["dependsOn"])
        route = list(
            yaml.safe_load_all(
                (root / "networking/routes/netbird/route.yaml").read_text()
            )
        )[1]
        for rule in route["spec"]["rules"][:2]:
            self.assertEqual(
                rule["timeouts"], {"request": "0s", "backendRequest": "0s"}
            )

    def test_bootstrap_waits_for_management_without_false_readiness(self):
        job = yaml.safe_load(Path(__file__).with_name("bootstrap.yaml").read_text())
        program = job["spec"]["template"]["spec"]["initContainers"][0]["args"][0]
        unavailable = urllib.error.URLError(
            ConnectionRefusedError("fixture management is starting")
        )
        output = io.StringIO()
        with (
            patch("urllib.request.urlopen", side_effect=unavailable),
            redirect_stdout(output),
        ):
            with self.assertRaises(urllib.error.URLError):
                exec(compile(program, "management-readiness", "exec"), {})
        self.assertNotIn("Management is ready", output.getvalue())
        ready = io.BytesIO()
        ready.status = 200
        output = io.StringIO()
        with (
            patch("urllib.request.urlopen", return_value=ready),
            redirect_stdout(output),
        ):
            exec(compile(program, "management-readiness", "exec"), {})
        self.assertIn("Management is ready", output.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
