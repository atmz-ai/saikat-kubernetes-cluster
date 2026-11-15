use axum::{
    http::HeaderMap,
    response::{IntoResponse, Response},
    Extension, Form, Json,
};
use sha2::{Digest, Sha256};
use std::sync::Arc;
use url::Url;

use crate::{
    context::server::ServerCtx,
    oauth::{
        client_validation::{ClientIdValidator, OAuthClientType, ValidationRes},
        jwt::{
            generate::{generate_access_token_and_id_token_jwt, generate_refresh_token_jwt},
            AuthCodeClaims, RefreshTokenClaims, TokenIdentity, TokenUse,
        },
        AuthGrantQuery, PartialOIDCConfig, TokenGrantError, TokenGrantErrorKind, TokenGrantRes,
        TokenGrantResult,
    },
    utils::{
        server_url::get_server_url_from_headers, time::current_epoch_secs,
        user_id::generate_user_id,
    },
};

fn build_token_grant(
    encoding_key: &jsonwebtoken::EncodingKey,
    identity: TokenIdentity,
    validation: ValidationRes,
    server_url: &str,
) -> TokenGrantRes {
    let (access_token, id_token) = generate_access_token_and_id_token_jwt(
        encoding_key,
        &identity,
        validation.access_max_age,
        server_url,
    );
    let refresh_token = generate_refresh_token_jwt(
        encoding_key,
        &identity,
        validation.refresh_max_age,
        server_url,
    );
    TokenGrantRes::new(access_token, id_token, refresh_token)
}

fn verify_pkce(code_verifier: &str, challenge: &[u8; 32]) -> bool {
    let fingerprint: [u8; 32] = Sha256::digest(code_verifier.as_bytes()).into();
    fingerprint == *challenge
}

async fn verify_client_secret(
    context: &ServerCtx,
    client_identifier: &str,
    client_secret: Option<String>,
    redirect_uri: Option<&Url>,
) -> Result<ValidationRes, TokenGrantError> {
    context
        .validator
        .full_validation(
            &context.jwk_pairs.client_tokens.decoding_key,
            client_identifier,
            redirect_uri,
            client_secret.as_deref(),
        )
        .await
        .map_err(|error| TokenGrantError {
            error: TokenGrantErrorKind::InvalidClient,
            error_description: error.to_string(),
        })
}

impl IntoResponse for TokenGrantResult {
    fn into_response(self) -> Response {
        match self {
            Self::Ok(grant) => Json(grant).into_response(),
            Self::Err(error) => {
                let status_code = error.error.status_code();
                let mut response = Json(error).into_response();
                *response.status_mut() = status_code;
                response
            }
        }
    }
}

pub async fn handle_well_known_jwks(Extension(context): Extension<Arc<ServerCtx>>) -> Response {
    Json(context.jwk_pairs.well_known_jwks.clone()).into_response()
}

pub async fn handle_oidc_configuration(headers: HeaderMap) -> Response {
    let server_url = get_server_url_from_headers(&headers);
    let jwks_uri = format!("{server_url}/.well-known/jwks.json");
    Json(PartialOIDCConfig { jwks_uri }).into_response()
}

pub async fn healthz() -> Response {
    Json(serde_json::json!({"status": "ok"})).into_response()
}

pub async fn handle_oauth_token_grant(
    Extension(context): Extension<Arc<ServerCtx>>,
    headers: HeaderMap,
    Form(request): Form<AuthGrantQuery>,
) -> Response {
    let server_url = get_server_url_from_headers(&headers);
    let result = match request {
        AuthGrantQuery::AuthorizationCode {
            code,
            redirect_uri,
            code_verifier,
            client_id,
            client_secret,
        } => {
            handle_authorization_code_grant(
                &context,
                code,
                redirect_uri,
                code_verifier,
                client_id,
                client_secret,
                &server_url,
            )
            .await
        }
        AuthGrantQuery::RefreshToken {
            refresh_token,
            client_id,
            client_secret,
        } => {
            handle_refresh_token_grant(
                &context,
                refresh_token,
                client_id,
                client_secret,
                &server_url,
            )
            .await
        }
        AuthGrantQuery::ClientCredentials {
            client_id,
            client_secret,
        } => handle_client_credentials_grant(&context, client_id, client_secret, &server_url).await,
    };

    match result {
        Ok(grant) => Json(grant).into_response(),
        Err(error) => {
            let status_code = error.error.status_code();
            let mut response = Json(error).into_response();
            *response.status_mut() = status_code;
            response
        }
    }
}

