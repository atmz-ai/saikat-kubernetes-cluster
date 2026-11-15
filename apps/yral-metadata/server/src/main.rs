mod api;
mod config;
mod consts;
mod services;
mod session;
mod state;
mod utils;

#[cfg(test)]
mod tests;

use std::sync::Arc;

use axum::{routing::get, Router};
use config::AppConfig;
use state::AppState;
use tower_http::cors::CorsLayer;
use utils::error::*;

fn setup_tracing_subscriber() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info,hyper=warn,reqwest=warn,tower_http=warn".into()),
        )
        .init();
}

async fn main_impl() -> Result<()> {
    let configuration = AppConfig::load()?;
    let state = Arc::new(AppState::new(&configuration)?);
    let application = application_router(state);
    let listener = tokio::net::TcpListener::bind(configuration.bind_address)
        .await
        .map_err(Error::Io)?;

    log::info!("Server starting on {}", configuration.bind_address);
    axum::serve(listener, application)
        .await
        .map_err(Error::Io)?;
    Ok(())
}

fn application_router(state: Arc<AppState>) -> Router {
    Router::new()
        .route("/session", get(session::get_session))
        .route("/explorer/{*tail}", get(services::openapi::get_swagger))
        .route("/explorer/", get(services::openapi::get_swagger_root))
        .route("/healthz", get(api::handlers::healthz))
        .route("/metadata/health", get(api::handlers::healthz))
        .layer(CorsLayer::permissive())
        .with_state(state)
}

fn main() {
    setup_tracing_subscriber();

    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap()
        .block_on(async {
            main_impl().await.unwrap();
        });
}
