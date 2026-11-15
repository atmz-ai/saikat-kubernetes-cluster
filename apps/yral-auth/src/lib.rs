// TODO(auth-page-all-providers): the web app's login surfaces support
// only a subset of the providers the mobile apps offer. Add:
//   - Sign in with Apple (oauth flow in src/oauth_provider.rs + the
//     Apple button on the auth page in src/page/auth.rs)

// TODO(ssr-to-client-spa): this app is a cargo-leptos SSR-rendered app
// (features ssr + hydrate; hydrate_body in lib.rs, the axum server in
// src/main.rs). Migrate to a fully client-rendered WASM SPA: drop the
// ssr feature, ship one wasm binary mounted via mount::mount_to_body,
// serve static assets from a plain file server (or the k8s nginx
// config in the infra repo), keep the API routes as a separate
// service. Rationale: the auth app is fully interactive post-load —
// SSR buys nothing but a Rust compile+server per deploy; a WASM SPA
// collapses the deploy to static hosting. The my-website app's islands
// model remains a separate SSR architecture.
#[cfg(feature = "ssr")]
pub mod api;
pub mod app;
pub mod components;
pub mod consts;
pub mod context;
pub mod error;
#[cfg(feature = "ssr")]
pub mod middleware;
pub mod oauth;
#[cfg(feature = "ssr")]
pub mod oauth_provider;
mod page;
pub mod utils;

#[cfg(feature = "hydrate")]
pub fn hydrate() {
    use crate::app::app;

    // initializes logging using the `log` crate
    _ = console_log::init_with_level(log::Level::Debug);
    console_error_panic_hook::set_once();

    leptos::mount::hydrate_body(app);
}
