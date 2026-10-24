# Application Source

Application code lives in `apps/<application>/`. Its cluster deployment declarations live separately in `kubernetes/apps/<application>/`, which Flux reconciles independently of local submodule checkout state. Repository-wide operating rules live in the root `AGENTS.md`; application-specific contracts belong in the application's own `AGENTS.md`.

## Maintained Applications

| Application | Deployment |
| --- | --- |
| `my-website` | `saikat.dev` |
| `yral-auth` | `auth.yral.com` |
| `yral-metadata` | `metadata.yral.com` |
| `yral-database-spacetime` | SpacetimeDB Maincloud; Rust workspace member |
| `yral-ios` | App Store and TestFlight, bundle `com.yral.iosApp` |

Rust applications maintained in this repository belong in the root Cargo workspace. Do not add them to its exclusion list. Tools, tasks, local configuration, secrets, and daemons remain centralized at the repository root; follow the root onboarding conventions rather than adding per-application tooling configuration.

## Independent Submodule

`yral-rishi-agent` is a submodule of `git@github.com:saikatdas0790/yral-rishi-agent.git`, a fork of `dolr-ai/yral-rishi-agent`, serving `agent.rishi.yral.com`. Changes land on fork branches and go through a fork-to-upstream pull request. Do not bypass the upstream maintainer's protections or merge authority. Its own documentation and instructions are maintained independently.

Initialize submodules after a fresh clone with `git submodule update --init --recursive`, or use the repository bootstrap task that already performs this step.

## Retired Legacy Frontend

The legacy Leptos frontend and its dedicated build, routing, and deployment resources were removed. Shared authentication, SpacetimeDB, and external object-storage data were retained.

Deployment retirement guidance belongs to `kubernetes/AGENTS.md`; historical one-time recovery and validation waivers do not establish new application-wide rules.