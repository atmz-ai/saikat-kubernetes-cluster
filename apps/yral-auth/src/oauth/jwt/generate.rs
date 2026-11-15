use web_time::Duration;

use super::{
    AccessTokenClaims, AuthCodeClaims, IdTokenClaims, RefreshTokenClaims, TokenIdentity, TokenUse,
};
use crate::{consts::AUTH_TOKEN_KID, oauth::AuthQuery, utils::time::current_epoch_secs};

pub fn generate_code_grant_jwt(
    encoding_key: &jsonwebtoken::EncodingKey,
    user_id: &str,
    server_url: &str,
    query: AuthQuery,
    email: Option<String>,
) -> String {
    let iat = current_epoch_secs();

    jsonwebtoken::encode(
        &jwt_header(),
        &AuthCodeClaims {
            aud: query.client_id.clone(),
            iat,
            exp: iat + 10 * 60,
            iss: server_url.to_string(),
            sub: user_id.to_string(),
            token_use: TokenUse::AuthorizationCode,
            jti: uuid::Uuid::new_v4().to_string(),
            ext_redirect_uri: query.redirect_uri,
            nonce: query.nonce,
            ext_code_challenge_s256: query.code_challenge,
            ext_email: email,
        },
        encoding_key,
    )
    .expect("Failed to encode JWT")
}

fn jwt_header() -> jsonwebtoken::Header {
    let mut header = jsonwebtoken::Header::new(jsonwebtoken::Algorithm::ES256);
    header.kid = Some(AUTH_TOKEN_KID.to_string());

    header
}

/// * Returns the access token followed by the ID token.
pub fn generate_access_token_and_id_token_jwt(
    encoding_key: &jsonwebtoken::EncodingKey,
    identity: &TokenIdentity,
    max_age: Duration,
    server_url: &str,
) -> (String, String) {
    let iat = current_epoch_secs();

    let access_claims = AccessTokenClaims {
        aud: identity.client_identifier.clone(),
        exp: iat + max_age.as_secs() as usize,
        iat,
        iss: server_url.to_string(),
        sub: identity.subject.clone(),
        token_use: TokenUse::Access,
        nonce: identity.nonce.clone(),
        ext_is_anonymous: identity.is_anonymous,
    };
    let id_claims = IdTokenClaims {
        aud: identity.client_identifier.clone(),
        exp: iat + max_age.as_secs() as usize,
        iat,
        iss: server_url.to_string(),
        sub: identity.subject.clone(),
        token_use: TokenUse::Id,
        nonce: identity.nonce.clone(),
        ext_is_anonymous: identity.is_anonymous,
        email: identity.email.clone(),
    };

    let header = jwt_header();

    let access_token =
        jsonwebtoken::encode(&header, &access_claims, encoding_key).expect("failed to encode JWT");
    let id_token =
        jsonwebtoken::encode(&header, &id_claims, encoding_key).expect("failed to encode JWT");

    (access_token, id_token)
}

pub fn generate_refresh_token_jwt(
    encoding_key: &jsonwebtoken::EncodingKey,
    identity: &TokenIdentity,
    max_age: Duration,
    server_url: &str,
) -> String {
    let iat = current_epoch_secs();

    jsonwebtoken::encode(
        &jwt_header(),
        &RefreshTokenClaims {
            aud: identity.client_identifier.clone(),
            exp: iat + max_age.as_secs() as usize,
            iat,
            iss: server_url.to_string(),
            sub: identity.subject.clone(),
            token_use: TokenUse::Refresh,
            nonce: identity.nonce.clone(),
            ext_is_anonymous: identity.is_anonymous,
            ext_email: identity.email.clone(),
        },
        encoding_key,
    )
    .expect("failed to encode JWT")
}
