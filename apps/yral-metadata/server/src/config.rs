use std::net::SocketAddr;

use config::{Config, ConfigError, Environment, File};
use serde::Deserialize;
#[derive(Deserialize)]
pub struct AppConfig {
    pub bind_address: SocketAddr,
    pub yral_auth_public_key: String,
}

impl AppConfig {
    pub fn load() -> Result<Self, ConfigError> {
        let configuration = Config::builder()
            .add_source(File::with_name("config.toml").required(false))
            .add_source(Environment::default())
            .build()?;

        configuration.try_deserialize()
    }
}
