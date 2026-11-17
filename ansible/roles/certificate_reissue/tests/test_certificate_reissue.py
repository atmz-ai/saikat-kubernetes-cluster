import copy
import datetime
import ipaddress
import json
from pathlib import Path
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import unittest

from ansible.plugins.filter.core import combine
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID
from jinja2 import Environment
import yaml


ROLE_DIRECTORY = Path(__file__).resolve().parents[1]
REPOSITORY_DIRECTORY = ROLE_DIRECTORY.parents[2]


class CertificateReissueTests(unittest.TestCase):
    def setUp(self):
        self.tasks = yaml.safe_load((ROLE_DIRECTORY / "tasks/main.yml").read_text())
        self.transaction = next(task for task in self.tasks if "block" in task)
        self.activation = next(task for task in self.transaction["block"] if "rescue" in task)
        self.environment = Environment()
        self.environment.filters["combine"] = combine
        self.environment.filters["from_json"] = json.loads

    def test_existing_public_ip_and_legacy_dns_sans_survive_candidate_configuration(self):
        configuration_task = next(
            task for task in self.transaction["block"]
            if "certificate_reissue_candidate_configuration" in task.get("ansible.builtin.set_fact", {})
        )
        expression = configuration_task["ansible.builtin.set_fact"]["certificate_reissue_candidate_configuration"]
        original_names = ["20.219.32.205", "10.96.0.1", "old.example.invalid"]
        rendered = self.environment.from_string(expression).render(
            certificate_reissue_cluster_configuration={
                "apiVersion": "kubeadm.k8s.io/v1beta4", "kind": "ClusterConfiguration",
                "certificatesDir": "/etc/kubernetes/pki",
                "apiServer": {"certSANs": ["kubernetes-api.saikat.dev"]},
            },
            certificate_reissue_candidate_directory={"path": "/staged/certificate"},
            certificate_reissue_api_version={"stdout": json.dumps({"gitVersion": "v1.36.4"})},
            certificate_reissue_original_subject_alternative_names=original_names,
        )
        candidate = yaml.safe_load(rendered)
        self.assertTrue(set(original_names).issubset(candidate["apiServer"]["certSANs"]))
        self.assertIn("kubernetes-api.saikat.dev", candidate["apiServer"]["certSANs"])
        self.assertEqual(candidate["kubernetesVersion"], "v1.36.4")
        self.assertEqual(candidate["certificatesDir"], "/staged/certificate")

    def test_patch_skew_does_not_require_a_component_upgrade(self):
        assertion = next(
            task for task in self.tasks
            if task["name"] == "Require a healthy API and compatible installed kubeadm minor version"
        )["ansible.builtin.assert"]["that"][1]
        predicate = self.environment.compile_expression(assertion)
        for kubeadm_version, api_version, accepted in (
            ("v1.36.5", "v1.36.4", True),
            ("v1.36.4", "v1.36.4", True),
            ("v1.35.5", "v1.36.4", False),
        ):
            with self.subTest(kubeadm=kubeadm_version, api=api_version):
                self.assertEqual(predicate(
                    certificate_reissue_kubeadm_version={"stdout": kubeadm_version},
                    certificate_reissue_api_version={"stdout": json.dumps({"gitVersion": api_version})},
                ), accepted)

    def test_pair_installation_is_after_the_stop_barrier_and_recovery_always_returns_manifest(self):
        stop_position = next(index for index, task in enumerate(self.activation["block"])
                             if task.get("ansible.builtin.wait_for", {}).get("state") == "stopped")
        install_position = next(index for index, task in enumerate(self.activation["block"])
                                if task.get("loop") == ["apiserver.crt", "apiserver.key"])
        self.assertLess(stop_position, install_position)
        recovery = next(task for task in self.activation["rescue"] if "always" in task)
        self.assertEqual(recovery["always"][0]["ansible.builtin.copy"]["dest"],
                         "/etc/kubernetes/manifests/kube-apiserver.yaml")

    def test_node_readiness_gate_retries_errors_and_requires_ready(self):
        verification = yaml.safe_load((ROLE_DIRECTORY / "tasks/verify-serving.yml").read_text())
        condition = next(task for task in verification if task["name"] == "Wait for the node's Ready condition before proceeding")["until"]
        predicate = self.environment.compile_expression(condition)
        for return_code, status, accepted in ((0, "True", True), (0, "False", False), (1, None, False)):
            with self.subTest(return_code=return_code, status=status):
                output = json.dumps({"status": {"conditions": [{"type": "Ready", "status": status}]}}) if status else ""
                self.assertEqual(predicate(certificate_reissue_node_ready={"rc": return_code, "stdout": output}), accepted)

    def test_real_tls_activation_and_failure_rollback(self):
        for failure in (None, "key-copy", "serving-verification"):
            with self.subTest(failure=failure):
                self.run_activation_fixture(failure)

    def run_activation_fixture(self, failure):
        with tempfile.TemporaryDirectory(prefix="certificate-fixture-", dir=ROLE_DIRECTORY / "tests") as directory:
            root = Path(directory)
            certificate_directory = root / "pki"
            candidate_directory = root / "candidate"
            backup_directory = root / "backup"
            manifest = root / "manifests/kube-apiserver.yaml"
            for path in (certificate_directory, candidate_directory, backup_directory, manifest.parent):
                path.mkdir()
            authority_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
            authority_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "fixture-authority")])
            now = datetime.datetime.now(datetime.UTC)
            authority = (x509.CertificateBuilder().subject_name(authority_name).issuer_name(authority_name)
                         .public_key(authority_key.public_key()).serial_number(x509.random_serial_number())
                         .not_valid_before(now - datetime.timedelta(days=1))
                         .not_valid_after(now + datetime.timedelta(days=1))
                         .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
                         .add_extension(x509.SubjectKeyIdentifier.from_public_key(authority_key.public_key()), critical=False)
                         .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(authority_key.public_key()), critical=False)
                         .add_extension(x509.KeyUsage(
                             digital_signature=True, content_commitment=False, key_encipherment=False,
                             data_encipherment=False, key_agreement=False, key_cert_sign=True,
                             crl_sign=True, encipher_only=False, decipher_only=False), critical=True)
                         .sign(authority_key, hashes.SHA256()))
            (certificate_directory / "ca.crt").write_bytes(authority.public_bytes(serialization.Encoding.PEM))
            original_information = self.write_serving_pair(
                certificate_directory, authority, authority_key, ["old.example.invalid"], now)
            candidate_information = self.write_serving_pair(
                candidate_directory, authority, authority_key,
                ["old.example.invalid", "kubernetes-api.saikat.dev"], now)
            manifest.write_text("original-static-manifest\n")
            for path in (certificate_directory / "apiserver.crt", certificate_directory / "apiserver.key", manifest):
                (backup_directory / path.name).write_bytes(path.read_bytes())
            originals = {path: path.read_bytes() for path in certificate_directory.iterdir()}
            if failure == "key-copy":
                (candidate_directory / "apiserver.key").unlink()

            with socket.socket() as reservation:
                reservation.bind(("127.0.0.1", 0))
                port = reservation.getsockname()[1]
            stopped = threading.Event()
            failures = []

            def serve_static_manifest():
                try:
                    while not stopped.is_set():
                        if not manifest.exists():
                            time.sleep(0.02)
                            continue
                        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
                        context.load_cert_chain(certificate_directory / "apiserver.crt",
                                                certificate_directory / "apiserver.key")
                        with socket.socket() as listener:
                            listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                            listener.bind(("127.0.0.1", port))
                            listener.listen()
                            listener.settimeout(0.05)
                            while manifest.exists() and not stopped.is_set():
                                try:
                                    connection, _ = listener.accept()
                                except TimeoutError:
                                    continue
                                try:
                                    with context.wrap_socket(connection, server_side=True):
                                        pass
                                except ssl.SSLError as error:
                                    if error.reason != "UNEXPECTED_EOF_WHILE_READING":
                                        raise
                except Exception as error:
                    failures.append(error)

            worker = threading.Thread(target=serve_static_manifest)
            worker.start()
            try:
                self.wait_for_certificate(certificate_directory / "ca.crt", port,
                                          "old.example.invalid", original_information)
                activation = self.rewrite_fixture(copy.deepcopy(self.activation), root, port)
                verification = yaml.safe_load((ROLE_DIRECTORY / "tasks/verify-serving.yml").read_text())[0]
                verification = self.rewrite_fixture(verification, root, port)
                helper = root / "verify.yml"
                verification_tasks = [verification]
                if failure == "serving-verification":
                    verification_tasks.append({
                        "name": "Inject post-activation verification failure",
                        "ansible.builtin.fail": {"msg": "Injected serving verification failure"},
                        "when": "certificate_reissue_expected_information.fingerprints.sha256 == certificate_reissue_candidate_information.fingerprints.sha256",
                    })
                helper.write_text(yaml.safe_dump(verification_tasks, sort_keys=False))
                for task in self.walk_tasks(activation):
                    if "ansible.builtin.include_tasks" in task:
                        task["ansible.builtin.include_tasks"] = str(helper)
                    command = task.get("ansible.builtin.command", {})
                    if command.get("argv", [None])[0] == "kubectl":
                        command["argv"] = [sys.executable, "-c", "print('ok')"]
                play = [{"name": "Exercise actual Ansible certificate transaction on isolated TLS fixture",
                         "hosts": "localhost", "connection": "local", "gather_facts": False,
                         "vars": {
                             "ansible_python_interpreter": sys.executable,
                             "ansible_remote_tmp": str(root / "ansible-tmp"),
                             "ansible_host": "127.0.0.1",
                             "certificate_reissue_candidate_directory": {"path": str(candidate_directory)},
                             "certificate_reissue_backup_directory": {"path": str(backup_directory)},
                             "certificate_reissue_candidate_information": candidate_information,
                             "certificate_reissue_original_information": original_information,
                             "certificate_reissue_original_file_modes": {
                                 str(certificate_directory / "apiserver.crt"): "0600",
                                 str(certificate_directory / "apiserver.key"): "0600",
                                 str(manifest): "0600",
                             },
                         }, "tasks": [activation]}]
                playbook = root / "fixture.yml"
                playbook.write_text(yaml.safe_dump(play, sort_keys=False))
                result = subprocess.run(
                    ["mise", "run", "--skip-tools", "ansible-playbook", "--", str(playbook),
                     "-i", "localhost,", "--connection", "local"],
                    cwd=REPOSITORY_DIRECTORY, check=False, timeout=90)
                self.assertEqual(result.returncode == 0, failure is None)
                self.assertEqual(manifest.read_text(), "original-static-manifest\n")
                expected = candidate_information if failure is None else original_information
                self.wait_for_certificate(certificate_directory / "ca.crt", port, "old.example.invalid", expected)
                if failure is not None:
                    for path, content in originals.items():
                        self.assertEqual(path.read_bytes(), content)
                self.assertFalse(failures, failures)
            finally:
                stopped.set()
                worker.join(timeout=5)
                self.assertFalse(worker.is_alive(), "TLS fixture did not stop")

    @staticmethod
    def write_serving_pair(directory, authority, authority_key, names, now):
        private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
        subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "kube-apiserver")])
        certificate = (x509.CertificateBuilder().subject_name(subject).issuer_name(authority.subject)
                       .public_key(private_key.public_key()).serial_number(x509.random_serial_number())
                       .not_valid_before(now - datetime.timedelta(days=1))
                       .not_valid_after(now + datetime.timedelta(days=1))
                       .add_extension(x509.SubjectAlternativeName(
                           [x509.DNSName(name) for name in names]
                           + [x509.IPAddress(ipaddress.ip_address("127.0.0.1"))]), critical=False)
                       .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
                       .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
                       .add_extension(x509.SubjectKeyIdentifier.from_public_key(private_key.public_key()), critical=False)
                       .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(authority_key.public_key()), critical=False)
                       .add_extension(x509.KeyUsage(
                           digital_signature=True, content_commitment=False, key_encipherment=True,
                           data_encipherment=False, key_agreement=False, key_cert_sign=False,
                           crl_sign=False, encipher_only=False, decipher_only=False), critical=True)
                       .sign(authority_key, hashes.SHA256()))
        (directory / "apiserver.crt").write_bytes(certificate.public_bytes(serialization.Encoding.PEM))
        (directory / "apiserver.key").write_bytes(private_key.private_bytes(
            serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption()))
        return {"subject_alt_name": ["DNS:" + name for name in names] + ["IP:127.0.0.1"],
                "fingerprints": {"sha256": certificate.fingerprint(hashes.SHA256()).hex()}}

    @classmethod
    def rewrite_fixture(cls, value, root, port):
        if isinstance(value, str):
            return value.replace("/etc/kubernetes", str(root)).replace(
                "(address, 6443)", "(address, " + str(port) + ")")
        if isinstance(value, list):
            return [cls.rewrite_fixture(item, root, port) for item in value]
        if isinstance(value, dict):
            result = {key: cls.rewrite_fixture(item, root, port) for key, item in value.items()}
            if "ansible.builtin.wait_for" in result:
                result["ansible.builtin.wait_for"]["port"] = port
                result["ansible.builtin.wait_for"]["sleep"] = 1
                result["ansible.builtin.wait_for"]["timeout"] = 10
            return result
        return value

    @classmethod
    def walk_tasks(cls, task):
        yield task
        for branch in ("block", "rescue", "always"):
            for child in task.get(branch, []):
                yield from cls.walk_tasks(child)

    def wait_for_certificate(self, authority_path, port, hostname, information):
        context = ssl.create_default_context(cafile=str(authority_path))
        deadline = time.monotonic() + 5
        while True:
            try:
                with socket.create_connection(("127.0.0.1", port), timeout=1) as connection:
                    with context.wrap_socket(connection, server_hostname=hostname) as secured:
                        certificate = x509.load_der_x509_certificate(secured.getpeercert(binary_form=True))
                        self.assertEqual(certificate.fingerprint(hashes.SHA256()).hex(),
                                         information["fingerprints"]["sha256"])
                return
            except ConnectionRefusedError:
                if time.monotonic() >= deadline:
                    raise
                time.sleep(0.02)


if __name__ == "__main__":
    unittest.main(verbosity=2)
