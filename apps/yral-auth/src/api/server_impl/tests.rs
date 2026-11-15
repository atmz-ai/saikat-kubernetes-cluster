use super::*;
use crate::{
    context::server::{JwkPair, JwkPairs},
    oauth::{
        client_validation::ClientIdValidatorImpl,
        jwt::{generate::generate_code_grant_jwt, JsonWebKeySet},
        pending_grants::PendingGrants,
        AuthResponse, CodeChallenge, CodeChallengeMethod,
    },
};
use base64::{engine::general_purpose::STANDARD, Engine};
use p256::pkcs8::{EncodePrivateKey, EncodePublicKey, LineEnding};
use serde_json::Value;
use std::collections::HashMap;

const CLIENT_IDENTIFIER: &str = "e1a6a7fb-8a1d-42dc-87b4-13ff94ecbe34";
const ISSUER: &str = "https://auth.yral.com";
const REDIRECT_URI: &str = "com.yral.iosApp://oauth/callback";
const VERIFIER: &str = "a-long-client-generated-pkce-verifier-for-this-login";

fn test_context() -> ServerCtx {
    let secret = p256::SecretKey::from_slice(&[7; 32]).unwrap();
    let private_pem = secret.to_pkcs8_pem(LineEnding::LF).unwrap();
    let public_pem = secret
        .public_key()
        .to_public_key_pem(LineEnding::LF)
        .unwrap();
    let client_private_der = hex::decode("302e020100300506032b6570042204209d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60").unwrap();
    let client_public_der = hex::decode(
        "302a300506032b6570032100d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a",
    )
    .unwrap();
    let client_private_pem = format!(
        "-----BEGIN PRIVATE KEY-----\n{}\n-----END PRIVATE KEY-----",
        STANDARD.encode(client_private_der)
    );
    let client_public_pem = format!(
        "-----BEGIN PUBLIC KEY-----\n{}\n-----END PUBLIC KEY-----",
        STANDARD.encode(client_public_der)
    );

    ServerCtx {
        oauth_http_client: openidconnect::reqwest::Client::new(),
        oauth_providers: HashMap::new(),
        cookie_key: axum_extra::extract::cookie::Key::from(&[0; 64]),
        jwk_pairs: JwkPairs {
            auth_tokens: JwkPair {
                encoding_key: jsonwebtoken::EncodingKey::from_ec_pem(private_pem.as_bytes())
                    .unwrap(),
                decoding_key: jsonwebtoken::DecodingKey::from_ec_pem(public_pem.as_bytes())
                    .unwrap(),
            },
            client_tokens: JwkPair {
                encoding_key: jsonwebtoken::EncodingKey::from_ed_pem(client_private_pem.as_bytes())
                    .unwrap(),
                decoding_key: jsonwebtoken::DecodingKey::from_ed_pem(client_public_pem.as_bytes())
                    .unwrap(),
            },
            well_known_jwks: JsonWebKeySet { keys: Vec::new() },
        },
        pending_oauth_states: PendingGrants::default(),
        pending_authorization_codes: PendingGrants::default(),
        validator: ClientIdValidatorImpl::Const(Default::default()),
    }
}

fn issued_code(context: &ServerCtx) -> String {
    let code = generate_code_grant_jwt(
        &context.jwk_pairs.auth_tokens.encoding_key,
        "verified-provider-subject",
        ISSUER,
        crate::oauth::AuthQuery {
            response_type: AuthResponse::Code,
            client_id: CLIENT_IDENTIFIER.to_string(),
            redirect_uri: REDIRECT_URI.parse().unwrap(),
            state: "client-state".to_string(),
            code_challenge: CodeChallenge(Sha256::digest(VERIFIER.as_bytes()).into()),
            code_challenge_method: CodeChallengeMethod::S256,
            nonce: Some("client-nonce".to_string()),
        },
        Some("person@example.com".to_string()),
    );
    let now = current_epoch_secs();
    context
        .pending_authorization_codes
        .issue(&code, now + 600, now)
        .unwrap();
    code
}

