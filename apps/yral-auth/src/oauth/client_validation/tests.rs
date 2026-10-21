use super::{ClientIdValidator, ConstClientIdValidator, OAuthClient, OAuthClientType};
use std::collections::HashMap;

#[test]
pub fn test_whitelist_macro() {
    let mut cl = HashMap::new();

    let client1 = OAuthClient {
        client_id: "test-client-1".to_string(),
        redirect_urls: vec!["https://example.com/callback".parse().unwrap()],
        client_type: OAuthClientType::Web,
    };
    let client2 = OAuthClient {
        client_id: "test-client-2".to_string(),
        redirect_urls: vec![
            "https://example.com/callback2".parse().unwrap(),
            "https://example.com/callback3".parse().unwrap(),
            "https://example.com/callback4".parse().unwrap(),
        ],
        client_type: OAuthClientType::Native,
    };
    let client3 = OAuthClient {
        client_id: "test-client-3".to_string(),
        redirect_urls: vec!["https://example.com/callback3".parse().unwrap()],
        client_type: OAuthClientType::Web,
    };
    let client4 = OAuthClient {
        client_id: "test-client-4".to_string(),
        redirect_urls: vec![],
        client_type: OAuthClientType::Preview,
    };

    whitelist!(
        cl,
        {
            "test-client-1",
            ["https://example.com/callback"],
            OAuthClientType::Web
        },
        {
            "test-client-2",
            ["https://example.com/callback2", "https://example.com/callback3", "https://example.com/callback4"],
            OAuthClientType::Native
        },
        {
            "test-client-3",
            ["https://example.com/callback3"],
            OAuthClientType::Web
        },
        {
            "test-client-4",
            [],
            OAuthClientType::Preview
        },
    );
    assert!(cl.get(client1.client_id.as_str()) == Some(&client1));
    assert!(cl.get(client2.client_id.as_str()) == Some(&client2));
    assert!(cl.get(client3.client_id.as_str()) == Some(&client3));
    assert!(cl.get(client4.client_id.as_str()) == Some(&client4));
}

const BROWSER_CLIENT_ID: &str = "8ae4e310-e4c5-4a8e-b0cc-09dc0be396bb";

#[tokio::test]
async fn browser_client_accepts_only_its_exact_redirect_uris() {
    let validator = ConstClientIdValidator::default();
    for allowed in ["https://oleole.ai/app/", "https://oleole.ai/u/"] {
        let uri = allowed.parse().unwrap();
        assert!(
            validator
                .validate_id_and_redirect(BROWSER_CLIENT_ID, &uri)
                .await
                .is_ok(),
            "{allowed} should be accepted"
        );
    }
    for rejected in [
        "https://oleole.ai/app",
        "http://oleole.ai/app/",
        "https://oleole.ai/app/other",
        "https://www.oleole.ai/app/",
        "https://oleole.ai.example.com/app/",
    ] {
        let uri = rejected.parse().unwrap();
        assert!(
            validator
                .validate_id_and_redirect(BROWSER_CLIENT_ID, &uri)
                .await
                .is_err(),
            "{rejected} should be rejected"
        );
    }
}

#[cfg(feature = "ssr")]
#[tokio::test]
async fn browser_client_needs_no_secret_at_the_token_endpoint() {
    let validator = ConstClientIdValidator::default();
    let unused_key = jsonwebtoken::DecodingKey::from_secret(b"unused");
    let redirect_uri = "https://oleole.ai/app/".parse().unwrap();
    let kind = validator
        .full_validation(&unused_key, BROWSER_CLIENT_ID, Some(&redirect_uri), None)
        .await
        .map(|res| res.kind);
    assert_eq!(kind.ok(), Some(OAuthClientType::Native));
}
