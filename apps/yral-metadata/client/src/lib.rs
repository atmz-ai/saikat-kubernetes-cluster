pub mod consts;
mod error;

pub use error::*;
pub use types::SessionClaims;

use consts::DEFAULT_API_URL;
use reqwest::Url;
use types::ApiResult;

#[derive(Clone, Debug)]
pub struct MetadataClient<const AUTH: bool> {
    base_url: Url,
    client: reqwest::Client,
    authentication_token: Option<String>,
}

impl Default for MetadataClient<false> {
    fn default() -> Self {
        Self::with_base_url(Url::parse(DEFAULT_API_URL).unwrap())
    }
}

impl<const AUTH: bool> MetadataClient<AUTH> {
    pub fn with_base_url(base_url: Url) -> Self {
        Self {
            base_url,
            client: Default::default(),
            authentication_token: None,
        }
    }

    pub async fn healthz(&self) -> Result<()> {
        let mut response = self
            .client
            .get(self.base_url.join("healthz")?)
            .send()
            .await?;
        let status = response.status();
        if !status.is_success() {
            let mut body = Vec::new();
            while let Some(chunk) = response.chunk().await? {
                let remaining = (1024 * 1024_usize).saturating_sub(body.len());
                body.extend_from_slice(&chunk[..chunk.len().min(remaining)]);
                if body.len() == 1024 * 1024 {
                    break;
                }
            }
            return Err(Error::HttpResponse {
                status: status.as_u16(),
                body: String::from_utf8_lossy(&body).into_owned(),
            });
        }
        Ok(())
    }
}

impl MetadataClient<true> {
    pub fn with_jwt_token(self, authentication_token: String) -> Self {
        Self {
            authentication_token: Some(authentication_token),
            ..self
        }
    }

    pub async fn get_session(&self) -> Result<SessionClaims> {
        let authentication_token = self
            .authentication_token
            .as_ref()
            .ok_or(Error::Api(types::error::ApiError::AuthTokenMissing))?;
        let mut response = self
            .client
            .get(self.base_url.join("session")?)
            .bearer_auth(authentication_token)
            .send()
            .await?;
        let status = response.status();
        let mut body = Vec::new();
        while let Some(chunk) = response.chunk().await? {
            let remaining = (1024 * 1024_usize).saturating_sub(body.len());
            body.extend_from_slice(&chunk[..chunk.len().min(remaining)]);
            if body.len() == 1024 * 1024 {
                break;
            }
        }
        if !status.is_success() {
            return Err(Error::HttpResponse {
                status: status.as_u16(),
                body: String::from_utf8_lossy(&body).into_owned(),
            });
        }
        let result: ApiResult<SessionClaims> = serde_json::from_slice(&body)?;
        Ok(result?)
    }
}
