use anyhow::Result;
use axum::http::StatusCode;
use axum::{routing::get, Router};

async fn main_impl(listener: tokio::net::TcpListener) -> Result<()> {
    tracing::info!(address = %listener.local_addr()?, "listening");
    axum::serve(
        listener,
        Router::new().route("/healthz", get(health_handler)),
    )
    .await?;
    Ok(())
}

fn main() {
    setup_tracing_subscriber();

    tokio::runtime::Builder::new_multi_thread()
        .enable_all()
        .build()
        .unwrap()
        .block_on(async {
            let listener = tokio::net::TcpListener::bind("[::]:50051").await.unwrap();
            main_impl(listener).await.unwrap();
        });
}

fn setup_tracing_subscriber() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env().unwrap_or_else(|_| {
                format!(
                    "{}=info,tower_http=warn,axum::rejection=warn,hyper=warn,reqwest=warn",
                    env!("CARGO_CRATE_NAME")
                )
                .into()
            }),
        )
        .init();
}

async fn health_handler() -> (StatusCode, &'static str) {
    (StatusCode::OK, "OK")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn health_is_available_and_legacy_endpoints_return_not_found() {
        let listener = tokio::net::TcpListener::bind("127.0.0.1:0").await.unwrap();
        let address = listener.local_addr().unwrap();
        let server = tokio::spawn(main_impl(listener));
        let client = reqwest::Client::new();
        let response = client
            .get(format!("http://{address}/healthz"))
            .send()
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK);
        assert_eq!(response.text().await.unwrap(), "OK");
        for (method, path) in [
            (reqwest::Method::DELETE, "/api/v1/posts"),
            (reqwest::Method::DELETE, "/api/v2/posts"),
            (reqwest::Method::DELETE, "/api/v1/user"),
            (reqwest::Method::POST, "/api/v1/user/follow"),
            (reqwest::Method::POST, "/api/v1/user/follow-notification"),
            (reqwest::Method::GET, "/api-docs/openapi.json"),
            (reqwest::Method::GET, "/swagger-ui"),
        ] {
            let response = client
                .request(method, format!("http://{address}{path}"))
                .send()
                .await
                .unwrap();
            assert_eq!(response.status(), StatusCode::NOT_FOUND, "{path}");
        }
        server.abort();
        assert!(server.await.unwrap_err().is_cancelled());
    }
}
