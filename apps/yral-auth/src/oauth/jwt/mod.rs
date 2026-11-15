use jsonwebtoken::jwk::Jwk;
use serde::{Deserialize, Serialize};
use url::Url;

use super::CodeChallenge;

pub mod generate;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TokenUse {
    AuthorizationCode,
    Access,
    Id,
    Refresh,
}

pub struct TokenIdentity {
    pub subject: String,
    pub client_identifier: String,
    pub nonce: Option<String>,
    pub is_anonymous: bool,
    pub email: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuthCodeClaims {
    aud: String,
    pub exp: usize,
    iat: usize,
    iss: String,
    pub sub: String,
    pub token_use: TokenUse,
    pub jti: String,
    pub ext_redirect_uri: Url,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub nonce: Option<String>,
    pub ext_code_challenge_s256: CodeChallenge,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ext_email: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccessTokenClaims {
    aud: String,
    exp: usize,
    iat: usize,
    iss: String,
    sub: String,
    token_use: TokenUse,
    #[serde(skip_serializing_if = "Option::is_none")]
    nonce: Option<String>,
    ext_is_anonymous: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IdTokenClaims {
    aud: String,
    exp: usize,
    iat: usize,
    iss: String,
    sub: String,
    token_use: TokenUse,
    #[serde(skip_serializing_if = "Option::is_none")]
    nonce: Option<String>,
    ext_is_anonymous: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    email: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RefreshTokenClaims {
    aud: String,
    exp: usize,
    iat: usize,
    iss: String,
    pub sub: String,
    pub token_use: TokenUse,
    #[serde(skip_serializing_if = "Option::is_none")]
    nonce: Option<String>,
    pub ext_is_anonymous: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ext_email: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClientSecretClaims {
    pub aud: String,
    pub exp: usize,
    pub iat: usize,
    pub iss: String,
    pub sub: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct JsonWebKeySet {
    pub keys: Vec<Jwk>,
}
