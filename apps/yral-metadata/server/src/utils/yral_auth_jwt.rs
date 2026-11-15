use jsonwebtoken::DecodingKey;
use types::SessionClaims;

use crate::consts::YRAL_AUTH_ACCESS_TOKEN_ISSUER;

use super::error::Error;

#[derive(Clone)]
pub struct YralAuthJwt {
    pub decoding_key: DecodingKey,
}

impl YralAuthJwt {
    pub fn init(public_key: String) -> Result<Self, Error> {
        let decoding_key = DecodingKey::from_ec_pem(public_key.as_bytes())?;

        Ok(YralAuthJwt { decoding_key })
    }

    pub fn verify_token(&self, token: &str) -> Result<SessionClaims, Error> {
        let mut validation = jsonwebtoken::Validation::new(jsonwebtoken::Algorithm::ES256);
        validation.set_issuer(&[YRAL_AUTH_ACCESS_TOKEN_ISSUER]);
        validation.validate_aud = false;

        let token_message =
            jsonwebtoken::decode::<SessionClaims>(token, &self.decoding_key, &validation)
                .map_err(Error::Jwt)?;

        if token_message.claims.ext_is_anonymous {
            return Err(Error::AuthTokenInvalid);
        }

        Ok(token_message.claims)
    }
}
