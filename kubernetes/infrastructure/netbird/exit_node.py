import argparse
import json
import os
import urllib.error
import urllib.parse
import urllib.request
from enum import Enum
from pathlib import Path

from api_models import CreateSetupKeyRequest, GroupRequest, RouteRequest


class Phase(Enum):
    GROUP = "reconciling exit-peer group"
    KEY = "preparing exit-peer enrollment"
    USERS = "reading operator identity"
    PEERS = "selecting the existing Mac"
    CLIENT_GROUP = "reconciling VPN client group"
    ROUTE = "reconciling exit route"
    VERIFY = "verifying exit route"
    DONE = "complete"


def group_operation(groups: list, name: str, peers: list[str] | None = None):
    candidates = [group for group in groups if group.get("name") == name]
    if len(candidates) > 1:
        raise ValueError("Ambiguous NetBird group: " + name)
    body = GroupRequest(name=name)
    if peers is not None:
        body["peers"] = peers
    if not candidates:
        return "POST", "/api/groups", body
    group = candidates[0]
    if not isinstance(group.get("id"), str) or not group["id"]:
        raise ValueError("NetBird group is missing its identifier: " + name)
    if peers is None:
        return None, None, group
    return "PUT", "/api/groups/" + urllib.parse.quote(group["id"], safe=""), body


def select_mac(users: list, peers: list) -> str:
    operators = [
        user["id"]
        for user in users
        if user.get("email") == "saikat@atmz.ai"
        and user.get("idp_id", "").startswith("google-")
        and user.get("role") in ("admin", "owner")
        and user.get("is_blocked") is False
    ]
    if len(operators) != 1:
        raise ValueError("Expected exactly one active Google operator")
    candidates = [
        peer
        for peer in peers
        if peer.get("dns_label") == "saikats-macbook-pro"
        and peer.get("os", "").startswith("Darwin")
        and peer.get("user_id") == operators[0]
    ]
    if (
        len(candidates) != 1
        or not isinstance(candidates[0].get("id"), str)
        or not candidates[0]["id"]
    ):
        raise ValueError("Expected the existing operator Mac peer, not another device")
    return candidates[0]["id"]


def exit_route(exit_group: str, client_group: str) -> RouteRequest:
    return RouteRequest(
        description="Kubernetes internet exit node",
        network_id="Azure Cloud VPN",
        enabled=True,
        peer_groups=[exit_group],
        network="0.0.0.0/0",
        metric=9999,
        masquerade=True,
        groups=[client_group],
        keep_route=False,
        # ! Offer the VPN without rerouting the operator's active Mac connection.
        skip_auto_apply=True,
    )


def route_operation(routes: list, desired: RouteRequest):
    candidates = [
        route for route in routes if route.get("network_id") == desired["network_id"]
    ]
    if len(candidates) > 1:
        raise ValueError("Expected only one declared Azure exit route")
    if not candidates:
        return "POST", "/api/routes", desired
    route = candidates[0]
    if not isinstance(route.get("id"), str) or not route["id"]:
        raise ValueError("NetBird exit route is missing its identifier")
    return "PUT", "/api/routes/" + urllib.parse.quote(route["id"], safe=""), desired


def verify_route(route: dict, desired: RouteRequest):
    for key, value in desired.items():
        if route.get(key) != value:
            raise ValueError("NetBird did not persist exit-route field: " + key)


def request(method: str, path: str, token: str, body: dict | None = None):
    print(method + " " + path, flush=True)
    outgoing = urllib.request.Request(
        "http://netbird-server.netbird.svc.cluster.local" + path,
        headers={"Authorization": "Token " + token, "Content-Type": "application/json"},
        data=json.dumps(body).encode() if body is not None else None,
        method=method,
    )
    try:
        with urllib.request.urlopen(outgoing, timeout=30) as response:
            incoming = response.read(1048577)
            if len(incoming) > 1048576:
                raise RuntimeError(
                    "NetBird HTTP " + str(response.status) + ": response exceeded 1 MiB"
                )
            return json.loads(incoming)
    except urllib.error.HTTPError as error:
        with error:
            error_body = error.read(1048576).decode(errors="replace")
        raise RuntimeError(
            "NetBird HTTP " + str(error.code) + ": " + error_body
        ) from error


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", action="store_true")
    arguments = parser.parse_args()
    token = Path("/management/gitops-bootstrap.pat").read_text().strip()
    phase = Phase.GROUP
    exit_group = None
    users = None
    mac_peer = None
    client_group = None
    route = None
    while phase is not Phase.DONE:
        print(phase.value, flush=True)
        match phase:
            case Phase.GROUP:
                groups = request("GET", "/api/groups", token)
                method, path, body = group_operation(groups, "cloud-vpn-exit-nodes")
                group = request(method, path, token, body) if method else body
                exit_group = group["id"]
                phase = Phase.KEY if arguments.prepare else Phase.USERS
            case Phase.KEY:
                key_path = Path("/var/lib/netbird/exit-setup.key")
                if not key_path.exists():
                    body = CreateSetupKeyRequest(
                        name="kubernetes-cloud-vpn",
                        type="one-off",
                        expires_in=86400,
                        auto_groups=[exit_group],
                        usage_limit=1,
                    )
                    key = request("POST", "/api/setup-keys", token, body)
                    if not isinstance(key.get("key"), str) or not key["key"]:
                        raise ValueError(
                            "NetBird did not return the exit-peer setup key"
                        )
                    descriptor = os.open(
                        key_path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600
                    )
                    with os.fdopen(descriptor, "w") as destination:
                        destination.write(key["key"])
                        destination.flush()
                        os.fsync(destination.fileno())
                    os.chown(key_path, 1000, 1000)
                    print(
                        "Persisted single-use enrollment key without exposing it",
                        flush=True,
                    )
                else:
                    print(
                        "Reusing persisted exit identity enrollment material",
                        flush=True,
                    )
                phase = Phase.DONE
            case Phase.USERS:
                users = request("GET", "/api/users", token)
                phase = Phase.PEERS
            case Phase.PEERS:
                peers = request("GET", "/api/peers", token)
                mac_peer = select_mac(users, peers)
                routing_peers = [
                    peer
                    for peer in peers
                    if any(
                        group.get("id") == exit_group
                        for group in peer.get("groups", [])
                    )
                ]
                if (
                    len(routing_peers) != 1
                    or routing_peers[0].get("hostname") != "azure-cloud-vpn"
                ):
                    raise ValueError(
                        "Expected exactly one enrolled Kubernetes exit peer"
                    )
                phase = Phase.CLIENT_GROUP
            case Phase.CLIENT_GROUP:
                groups = request("GET", "/api/groups", token)
                method, path, body = group_operation(
                    groups, "cloud-vpn-clients", [mac_peer]
                )
                client_group = request(method, path, token, body)["id"]
                phase = Phase.ROUTE
            case Phase.ROUTE:
                routes = request("GET", "/api/routes", token)
                desired = exit_route(exit_group, client_group)
                method, path, body = route_operation(routes, desired)
                route = request(method, path, token, body)
                verify_route(route, desired)
                phase = Phase.VERIFY
            case Phase.VERIFY:
                route = request(
                    "GET",
                    "/api/routes/" + urllib.parse.quote(route["id"], safe=""),
                    token,
                )
                verify_route(route, exit_route(exit_group, client_group))
                print(
                    "Verified Azure Cloud VPN is offered only to the existing Mac with Auto Apply off",
                    flush=True,
                )
                phase = Phase.DONE


if __name__ == "__main__":
    main()
