use axum::{
    extract::Path,
    http::StatusCode,
    response::{IntoResponse, Response},
};
use std::sync::Arc;
use utoipa::openapi::security::{HttpAuthScheme, HttpBuilder, SecurityScheme};
use utoipa::{Modify, OpenApi};

use crate::utils::error::Error as AppError;
use types::{error::ApiError, SessionClaims};

struct BearerAuth;

impl Modify for BearerAuth {
    fn modify(&self, openapi: &mut utoipa::openapi::OpenApi) {
        if let Some(components) = openapi.components.as_mut() {
            components.add_security_scheme(
                "bearer_auth",
                SecurityScheme::Http(
                    HttpBuilder::new()
                        .scheme(HttpAuthScheme::Bearer)
                        .bearer_format("JWT")
                        .build(),
                ),
            )
        }
    }
}

#[derive(OpenApi)]
#[openapi(
    paths(
        crate::api::handlers::healthz,
        crate::session::get_session
    ),
    components(schemas(
        ApiError,
        SessionClaims
    )),
    modifiers(&BearerAuth)
)]
pub(crate) struct ApiDoc;

pub async fn get_swagger(Path(tail): Path<String>) -> Result<Response, AppError> {
    if tail == "swagger.json" {
        let spec = ApiDoc::openapi()
            .to_json()
            .map_err(|err| AppError::SwaggerUi(err.to_string()))?;
        return Ok((StatusCode::OK, [("content-type", "application/json")], spec).into_response());
    }

    let config =
        Arc::new(utoipa_swagger_ui::Config::new(["/explorer/swagger.json"]).use_base_layout());

    match utoipa_swagger_ui::serve(&tail, config.clone())
        .map_err(|err| AppError::SwaggerUi(err.to_string()))?
    {
        None => Err(AppError::SwaggerUi(format!("path not found: {}", tail))),
        Some(file) => Ok((
            StatusCode::OK,
            [("content-type", file.content_type)],
            file.bytes.to_vec(),
        )
            .into_response()),
    }
}

pub async fn get_swagger_root() -> Result<Response, AppError> {
    let config =
        Arc::new(utoipa_swagger_ui::Config::new(["/explorer/swagger.json"]).use_base_layout());

    match utoipa_swagger_ui::serve("index.html", config.clone())
        .map_err(|err| AppError::SwaggerUi(err.to_string()))?
    {
        None => Err(AppError::SwaggerUi("path not found".to_string())),
        Some(file) => Ok((
            StatusCode::OK,
            [("content-type", file.content_type)],
            file.bytes.to_vec(),
        )
            .into_response()),
    }
}
