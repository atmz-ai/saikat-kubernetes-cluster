use crate::{config::AppConfig, utils::error::Result, utils::yral_auth_jwt::YralAuthJwt};

#[derive(Clone)]
pub struct AppState {
    pub yral_auth_jwt: YralAuthJwt,
}

impl AppState {
    pub fn new(configuration: &AppConfig) -> Result<Self> {
        Ok(Self {
            yral_auth_jwt: YralAuthJwt::init(configuration.yral_auth_public_key.clone())?,
        })
    }
}
