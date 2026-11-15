use axum::{
    http::StatusCode,
    response::{IntoResponse, Response},
    Json,
};
use thiserror::Error;
use types::{error::ApiError, ApiResult};

#[derive(Error, Debug)]
pub enum Error {
    #[error(transparent)]
    Io(#[from] std::io::Error),
    #[error("failed to load config {0}")]
    Config(#[from] config::ConfigError),
    #[error("jwt {0}")]
    Jwt(#[from] jsonwebtoken::errors::Error),
    #[error("auth token missing")]
    AuthTokenMissing,
    #[error("auth token invalid")]
    AuthTokenInvalid,
    #[error("swagger ui error {0}")]
    SwaggerUi(String),
}

impl IntoResponse for Error {
    fn into_response(self) -> Response {
        let (status, error) = match self {
            Self::Jwt(_) => (StatusCode::UNAUTHORIZED, ApiError::Jwt),
            Self::AuthTokenMissing => (StatusCode::UNAUTHORIZED, ApiError::AuthTokenMissing),
            Self::AuthTokenInvalid => (StatusCode::UNAUTHORIZED, ApiError::AuthToken),
            error => {
                log::error!("internal error: {error}");
                (
                    StatusCode::INTERNAL_SERVER_ERROR,
                    ApiError::Unknown("internal error, reported".into()),
                )
            }
        };
        let response: ApiResult<()> = Err(error);
        (status, Json(response)).into_response()
    }
}

pub type Result<T, E = Error> = std::result::Result<T, E>;
