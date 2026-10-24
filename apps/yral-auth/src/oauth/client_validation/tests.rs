use super::{ClientIdValidator, ConstClientIdValidator, OAuthClientType};

#[tokio::test]
async fn retained_clients_keep_their_redirects_and_types() {
    let validator = ConstClientIdValidator::default();
    for (client_identifier, redirect_url, client_type) in [
        (
            "31122c67-4801-4e70-82f0-08e12daa4f2d",
            "https://localhost:3000",
            OAuthClientType::Web,
        ),
        (
            "e1a6a7fb-8a1d-42dc-87b4-13ff94ecbe34",
            "com.yral.iosApp://oauth/callback",
            OAuthClientType::Native,
        ),
        (
            "e1a6a7fb-8a1d-42dc-87b4-13ff94ecbe34",
            "com.yral.iosApp.staging://oauth/callback",
            OAuthClientType::Native,
        ),
        (
            "6a0101eb-8496-4afb-ba48-425187c3a30d",
            "http://localhost:5190/api/oauth/callback",
            OAuthClientType::Web,
        ),
        (
            "c89b29de-8366-4e62-9b9e-c29585740acf",
            "yral://oauth/callback",
            OAuthClientType::Native,
        ),
        (
            "ada497c8-f8e1-4ab8-b3b1-f2b873357f5f",
            "http://localhost:3002/auth/callback",
            OAuthClientType::Web,
        ),
        (
            "ada497c8-f8e1-4ab8-b3b1-f2b873357f5f",
            "https://nofeebooking.com/auth/callback",
            OAuthClientType::Web,
        ),
        (
            "7a2f3b8c-1d4e-4f5a-9b6c-7d8e9f0a1b2c",
            "https://auth.yral.com/account/callback",
            OAuthClientType::Web,
        ),
        (
            "7a2f3b8c-1d4e-4f5a-9b6c-7d8e9f0a1b2c",
            "http://localhost:3000/account/callback",
            OAuthClientType::Web,
        ),
    ] {
        let client = validator.lookup_client(client_identifier).await.unwrap();
        assert_eq!(client.client_type, client_type);
        assert!(validator
            .validate_id_and_redirect(client_identifier, &redirect_url.parse().unwrap())
            .await
            .is_ok());
    }
    let backend_client = validator
        .lookup_client("02c8a862-5696-4f36-b0e7-c39edd4f34ea")
        .await
        .unwrap();
    assert_eq!(backend_client.client_type, OAuthClientType::BackendService);
    assert!(backend_client.redirect_urls.is_empty());
}

#[tokio::test]
async fn retired_frontend_clients_are_unauthorized() {
    let validator = ConstClientIdValidator::default();
    for client_identifier in [
        "4ec00561-91bb-4e60-9743-8bed684145ba",
        "5c86a459-493d-463e-965d-be6ed74f3e5f",
        "f3a7872f-55f9-4ca7-8fec-9a5d20356248",
    ] {
        assert!(
            matches!(validator.lookup_client(client_identifier).await, Err(crate::error::AuthErrorKind::UnauthorizedClient(rejected_identifier)) if rejected_identifier == client_identifier)
        );
    }
    for redirect_url in [
        "https://legacy.yral.com/auth/google_redirect",
        "http://127.0.0.1:8080/auth/google_redirect",
    ] {
        assert!(validator
            .validate_id_and_redirect(
                "4ec00561-91bb-4e60-9743-8bed684145ba",
                &redirect_url.parse().unwrap()
            )
            .await
            .is_err());
        for client in validator.clients.values() {
            assert!(validator
                .validate_redirect_uri(client, Some(&redirect_url.parse().unwrap()))
                .is_err());
        }
    }
}
