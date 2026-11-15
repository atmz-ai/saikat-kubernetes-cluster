use axum::Json;

#[utoipa::path(
    get,
    path = "/healthz",
    responses((status = 200, description = "Service is running", body = serde_json::Value))
)]
pub async fn healthz() -> Json<serde_json::Value> {
    Json(serde_json::json!({"status": "ok"}))
}
