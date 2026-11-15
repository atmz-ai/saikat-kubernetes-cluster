use serde::{Deserialize, Serialize};
use thiserror::Error;
use utoipa::ToSchema;

#[derive(Deserialize, Serialize, Error, Debug, PartialEq, ToSchema)]
#[non_exhaustive]
pub enum ApiError {
    #[error("jwt error - invalid token")]
    Jwt,
    #[error("invalid authentication token")]
    AuthToken,
    #[error("missing authentication token")]
    AuthTokenMissing,
    #[error("unknown: {0}")]
    Unknown(String),
}
