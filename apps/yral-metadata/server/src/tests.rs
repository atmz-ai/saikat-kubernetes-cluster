use axum::{
    body::{to_bytes, Body},
    http::{Method, Request, StatusCode},
};
use jsonwebtoken::{encode, Algorithm, EncodingKey, Header};
use std::sync::Arc;
use tower::ServiceExt;
use types::{error::ApiError, ApiResult, SessionClaims};
use utoipa::OpenApi;

use crate::{application_router, config::AppConfig, services::openapi::ApiDoc, state::AppState};

pub(crate) const TEST_PUBLIC_KEY: &str = "-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAER7lk/VOxdOgzYkWtybsgmJbOdWSB
VR0mVIxiwWobGAjSBlcuqLJaceOUbDI08PiXehMi/yFbHUgq28oZFFUkcg==
-----END PUBLIC KEY-----";

const TEST_PRIVATE_KEY: &str = "-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgkWH9hy5Xl79jQ+bm
3lKnWpxV/Y5pAaSeF8IkcZ5AbTqhRANCAARHuWT9U7F06DNiRa3JuyCYls51ZIFV
HSZUjGLBahsYCNIGVy6oslpx45RsMjTw+Jd6EyL/IVsdSCrbyhkUVSRy
-----END PRIVATE KEY-----";

#[tokio::test]
async fn retired_routes_return_not_found_instead_of_success() {
    let configuration = AppConfig {
        bind_address: "127.0.0.1:0".parse().unwrap(),
        yral_auth_public_key: TEST_PUBLIC_KEY.into(),
    };
    let application = application_router(Arc::new(AppState::new(&configuration).unwrap()));
    for (method, path) in [
        (Method::GET, "/metadata/2vxsx-fae"),
        (Method::POST, "/metadata/2vxsx-fae"),
        (Method::POST, "/admin/metadata/2vxsx-fae"),
        (Method::DELETE, "/metadata/bulk"),
        (Method::POST, "/metadata-bulk"),
        (Method::POST, "/email/2vxsx-fae"),
        (Method::POST, "/signup/2vxsx-fae"),
        (Method::POST, "/v2/update_session_as_registered"),
        (Method::POST, "/notifications/2vxsx-fae"),
        (Method::DELETE, "/notifications/2vxsx-fae"),
    ] {
        let response = application
            .clone()
            .oneshot(
                Request::builder()
                    .method(method)
                    .uri(path)
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::NOT_FOUND, "{path}");
        assert!(!response.status().is_success(), "{path}");
    }
}

#[tokio::test]
async fn health_and_openapi_work_without_backend_configuration() {
    let configuration = AppConfig {
        bind_address: "127.0.0.1:0".parse().unwrap(),
        yral_auth_public_key: TEST_PUBLIC_KEY.into(),
    };
    let application = application_router(Arc::new(AppState::new(&configuration).unwrap()));
    for path in ["/healthz", "/metadata/health"] {
        let response = application
            .clone()
            .oneshot(Request::builder().uri(path).body(Body::empty()).unwrap())
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK, "{path}");
        assert_ne!(response.status(), StatusCode::NOT_FOUND, "{path}");
        let body = to_bytes(response.into_body(), 1024).await.unwrap();
        assert_eq!(&body[..], br#"{"status":"ok"}"#, "{path}");
    }

    for path in ["/explorer/", "/explorer/swagger.json"] {
        let response = application
            .clone()
            .oneshot(Request::builder().uri(path).body(Body::empty()).unwrap())
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::OK, "{path}");
    }

    let document = serde_json::to_value(ApiDoc::openapi()).unwrap();
    let paths = document["paths"].as_object().unwrap();
    assert_eq!(paths.len(), 2);
    assert!(paths.contains_key("/session"));
    assert!(paths.contains_key("/healthz"));
    let schemas = document["components"]["schemas"].as_object().unwrap();
    assert!(!schemas.contains_key("UserMetadata"));
    assert!(!schemas.contains_key("UpdateUserSessionRequest"));
    assert!(schemas["OkWrapper_SessionClaims"]["properties"]
        .get("Ok")
        .is_some());
}

