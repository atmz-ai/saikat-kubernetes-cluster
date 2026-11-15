use thiserror::Error;
use types::error::ApiError;

#[derive(Error, Debug)]
pub enum Error {
    #[error("{0}")]
    Reqwest(#[from] reqwest::Error),
    #[error("invalid API URL: {0}")]
    Url(#[from] url::ParseError),
    #[error("{0}")]
    Api(#[from] ApiError),
    #[error("HTTP {status}: {body}")]
    HttpResponse { status: u16, body: String },
    #[error("invalid API response: {0}")]
    Json(#[from] serde_json::Error),
}

pub type Result<T, E = Error> = std::result::Result<T, E>;
