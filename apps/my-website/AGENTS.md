# Personal Website

SvelteKit 3 / Svelte 5, strict TypeScript, Tailwind CSS 4 and XState 5. Root tooling, image builds and Kubernetes declarations remain outside this app.

## Build and runtime

From this directory: `npm ci`, `npm run check`, `npm test`, `npm run build`.
`npm test` runs pure Vitest tests once, without services or browser binaries.
From the repository root, `mise run my-website-browser-test` builds first and then runs the isolated browser suite. `mise run my-website-validate` includes the same browser assertions against `https://saikat.dev`, alongside production health validation.
`npm run test:browser` runs Playwright separately after building; its webServer starts and stops `node build` on loopback port 4179. It uses installed Chrome (`channel: 'chrome'`).
To test an existing production daemon without starting or stopping a server, run `PLAYWRIGHT_BASE_URL=http://localhost:8081 npm run test:browser`. An explicit base URL disables Playwright's `webServer` entirely.

The latest typography plugin still pins an affected selector parser. Its scoped npm override advances that parser to patched 7.2.x; selector contract tests and production CSS parity validate compatibility. Remove the override when the plugin's own declaration upgrades. `allowScripts.fsevents = false` explicitly denies the optional macOS watcher rebuild; normal Node/Vite watching remains available without this optional native module. Do not globally disable lifecycle scripts or silence npm warnings.

Production runs `node build` with production dependencies. Set `HOST`, `PORT` and `ORIGIN` at deployment (canonical production origin `https://saikat.dev`). No secrets are required. Do not add local environment files or per-app daemons.

## Ownership and contracts

- Feature folders under `src/lib/` colocate screens, components, machines, pure logic and unit tests. SvelteKit route files only load data and compose screens.
- `useMachine` from the official `@xstate/svelte` integration creates an actor for each component lifetime. Never export a running actor or share mutable SSR state. UI sends typed events; filtering is pure and derived, never another mutable list.
- Interactive feature machines begin in `initializing`; their component's `onMount` sends `component.mounted` to enter `ready`. Render controls disabled until the actor matches `ready`, so SSR cannot accept actions before hydration installs handlers. Tests wait for enabled controls before interaction or taking the browser offline; delayed-script tests verify the actual readiness boundary without sleeps or retries.
- `content/blog/` and `content/projects/` are preserved Markdown with YAML frontmatter. Server-only Vite raw imports bundle the complete content into the server; production needs no separate content directory. Markdown supports raw trusted repository HTML, tables, autolinks, strikethrough, tasks, footnotes and Prism syntax highlighting. Never process untrusted Markdown through this renderer.
- `public/` remains the authoritative source of static assets, configured through `files.assets`. Keep existing URLs and files unchanged.
- Blog dates sort descending by `date`; projects by `startDate`. Dates render in UTC to preserve historical date labels across build/server/browser timezones. Search is literal case-insensitive substring matching of title, description or individual tags, without trimming or regex interpretation.
- Home and list routes prerender. Content routes use `prerender = 'auto'` with explicit entries, retaining server loaders to return HTTP 404 for unknown slugs. `/404` and unknown routes keep the pupper view and real 404 status.

## Appearance and accessibility

Shared color tokens live in `style/tailwind.css`. Native `prefers-color-scheme` selects light or dark colors; `color-scheme: light dark` also themes browser controls. Do not duplicate device appearance in an actor, store, cookie, or hydration script. Both themes must render correctly with JavaScript disabled and respond immediately to device changes. Respect `prefers-reduced-motion`, retain keyboard focus indicators, and verify readable text contrast and narrow-screen overflow in browser tests.

Navigation uses the existing XState lifecycle, with always-visible desktop navigation at 768px and a collapsible mobile header below that breakpoint. Keep `aria-current`, the skip link, no-JavaScript navigation, and disabled-until-hydrated controls intact.

Page sections, navigation, and footer use the full viewport width with shared responsive gutters. Only reading pages constrain their text column. The document is a full-height flex shell so short pages keep the footer at the viewport bottom. Validate element bounds rather than treating left-aligned text inside a centered column as a positioning bug.

## Offline previews

Presentation components use same-file typed fixture fallback props, so rendering them with no props works offline. Cards export their same-file fixtures for detail screens. The homepage, icons, metadata and not-found view are already static offline fixtures. `/previews` in development renders populated/empty lists and every screen, exercising nested components and icons. It returns HTTP 404 in production. No preview fetches an API or embeds the real project iframes. Navigation can receive `previewViewport="narrow"` or `"wide"`; normal rendering observes the browser breakpoint at 768px. Do not replace fixtures with live credentials or network dependencies.

## Canonical tooling references

- [Official scaffold](https://svelte.dev/docs/cli/sv-create): `sv create --template minimal --types ts`.
- [SvelteKit Vite configuration](https://svelte.dev/docs/kit/@sveltejs-kit-vite): SvelteKit 3 config belongs in `vite.config.ts`, not the retired `svelte.config.js`.
- [Node adapter](https://svelte.dev/docs/kit/adapter-node): `sveltekit({ adapter: adapter() })`, then `node build`.
- [Page options](https://svelte.dev/docs/kit/page-options): explicit `entries` and `prerender = 'auto'` retain SSR fallback.
- [Svelte props and fixture defaults](https://svelte.dev/docs/svelte/$props).
- [Svelte mount lifecycle](https://svelte.dev/docs/svelte/lifecycle-hooks#onMount), [Playwright hydration guidance](https://playwright.dev/docs/navigations#hydration).
- [Device color preference](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-color-scheme), [native color schemes](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/color-scheme).
- [Official XState Svelte integration](https://stately.ai/docs/xstate-svelte), [machines and pure transitions](https://stately.ai/docs/machines).
- [Markdown-it](https://markdown-it.github.io/markdown-it/), [Vitest](https://vitest.dev/guide/), [Playwright webServer](https://playwright.dev/docs/test-webserver).
- [npm install-script approvals](https://docs.npmjs.com/cli/v11/commands/npm-install-scripts), [selector parser release contracts](https://github.com/postcss/postcss-selector-parser/blob/master/CHANGELOG.md).
