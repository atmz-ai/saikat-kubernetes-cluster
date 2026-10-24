use std::collections::HashMap;

use super::{OAuthClient, OAuthClientType};

pub fn default_oauth_clients() -> HashMap<String, OAuthClient> {
    let client_definitions: &[(&str, &[&str], OAuthClientType)] = &[
        (
            "31122c67-4801-4e70-82f0-08e12daa4f2d",
            &["https://localhost:3000"],
            OAuthClientType::Web,
        ),
        (
            "e1a6a7fb-8a1d-42dc-87b4-13ff94ecbe34",
            &[
                "com.yral.iosApp://oauth/callback",
                "com.yral.iosApp.staging://oauth/callback",
            ],
            OAuthClientType::Native,
        ),
        (
            "6a0101eb-8496-4afb-ba48-425187c3a30d",
            &["http://localhost:5190/api/oauth/callback"],
            OAuthClientType::Web,
        ),
        (
            "c89b29de-8366-4e62-9b9e-c29585740acf",
            &["yral://oauth/callback"],
            OAuthClientType::Native,
        ),
        (
            "02c8a862-5696-4f36-b0e7-c39edd4f34ea",
            &[],
            OAuthClientType::BackendService,
        ),
        (
            "ada497c8-f8e1-4ab8-b3b1-f2b873357f5f",
            &[
                "http://localhost:3002/auth/callback",
                "https://nofeebooking.com/auth/callback",
            ],
            OAuthClientType::Web,
        ),
        (
            "7a2f3b8c-1d4e-4f5a-9b6c-7d8e9f0a1b2c",
            &[
                "https://auth.yral.com/account/callback",
                "http://localhost:3000/account/callback",
            ],
            OAuthClientType::Web,
        ),
    ];

    client_definitions
        .iter()
        .map(|(client_identifier, redirect_urls, client_type)| {
            let client = OAuthClient {
                client_id: (*client_identifier).to_string(),
                redirect_urls: redirect_urls
                    .iter()
                    .map(|redirect_url| redirect_url.parse().unwrap())
                    .collect(),
                client_type: *client_type,
            };
            (client.client_id.clone(), client)
        })
        .collect()
}
