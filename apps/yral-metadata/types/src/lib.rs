pub mod error;
pub mod identity;

pub use identity::{Error, Message, Signature};
use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

pub type ApiResult<T> = Result<T, error::ApiError>;

#[derive(Debug, Serialize, Deserialize, PartialEq, Eq, ToSchema)]
pub struct SessionClaims {
    pub aud: String,
    pub exp: u64,
    pub iat: u64,
    pub iss: String,
    pub sub: String,
    pub nonce: Option<String>,
    pub ext_is_anonymous: bool,
}