fn decode_claims(context: &ServerCtx, token: &str) -> Value {
    let mut validation = jsonwebtoken::Validation::new(jsonwebtoken::Algorithm::ES256);
    validation.set_audience(&[CLIENT_IDENTIFIER]);
    validation.set_issuer(&[ISSUER]);
    let decoded = jsonwebtoken::decode::<Value>(
        token,
        &context.jwk_pairs.auth_tokens.decoding_key,
        &validation,
    )
    .unwrap();
    assert_eq!(
        decoded.header.kid.as_deref(),
        Some(crate::consts::AUTH_TOKEN_KID)
    );
    decoded.claims
}

#[tokio::test]
async fn authorization_grant_preserves_claims_and_cannot_be_replayed() {
    let context = test_context();
    let code = issued_code(&context);
    let grant = handle_authorization_code_grant(
        &context,
        code.clone(),
        REDIRECT_URI.parse().unwrap(),
        VERIFIER.to_string(),
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER,
    )
    .await
    .unwrap();
    let access = decode_claims(&context, &grant.access_token);
    let identity = decode_claims(&context, &grant.id_token);
    let refresh = decode_claims(&context, &grant.refresh_token);
    assert_eq!(access["token_use"], "access");
    assert_eq!(identity["token_use"], "id");
    assert_eq!(refresh["token_use"], "refresh");
    for claims in [&access, &identity, &refresh] {
        assert_eq!(claims["sub"], "verified-provider-subject");
        assert_eq!(claims["aud"], CLIENT_IDENTIFIER);
        assert_eq!(claims["iss"], ISSUER);
        assert_eq!(claims["nonce"], "client-nonce");
        assert_eq!(claims["ext_is_anonymous"], false);
    }
    assert_eq!(identity["email"], "person@example.com");
    assert_eq!(refresh["ext_email"], "person@example.com");
    let mut identity_keys = identity
        .as_object()
        .unwrap()
        .keys()
        .map(String::as_str)
        .collect::<Vec<_>>();
    identity_keys.sort_unstable();
    assert_eq!(
        identity_keys,
        [
            "aud",
            "email",
            "exp",
            "ext_is_anonymous",
            "iat",
            "iss",
            "nonce",
            "sub",
            "token_use"
        ]
    );
    assert_eq!(
        access["exp"].as_u64().unwrap() - access["iat"].as_u64().unwrap(),
        crate::consts::ACCESS_TOKEN_MAX_AGE.as_secs()
    );
    assert_eq!(
        refresh["exp"].as_u64().unwrap() - refresh["iat"].as_u64().unwrap(),
        crate::consts::REFRESH_TOKEN_MAX_AGE.as_secs()
    );
    let replay = handle_authorization_code_grant(
        &context,
        code,
        REDIRECT_URI.parse().unwrap(),
        VERIFIER.to_string(),
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER,
    )
    .await
    .unwrap_err();
    assert!(matches!(replay.error, TokenGrantErrorKind::InvalidGrant));
}

#[tokio::test]
async fn invalid_bindings_do_not_consume_a_valid_code_and_lost_codes_fail_closed() {
    let context = test_context();
    let code = issued_code(&context);
    for (redirect, verifier, client, issuer) in [
        (
            REDIRECT_URI,
            "incorrect-verifier",
            CLIENT_IDENTIFIER,
            ISSUER,
        ),
        (
            "com.yral.iosApp.staging://oauth/callback",
            VERIFIER,
            CLIENT_IDENTIFIER,
            ISSUER,
        ),
        (
            REDIRECT_URI,
            VERIFIER,
            CLIENT_IDENTIFIER,
            "https://other-issuer.example",
        ),
        (
            "yral://oauth/callback",
            VERIFIER,
            "c89b29de-8366-4e62-9b9e-c29585740acf",
            ISSUER,
        ),
    ] {
        assert!(handle_authorization_code_grant(
            &context,
            code.clone(),
            redirect.parse().unwrap(),
            verifier.to_string(),
            client.to_string(),
            None,
            issuer
        )
        .await
        .is_err());
    }
    assert!(handle_authorization_code_grant(
        &test_context(),
        code.clone(),
        REDIRECT_URI.parse().unwrap(),
        VERIFIER.to_string(),
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER
    )
    .await
    .is_err());
    assert!(handle_authorization_code_grant(
        &context,
        code,
        REDIRECT_URI.parse().unwrap(),
        VERIFIER.to_string(),
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER
    )
    .await
    .is_ok());
}

