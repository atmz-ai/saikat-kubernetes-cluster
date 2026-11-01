use crate::{components::spinner::Spinner, oauth::SupportedOAuthProviders};
use leptos::{html, prelude::*};
use leptos_router::{
    components::{Redirect, RedirectProps},
    hooks::use_query,
    params::Params,
};

#[server]
pub async fn get_oauth_url(
    provider: SupportedOAuthProviders,
    client_state: String,
) -> Result<String, ServerFnError> {
    use crate::api::oauth_server_impl::get_oauth_url_impl;
    get_oauth_url_impl(provider, client_state).await
}

#[derive(Debug, Clone, Params, PartialEq)]
pub struct OAuthRedirectorQueryMaybe {
    provider: Option<SupportedOAuthProviders>,
    state: Option<String>,
}

pub fn oauth_redirector_page() -> impl IntoView {
    let query = use_query::<OAuthRedirectorQueryMaybe>();
    let oauth_url = Resource::new_blocking(
        move || query.get(),
        async move |query| {
            let query = query?;
            let Some(provider) = query.provider else {
                return Err(ServerFnError::new("invalid provider"));
            };
            let Some(state) = query.state else {
                return Err(ServerFnError::new("invalid state"));
            };

            get_oauth_url(provider, state).await
        },
    );

    Suspense(
        SuspenseProps::builder()
            .fallback(|| {
                html::div()
                    .class("w-dvw h-dvh bg-black flex justify-center items-center")
                    .child(Spinner())
            })
            .children(ToChildren::to_children(move || {
                Suspend::new(async move {
                    let redirect_path = match oauth_url.await {
                        Ok(url) => url,
                        Err(error) => format!("/error?error={error}"),
                    };
                    Redirect(RedirectProps::builder().path(redirect_path).build())
                })
            }))
            .build(),
    )
}
