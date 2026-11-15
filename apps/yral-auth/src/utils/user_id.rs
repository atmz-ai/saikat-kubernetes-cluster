use uuid::Uuid;

/// * Anonymous grants get fresh subjects rather than persistent accounts.
pub fn generate_user_id() -> String {
    Uuid::new_v4().to_string()
}