#[tokio::test]
async fn session_returns_verified_claims_and_rejects_invalid_tokens() {
    let configuration = AppConfig {
        bind_address: "127.0.0.1:0".parse().unwrap(),
        yral_auth_public_key: TEST_PUBLIC_KEY.into(),
    };
    let application = application_router(Arc::new(AppState::new(&configuration).unwrap()));
    for (expiration, issuer, anonymous, expected_status) in [
        (
            4_102_444_800,
            "https://auth.yral.com",
            false,
            StatusCode::OK,
        ),
        (1, "https://auth.yral.com", false, StatusCode::UNAUTHORIZED),
        (
            4_102_444_800,
            "https://invalid.example",
            false,
            StatusCode::UNAUTHORIZED,
        ),
        (
            4_102_444_800,
            "https://auth.yral.com",
            true,
            StatusCode::UNAUTHORIZED,
        ),
    ] {
        let claims = SessionClaims {
            aud: "metadata-test".into(),
            exp: expiration,
            iat: 1,
            iss: issuer.into(),
            sub: "test-user".into(),
            nonce: None,
            ext_is_anonymous: anonymous,
        };
        let authentication_token = encode(
            &Header::new(Algorithm::ES256),
            &claims,
            &EncodingKey::from_ec_pem(TEST_PRIVATE_KEY.as_bytes()).unwrap(),
        )
        .unwrap();
        let response = application
            .clone()
            .oneshot(
                Request::builder()
                    .uri("/session")
                    .header("Authorization", format!("Bearer {authentication_token}"))
                    .body(Body::empty())
                    .unwrap(),
            )
            .await
            .unwrap();
        assert_eq!(response.status(), expected_status);
        let body = to_bytes(response.into_body(), 4096).await.unwrap();
        let result: ApiResult<SessionClaims> = serde_json::from_slice(&body).unwrap();
        if expected_status == StatusCode::OK {
            assert_eq!(result.unwrap(), claims);
        } else {
            assert!(result.is_err());
        }
    }
}

#[tokio::test]
async fn client_health_and_session_work_against_the_server() {
    let configuration = AppConfig {
        bind_address: "127.0.0.1:0".parse().unwrap(),
        yral_auth_public_key: TEST_PUBLIC_KEY.into(),
    };
    let application = application_router(Arc::new(AppState::new(&configuration).unwrap()));
    let listener = tokio::net::TcpListener::bind(configuration.bind_address)
        .await
        .unwrap();
    let base_url = format!("http://{}/", listener.local_addr().unwrap())
        .parse()
        .unwrap();
    let server = tokio::spawn(async move { axum::serve(listener, application).await.unwrap() });
    let client = metadata_client::MetadataClient::<true>::with_base_url(base_url);
    client.healthz().await.unwrap();
    assert!(matches!(
        client.get_session().await.unwrap_err(),
        metadata_client::Error::Api(ApiError::AuthTokenMissing)
    ));

    let claims = SessionClaims {
        aud: "metadata-test".into(),
        exp: 4_102_444_800,
        iat: 1,
        iss: "https://auth.yral.com".into(),
        sub: "test-user".into(),
        nonce: None,
        ext_is_anonymous: false,
    };
    let authentication_token = encode(
        &Header::new(Algorithm::ES256),
        &claims,
        &EncodingKey::from_ec_pem(TEST_PRIVATE_KEY.as_bytes()).unwrap(),
    )
    .unwrap();
    let authenticated_client = client.clone().with_jwt_token(authentication_token);
    assert_eq!(authenticated_client.get_session().await.unwrap(), claims);

    let forged_token = encode(
        &Header::new(Algorithm::HS256),
        &claims,
        &EncodingKey::from_secret(b"test-secret"),
    )
    .unwrap();
    for invalid_token in ["not-a-token".to_string(), forged_token] {
        let invalid_client = client.clone().with_jwt_token(invalid_token);
        let error = invalid_client.get_session().await.unwrap_err();
        assert!(matches!(
            error,
            metadata_client::Error::HttpResponse { status: 401, ref body }
                if body == r#"{"Err":"Jwt"}"#
        ));
    }
    server.abort();
    assert!(server.await.unwrap_err().is_cancelled());
}

#[tokio::test]
async fn session_requires_a_valid_bearer_header() {
    let configuration = AppConfig {
        bind_address: "127.0.0.1:0".parse().unwrap(),
        yral_auth_public_key: TEST_PUBLIC_KEY.into(),
    };
    let application = application_router(Arc::new(AppState::new(&configuration).unwrap()));
    for (authorization, expected_error) in [
        (None, ApiError::AuthTokenMissing),
        (Some(""), ApiError::AuthToken),
        (Some("Bearer "), ApiError::AuthToken),
        (Some("not-a-token"), ApiError::AuthToken),
        (Some("Basic not-a-token"), ApiError::AuthToken),
        (Some("Bearer not-a-token"), ApiError::Jwt),
    ] {
        let mut request = Request::builder().uri("/session");
        if let Some(authorization) = authorization {
            request = request.header("Authorization", authorization);
        }
        let response = application
            .clone()
            .oneshot(request.body(Body::empty()).unwrap())
            .await
            .unwrap();
        assert_eq!(response.status(), StatusCode::UNAUTHORIZED);
        let body = to_bytes(response.into_body(), 4096).await.unwrap();
        let result: ApiResult<SessionClaims> = serde_json::from_slice(&body).unwrap();
        assert_eq!(result.unwrap_err(), expected_error);
    }
}
