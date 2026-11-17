import argparse
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from api_models import IdentityProviderRequest, SetupRequest, UserRequest


class Phase(Enum):
    INSTANCE = "checking instance"
    SETUP = "creating operator"
    ACCOUNTS = "reading account settings"
    ACCOUNT_UPDATED = "verifying user approval"
    PROVIDERS = "reading identity providers"
    PROVIDER_UPDATED = "configuring Google"
    PROVIDER_VERIFIED = "verifying Google"
    USERS = "reading the operator Google identity"
    USER_APPROVED = "approving the operator Google identity"
    USER_UPDATED = "granting operator administrator access"
    USER_VERIFIED = "verifying operator administrator access"
    DONE = "complete"


class Completion(Enum):
    WAITING_FOR_GOOGLE_SIGNIN = (
        "Waiting for the operator's first Google sign-in; no other users were changed"
    )
    OPERATOR_READY = (
        "Verified the exact operator Google identity has active administrator access"
    )


@dataclass(frozen=True)
class Request:
    phase: Phase
    method: str
    path: str
    body: dict | None = None


@dataclass(frozen=True)
class SaveToken:
    token: str
    request: Request


def account_update(accounts: list) -> Request:
    if len(accounts) != 1 or not isinstance(accounts[0], dict):
        raise ValueError("Expected exactly one NetBird account")
    account = accounts[0]
    if not isinstance(account.get("id"), str) or not account["id"]:
        raise ValueError("NetBird account is missing its identifier")
    if not isinstance(account.get("settings"), dict):
        raise ValueError("NetBird account is missing its settings")
    settings = dict(account["settings"])
    extra = settings.get("extra", {})
    if not isinstance(extra, dict):
        raise ValueError("NetBird account has invalid extra settings")
    settings["extra"] = dict(extra, user_approval_required=True)
    return Request(
        Phase.ACCOUNT_UPDATED,
        "PUT",
        "/api/accounts/" + urllib.parse.quote(account["id"], safe=""),
        {"settings": settings},
    )


def provider_update(providers: list, desired: IdentityProviderRequest) -> Request:
    if not providers:
        return Request(
            Phase.PROVIDER_UPDATED, "POST", "/api/identity-providers", desired
        )

    if len(providers) != 1 or not isinstance(providers[0], dict):
        raise ValueError("Expected only the declared ATMZ Google identity provider")
    provider = providers[0]
    if (
        provider.get("name") != desired["name"]
        or provider.get("type") != desired["type"]
    ):
        raise ValueError(
            "Existing NetBird identity provider differs from the declared provider"
        )
    if not isinstance(provider.get("id"), str) or not provider["id"]:
        raise ValueError("NetBird identity provider is missing its identifier")
    return Request(
        Phase.PROVIDER_UPDATED,
        "PUT",
        "/api/identity-providers/" + urllib.parse.quote(provider["id"], safe=""),
        desired,
    )


def operator_update(users: list, operator_email: str) -> Request | Completion:
    if any(not isinstance(user, dict) for user in users):
        raise ValueError("NetBird users response contains an invalid user")
    candidates = [
        user
        for user in users
        if user.get("email") == operator_email
        and isinstance(user.get("idp_id"), str)
        and user["idp_id"].startswith("google-")
    ]
    if not candidates:
        owners = [
            user
            for user in users
            if user.get("email") == operator_email
            and user.get("role") == "owner"
            and user.get("is_service_user") is False
        ]
        if len(owners) != 1:
            raise ValueError(
                "NetBird users do not contain the declared bootstrap owner"
            )
        return Completion.WAITING_FOR_GOOGLE_SIGNIN
    if len(candidates) != 1:
        raise ValueError(
            "Expected exactly one Google identity for the declared operator"
        )
    operator = candidates[0]
    if not isinstance(operator.get("role"), str) or not operator["role"]:
        raise ValueError("Operator Google identity is missing its account role")
    if (
        not isinstance(operator.get("id"), str)
        or not operator["id"]
        or operator.get("is_service_user") is not False
    ):
        raise ValueError("Operator Google identity is invalid or is a service user")
    if (
        type(operator.get("pending_approval")) is not bool
        or type(operator.get("is_blocked")) is not bool
    ):
        raise ValueError("Operator Google identity is missing its approval status")
    endpoint = "/api/users/" + urllib.parse.quote(operator["id"], safe="")
    if operator["pending_approval"]:
        return Request(Phase.USER_APPROVED, "POST", endpoint + "/approve")
    if operator.get("role") in ("admin", "owner") and not operator["is_blocked"]:
        return Completion.OPERATOR_READY
    groups = operator.get("auto_groups")
    if not isinstance(groups, list) or any(
        not isinstance(group, str) for group in groups
    ):
        raise ValueError("Operator Google identity is missing its auto groups")
    update = UserRequest(role="admin", auto_groups=list(groups), is_blocked=False)
    return Request(Phase.USER_UPDATED, "PUT", endpoint, update)


