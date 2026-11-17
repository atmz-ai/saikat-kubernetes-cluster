# Application Source

Application code lives in `apps/<application>/`. Its cluster deployment declarations live separately in `kubernetes/apps/<application>/`, which Flux reconciles from Git. Repository-wide operating rules live in the root `AGENTS.md`; application-specific contracts belong in the application's own `AGENTS.md`.

## Maintained Applications

| Application | Deployment |
| --- | --- |
| `my-website` | `saikat.dev` |

The website uses SvelteKit, TypeScript, and XState. Its dependency manifest and lockfile live with the application. Tools, tasks, local configuration, secrets, and daemons remain centralized at the repository root; follow the root onboarding conventions rather than adding per-application tooling configuration.

## External Ownership

Rishi independently maintains the Ole-Ole-AI repositories. Do not include his
code as a submodule or consume his APIs. New application APIs belong in this
repository; do not replace retired integrations with another Rishi endpoint.

Deployment retirement guidance belongs to `kubernetes/AGENTS.md`; historical one-time recovery and validation waivers do not establish new application-wide rules.