# apps/

This directory contains application source code. Some apps are **git submodules** (separate repos pinned here), while others are **in-repo directories** (native to this cluster repo).

## Relationship to `kubernetes/apps/`

| Directory                     | Contents                                             |
| ----------------------------- | ---------------------------------------------------- |
| `apps/<app-name>/`            | Application source code (submodule or in-repo)       |
| `kubernetes/apps/<app-name>/` | Kubernetes deployment manifests for that application |

Source code and deployment manifests are intentionally separated. Flux reconciles from `kubernetes/apps/` independently of the submodule checkout state.

## Adding a new application

### As a submodule (separate repo)

```bash
# 1. Add the submodule (SSH recommended)
git submodule add git@github.com:<org>/<repo-name>.git apps/<repo-name>
git add apps/<repo-name> .gitmodules
git commit -m "feat: add <repo-name> submodule"
```

### As an in-repo directory

```bash
mkdir apps/<app-name>
# Create Cargo.toml, Dockerfile.buildkit, etc.
# Add to Cargo.toml root workspace exclude list
```

## Populating submodules after a fresh clone

```bash
git submodule update --init --recursive
```

## Current submodules

| Submodule                          | Source repo                                           |
| ---------------------------------- | ----------------------------------------------------- |
| `apps/yral-rishi-agent/`           | git@github.com:saikatdas0790/yral-rishi-agent.git — fork of dolr-ai/yral-rishi-agent (agent.rishi.yral.com). The submodule clones the FORK; the checkout adds an `upstream` remote pointing at Rishi's repo. Work lands on fork branches; PRs go fork → upstream so Rishi's repo protections and final merge say are never bypassed. |

## In-repo applications (not submodules)

| App                             | Deployed at                                                 |
| ------------------------------- | ----------------------------------------------------------- |
| `apps/my-website/`             | `saikat.dev`                                                |
| `apps/yral-auth/`               | `auth.yral.com`                                             |
| `apps/yral-metadata/`           | `metadata.yral.com`                                         |
| `apps/yral-database-spacetime/` | Workspace member (root Cargo.toml)                          || `apps/yral-ios/`                | App Store / TestFlight (`com.yral.iosApp`)                  |

## Retired Legacy Frontend

The legacy Leptos frontend and its dedicated build, routing, and deployment resources are removed. Shared authentication, SpacetimeDB, and external object-storage data are retained.

Deploy retirement in two stages. Suspend `app-yral-web` and its image automation while preparing the removal, then push an empty resource set with the Kustomization explicitly resumed. Verify its inventory is empty, the retired namespace and image automation are absent, and the retained services remain healthy. Only then remove the empty Kustomization and its parent reference in a second push. Deleting a suspended Kustomization skips finalizer pruning and orphans its resources. Let Flux reconcile naturally, without forcing it. Removing local credentials does not revoke their upstream keys or delete external data.

During retirement, Flux's bootstrap Git Secret had expired credentials and could not fetch a GitOps repair. The operator authorized a one-time local `flux create secret git` update using the age-encrypted `GITHUB_TOKEN` from fnox. Source readiness was verified without forced reconciliation; no Ansible recovery operation was added.

Native release builds, local daemon health checks, and regression tests passed. The local auth image build failed before compilation when Rust's toolchain download could not resolve DNS inside the Apple builder. The operator explicitly waived local image validation for this deployment; production build and rollout checks remain required.