def transition(
    phase: Phase,
    response: dict | list,
    setup: SetupRequest,
    provider: IdentityProviderRequest,
    token_available: bool,
) -> Request | SaveToken | Completion | None:
    match phase:
        case Phase.INSTANCE:
            if (
                not isinstance(response, dict)
                or type(response.get("setup_required")) is not bool
            ):
                raise ValueError("NetBird instance response is missing setup_required")
            if response["setup_required"]:
                return Request(Phase.SETUP, "POST", "/api/setup", setup)
            if not token_available:
                raise ValueError(
                    "NetBird is initialized but its persisted bootstrap PAT is missing; restore the bootstrap token from the volume backup"
                )
            return Request(Phase.ACCOUNTS, "GET", "/api/accounts")
        case Phase.SETUP:
            if (
                not isinstance(response, dict)
                or response.get("email") != setup["email"]
            ):
                raise ValueError("NetBird did not create the declared operator")
            token = response.get("personal_access_token")
            if not isinstance(token, str) or not token.startswith("nbp_"):
                raise ValueError(
                    "NetBird setup did not return its requested bootstrap PAT"
                )
            return SaveToken(token, Request(Phase.ACCOUNTS, "GET", "/api/accounts"))
        case Phase.ACCOUNTS:
            if not isinstance(response, list):
                raise ValueError("NetBird accounts response is not a list")
            return account_update(response)
        case Phase.ACCOUNT_UPDATED:
            if (
                not isinstance(response, dict)
                or response.get("settings", {})
                .get("extra", {})
                .get("user_approval_required")
                is not True
            ):
                raise ValueError("NetBird did not persist mandatory user approval")
            return Request(Phase.PROVIDERS, "GET", "/api/identity-providers")
        case Phase.PROVIDERS:
            if not isinstance(response, list):
                raise ValueError("NetBird identity providers response is not a list")
            return provider_update(response, provider)
        case Phase.PROVIDER_UPDATED | Phase.PROVIDER_VERIFIED:
            if not isinstance(response, dict) or any(
                response.get(key) != provider[key]
                for key in ("name", "type", "issuer", "client_id")
            ):
                raise ValueError(
                    "NetBird Google provider does not match the declared configuration"
                )
            if not isinstance(response.get("id"), str) or not response["id"]:
                raise ValueError("NetBird Google provider is missing its identifier")
            if phase is Phase.PROVIDER_VERIFIED:
                return Request(Phase.USERS, "GET", "/api/users")
            return Request(
                Phase.PROVIDER_VERIFIED,
                "GET",
                "/api/identity-providers/"
                + urllib.parse.quote(response["id"], safe=""),
            )
        case Phase.USERS | Phase.USER_VERIFIED:
            if not isinstance(response, list):
                raise ValueError("NetBird users response is not a list")
            result = operator_update(response, setup["email"])
            if phase is Phase.USER_VERIFIED and result is not Completion.OPERATOR_READY:
                raise ValueError(
                    "NetBird did not persist the operator administrator grant"
                )
            return result
        case Phase.USER_APPROVED:
            if (
                not isinstance(response, dict)
                or response.get("email") != setup["email"]
                or response.get("pending_approval") is not False
            ):
                raise ValueError("NetBird did not persist the operator approval")
            return Request(Phase.USERS, "GET", "/api/users")
        case Phase.USER_UPDATED:
            if (
                not isinstance(response, dict)
                or response.get("email") != setup["email"]
                or response.get("role") not in ("admin", "owner")
                or response.get("pending_approval") is not False
                or response.get("is_blocked") is not False
            ):
                raise ValueError("NetBird did not grant operator administrator access")
            return Request(Phase.USER_VERIFIED, "GET", "/api/users")
        case _:
            return None


def main(command_line_arguments=None):
    parser = argparse.ArgumentParser()
    parser.add_argument("--approve-operator", action="store_true")
    arguments = parser.parse_args(command_line_arguments)
    setup = SetupRequest(
        email=os.environ["NETBIRD_OPERATOR_EMAIL"],
        password=os.environ["NETBIRD_BOOTSTRAP_PASSWORD"],
        name=os.environ["NETBIRD_OPERATOR_EMAIL"],
        create_pat=True,
        pat_expire_in=365,
    )
    provider = IdentityProviderRequest(
        type="google",
        name="ATMZ Google",
        issuer="https://accounts.google.com",
        client_id=os.environ["NETBIRD_GOOGLE_CLIENT_ID"],
        client_secret=os.environ["NETBIRD_GOOGLE_CLIENT_SECRET"],
    )
    token_path = Path("/var/lib/netbird/gitops-bootstrap.pat")
    token = token_path.read_text().strip() if token_path.exists() else ""
    if arguments.approve_operator and not token:
        raise RuntimeError("The initializer has not persisted its bootstrap PAT")
    request = (
        Request(Phase.USERS, "GET", "/api/users")
        if arguments.approve_operator
        else Request(Phase.INSTANCE, "GET", "/api/instance")
    )
    while request is not None:
        print(
            request.phase.value + ": " + request.method + " " + request.path, flush=True
        )
        headers = {"Content-Type": "application/json"}
        if token:
            headers["Authorization"] = "Token " + token
        network_request = urllib.request.Request(
            "http://netbird-server.netbird.svc.cluster.local" + request.path,
            data=(
                json.dumps(request.body).encode() if request.body is not None else None
            ),
            headers=headers,
            method=request.method,
        )
        try:
            with urllib.request.urlopen(network_request, timeout=30) as response:
                body = response.read(1048577)
                if len(body) > 1048576:
                    raise RuntimeError(
                        "NetBird HTTP "
                        + str(response.status)
                        + ": response exceeded 1 MiB"
                    )
                result = json.loads(body)
        except urllib.error.HTTPError as error:
            with error:
                error_body = error.read(1048576).decode(errors="replace")
            raise RuntimeError(
                "NetBird HTTP " + str(error.code) + ": " + error_body
            ) from error
        effect = transition(request.phase, result, setup, provider, bool(token))
        if isinstance(effect, SaveToken):
            descriptor = os.open(
                token_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600
            )
            with os.fdopen(descriptor, "w") as destination:
                destination.write(effect.token)
                destination.flush()
                os.fsync(destination.fileno())
            token = effect.token
            request = effect.request
        elif isinstance(effect, Completion):
            print(effect.value, flush=True)
            request = None
        else:
            request = effect


if __name__ == "__main__":
    main()