#[tokio::test]
async fn authorization_codes_reject_wrong_purpose_expiry_and_missing_unique_identifier() {
    let context = test_context();
    let code = issued_code(&context);
    let original = decode_claims(&context, &code);
    for field in ["token_use", "exp", "jti"] {
        let mut claims = original.clone();
        match field {
            "token_use" => claims["token_use"] = Value::from("refresh"),
            "exp" => claims["exp"] = Value::from(1),
            _ => {
                claims.as_object_mut().unwrap().remove("jti");
            }
        }
        let invalid = jsonwebtoken::encode(
            &jsonwebtoken::Header::new(jsonwebtoken::Algorithm::ES256),
            &claims,
            &context.jwk_pairs.auth_tokens.encoding_key,
        )
        .unwrap();
        let now = current_epoch_secs();
        context
            .pending_authorization_codes
            .issue(&invalid, now + 600, now)
            .unwrap();
        assert!(handle_authorization_code_grant(
            &context,
            invalid,
            REDIRECT_URI.parse().unwrap(),
            VERIFIER.to_string(),
            CLIENT_IDENTIFIER.to_string(),
            None,
            ISSUER,
        )
        .await
        .is_err());
    }
}

#[tokio::test]
async fn concurrent_token_grants_and_distinct_logins_do_not_share_codes() {
    let context = test_context();
    let code = issued_code(&context);
    let other_code = issued_code(&context);
    assert_ne!(code, other_code);
    let first = handle_authorization_code_grant(
        &context,
        code.clone(),
        REDIRECT_URI.parse().unwrap(),
        VERIFIER.to_string(),
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER,
    );
    let second = handle_authorization_code_grant(
        &context,
        code,
        REDIRECT_URI.parse().unwrap(),
        VERIFIER.to_string(),
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER,
    );
    let (first, second) = tokio::join!(first, second);
    assert_eq!(usize::from(first.is_ok()) + usize::from(second.is_ok()), 1);
    assert!(handle_authorization_code_grant(
        &context,
        other_code,
        REDIRECT_URI.parse().unwrap(),
        VERIFIER.to_string(),
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER
    )
    .await
    .is_ok());
}