async fn handle_authorization_code_grant(
    context: &ServerCtx,
    code: String,
    redirect_uri: Url,
    code_verifier: String,
    client_identifier: String,
    client_secret: Option<String>,
    server_url: &str,
) -> Result<TokenGrantRes, TokenGrantError> {
    let client_validation = verify_client_secret(
        context,
        &client_identifier,
        client_secret,
        Some(&redirect_uri),
    )
    .await?;
    let mut validation = jsonwebtoken::Validation::new(jsonwebtoken::Algorithm::ES256);
    validation.set_audience(&[&client_identifier]);
    validation.set_issuer(&[server_url]);
    validation.leeway = 0;

    let claims = jsonwebtoken::decode::<AuthCodeClaims>(
        &code,
        &context.jwk_pairs.auth_tokens.decoding_key,
        &validation,
    )
    .map_err(|error| TokenGrantError {
        error: TokenGrantErrorKind::InvalidGrant,
        error_description: error.to_string(),
    })?
    .claims;

    if claims.token_use != TokenUse::AuthorizationCode
        || claims.ext_redirect_uri != redirect_uri
        || !verify_pkce(&code_verifier, &claims.ext_code_challenge_s256.0)
    {
        return Err(TokenGrantError {
            error: TokenGrantErrorKind::InvalidGrant,
            error_description: "Invalid authorization code, redirect URI, or verifier".to_string(),
        });
    }

    if !context
        .pending_authorization_codes
        .consume(&code, current_epoch_secs())
        .map_err(|error| TokenGrantError {
            error: TokenGrantErrorKind::ServerError,
            error_description: error,
        })?
    {
        return Err(TokenGrantError {
            error: TokenGrantErrorKind::InvalidGrant,
            error_description: "Authorization code expired, already used, or unknown".to_string(),
        });
    }

    Ok(build_token_grant(
        &context.jwk_pairs.auth_tokens.encoding_key,
        TokenIdentity {
            subject: claims.sub,
            client_identifier,
            nonce: claims.nonce,
            is_anonymous: false,
            email: claims.ext_email,
        },
        client_validation,
        server_url,
    ))
}

async fn handle_refresh_token_grant(
    context: &ServerCtx,
    refresh_token: String,
    client_identifier: String,
    client_secret: Option<String>,
    server_url: &str,
) -> Result<TokenGrantRes, TokenGrantError> {
    let client_validation =
        verify_client_secret(context, &client_identifier, client_secret, None).await?;
    let mut validation = jsonwebtoken::Validation::new(jsonwebtoken::Algorithm::ES256);
    validation.set_audience(&[&client_identifier]);
    validation.set_issuer(&[server_url, "https://auth.yral.com"]);

    let claims = jsonwebtoken::decode::<RefreshTokenClaims>(
        &refresh_token,
        &context.jwk_pairs.auth_tokens.decoding_key,
        &validation,
    )
    .map_err(|error| TokenGrantError {
        error: TokenGrantErrorKind::InvalidGrant,
        error_description: error.to_string(),
    })?
    .claims;

    if claims.token_use != TokenUse::Refresh {
        return Err(TokenGrantError {
            error: TokenGrantErrorKind::InvalidGrant,
            error_description: "Expected a refresh token".to_string(),
        });
    }

    Ok(build_token_grant(
        &context.jwk_pairs.auth_tokens.encoding_key,
        TokenIdentity {
            subject: claims.sub,
            client_identifier,
            nonce: None,
            is_anonymous: claims.ext_is_anonymous,
            email: claims.ext_email,
        },
        client_validation,
        server_url,
    ))
}

async fn handle_client_credentials_grant(
    context: &ServerCtx,
    client_identifier: String,
    client_secret: Option<String>,
    server_url: &str,
) -> Result<TokenGrantRes, TokenGrantError> {
    let client_validation =
        verify_client_secret(context, &client_identifier, client_secret, None).await?;
    let is_anonymous = client_validation.kind != OAuthClientType::BackendService;
    let subject = if is_anonymous {
        generate_user_id()
    } else {
        format!("backend:{client_identifier}")
    };

    Ok(build_token_grant(
        &context.jwk_pairs.auth_tokens.encoding_key,
        TokenIdentity {
            subject,
            client_identifier,
            nonce: None,
            is_anonymous,
            email: None,
        },
        client_validation,
        server_url,
    ))
}

#[cfg(test)]
mod tests;
