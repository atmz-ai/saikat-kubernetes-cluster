use serde::{Deserialize, Serialize};
use utoipa::ToSchema;

#[derive(Debug, ToSchema, Serialize, Deserialize)]
pub struct ErrorWrapper<T: ToSchema> {
    #[serde(rename = "Err")]
    error: T,
}

#[derive(Debug, ToSchema, Serialize, Deserialize)]
pub struct OkWrapper<T: ToSchema> {
    #[serde(rename = "Ok")]
    value: T,
}
