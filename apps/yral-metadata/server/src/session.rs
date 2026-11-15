use axum::{extract::State, http::HeaderMap, Json};
use std::sync::Arc;
use types::{error::ApiError, ApiResult, SessionClaims};

use crate::{
    services::error_wrappers::{ErrorWrapper, OkWrapper},
    state::AppState,
    utils::error::{Error, Result},
};

#[utoipa::path(
    get,
    path = "/session",
    responses(
        (status = 200, description = "Verified registered-user token claims; no session mutation", body = OkWrapper<SessionClaims>),
        (status = 401, description = "Auth token missing or invalid", body = ErrorWrapper<ApiError>)
    ),
    security(("bearer_auth" = []))
)]
pub async fn get_session(
    State(state): State<Arc<AppState>>,
    headers: HeaderMap,
) -> Result<Json<ApiResult<SessionClaims>>> {
    let authentication_token = headers
        .get("Authorization")
        .ok_or(Error::AuthTokenMissing)?
        .to_str()
        .map_err(|_| Error::AuthTokenInvalid)?
        .strip_prefix("Bearer ")
        .filter(|token| !token.is_empty())
        .ok_or(Error::AuthTokenInvalid)?;

    let claims = state.yral_auth_jwt.verify_token(authentication_token)?;
    Ok(Json(Ok(claims)))
}