#[tokio::test]
async fn refresh_is_stateless_but_rejects_access_identity_legacy_and_invalid_tokens() {
    let context = test_context();
    let code = issued_code(&context);
    let grant = handle_authorization_code_grant(
        &context,
        code,
        REDIRECT_URI.parse().unwrap(),
        VERIFIER.to_string(),
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER,
    )
    .await
    .unwrap();
    let refreshed = handle_refresh_token_grant(
        &test_context(),
        grant.refresh_token.clone(),
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER,
    )
    .await
    .unwrap();
    let refreshed_identity = decode_claims(&context, &refreshed.id_token);
    assert_eq!(refreshed_identity["sub"], "verified-provider-subject");
    assert_eq!(refreshed_identity["email"], "person@example.com");
    assert!(refreshed_identity.get("nonce").is_none());
    for token in [&grant.access_token, &grant.id_token] {
        assert!(handle_refresh_token_grant(
            &context,
            token.clone(),
            CLIENT_IDENTIFIER.to_string(),
            None,
            ISSUER
        )
        .await
        .is_err());
    }
    let original = decode_claims(&context, &grant.refresh_token);
    for modified in [
        {
            let mut claims = original.clone();
            claims.as_object_mut().unwrap().remove("token_use");
            claims
        },
        {
            let mut claims = original.clone();
            claims["exp"] = Value::from(1);
            claims
        },
        {
            let mut claims = original.clone();
            claims["aud"] = Value::from("other-client");
            claims
        },
        {
            let mut claims = original.clone();
            claims["iss"] = Value::from("https://other-issuer.example");
            claims
        },
    ] {
        let invalid = jsonwebtoken::encode(
            &jsonwebtoken::Header::new(jsonwebtoken::Algorithm::ES256),
            &modified,
            &context.jwk_pairs.auth_tokens.encoding_key,
        )
        .unwrap();
        assert!(handle_refresh_token_grant(
            &context,
            invalid,
            CLIENT_IDENTIFIER.to_string(),
            None,
            ISSUER
        )
        .await
        .is_err());
    }
    let other_secret = p256::SecretKey::from_slice(&[8; 32])
        .unwrap()
        .to_pkcs8_pem(LineEnding::LF)
        .unwrap();
    let wrong_key = jsonwebtoken::EncodingKey::from_ec_pem(other_secret.as_bytes()).unwrap();
    let invalid = jsonwebtoken::encode(
        &jsonwebtoken::Header::new(jsonwebtoken::Algorithm::ES256),
        &original,
        &wrong_key,
    )
    .unwrap();
    assert!(handle_refresh_token_grant(
        &context,
        invalid,
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER
    )
    .await
    .is_err());
}

#[tokio::test]
async fn anonymous_and_authenticated_backend_grants_need_no_registration() {
    let context = test_context();
    let anonymous =
        handle_client_credentials_grant(&context, CLIENT_IDENTIFIER.to_string(), None, ISSUER)
            .await
            .unwrap();
    let claims = decode_claims(&context, &anonymous.id_token);
    assert_eq!(claims["ext_is_anonymous"], true);
    assert!(uuid::Uuid::parse_str(claims["sub"].as_str().unwrap()).is_ok());
    let refreshed = handle_refresh_token_grant(
        &context,
        anonymous.refresh_token,
        CLIENT_IDENTIFIER.to_string(),
        None,
        ISSUER,
    )
    .await
    .unwrap();
    assert_eq!(
        decode_claims(&context, &refreshed.id_token)["sub"],
        claims["sub"]
    );

    let client_identifier = "02c8a862-5696-4f36-b0e7-c39edd4f34ea";
    assert!(
        handle_client_credentials_grant(&context, client_identifier.to_string(), None, ISSUER)
            .await
            .is_err()
    );
    let now = current_epoch_secs();
    let secret = jsonwebtoken::encode(&jsonwebtoken::Header::new(jsonwebtoken::Algorithm::EdDSA), &serde_json::json!({"aud": client_identifier, "exp": now + 600, "iat": now, "iss": ISSUER, "sub": client_identifier}), &context.jwk_pairs.client_tokens.encoding_key).unwrap();
    let mut subjects = Vec::new();
    for _ in 0..2 {
        let grant = handle_client_credentials_grant(
            &test_context(),
            client_identifier.to_string(),
            Some(secret.clone()),
            ISSUER,
        )
        .await
        .unwrap();
        let mut validation = jsonwebtoken::Validation::new(jsonwebtoken::Algorithm::ES256);
        validation.set_audience(&[client_identifier]);
        validation.set_issuer(&[ISSUER]);
        let claims = jsonwebtoken::decode::<Value>(
            &grant.id_token,
            &context.jwk_pairs.auth_tokens.decoding_key,
            &validation,
        )
        .unwrap()
        .claims;
        assert_eq!(claims["ext_is_anonymous"], false);
        subjects.push(claims["sub"].clone());
    }
    assert_eq!(subjects[0], format!("backend:{client_identifier}"));
    assert_eq!(subjects[0], subjects[1]);
}
