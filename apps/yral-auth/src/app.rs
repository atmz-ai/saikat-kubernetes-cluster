use leptos::{
    html,
    hydration::{AutoReloadProps, HydrationScriptsProps},
    prelude::*,
};
use leptos_meta::{
    provide_meta_context, HashedStylesheet, HashedStylesheetProps, MetaTags, Title, TitleProps,
};
use leptos_router::{
    components::{
        Redirect, RedirectProps, Route, RouteChildren, RouteProps, Router, RouterProps, Routes,
        RoutesProps,
    },
    path,
};

use crate::{
    context::provide_client_id_validator,
    page::{
        account::{oauth_callback::OauthCallbackPage, page::AccountPage},
        auth::auth_page,
        error_page::ErrorPage,
        oauth_login::{oauth_callback::OAuthCallbackPage, oauth_redirector::oauth_redirector_page},
    },
};

pub fn shell(options: LeptosOptions) -> impl IntoView {
    (
        leptos::tachys::html::doctype("html"),
        html::html()
            .attr("lang", "en")
            .child(
                html::head()
                    .child(html::meta().attr("charset", "utf-8"))
                    .child(
                        html::meta()
                            .attr("name", "viewport")
                            .attr("content", "width=device-width, initial-scale=1"),
                    )
                    .child(AutoReload(
                        AutoReloadProps::builder().options(options.clone()).build(),
                    ))
                    .child(HydrationScripts(
                        HydrationScriptsProps::builder()
                            .options(options.clone())
                            .build(),
                    ))
                    .child(HashedStylesheet(
                        HashedStylesheetProps::builder()
                            .options(options)
                            .id("leptos")
                            .build(),
                    ))
                    .child(MetaTags()),
            )
            .child(html::body().child(app())),
    )
}

pub fn app() -> impl IntoView {
    provide_meta_context();
    provide_client_id_validator();

    (
        Title(TitleProps::builder().text("Yral Authentication").build()),
        Router(
            RouterProps::builder()
                .children(ToChildren::to_children(|| {
                    html::main().child(Routes(
                        RoutesProps::builder()
                            .fallback(|| "Page not found.".into_view())
                            .children(RouteChildren::to_children(|| {
                                (
                                    Route(
                                        RouteProps::builder()
                                            .path(path!("/"))
                                            .view(|| {
                                                Redirect(
                                                    RedirectProps::builder()
                                                        .path("/account")
                                                        .build(),
                                                )
                                            })
                                            .build(),
                                    ),
                                    Route(
                                        RouteProps::builder()
                                            .path(path!("/account"))
                                            .view(AccountPage)
                                            .build(),
                                    ),
                                    Route(
                                        RouteProps::builder()
                                            .path(path!("/account/callback"))
                                            .view(OauthCallbackPage)
                                            .build(),
                                    ),
                                    Route(
                                        RouteProps::builder()
                                            .path(path!("/oauth/auth"))
                                            .view(auth_page)
                                            .build(),
                                    ),
                                    Route(
                                        RouteProps::builder()
                                            .path(path!("/oauth_redirector"))
                                            .view(oauth_redirector_page)
                                            .build(),
                                    ),
                                    Route(
                                        RouteProps::builder()
                                            .path(path!("/oauth_callback"))
                                            .view(OAuthCallbackPage)
                                            .build(),
                                    ),
                                    Route(
                                        RouteProps::builder()
                                            .path(path!("/error"))
                                            .view(ErrorPage)
                                            .build(),
                                    ),
                                )
                            }))
                            .build(),
                    ))
                }))
                .build(),
        ),
    )
}

#[cfg(all(test, feature = "ssr"))]
mod tests {
    #[test]
    fn retained_account_route_is_registered_without_phone_routes() {
        let routes = leptos_axum::generate_route_list(super::app);
        let paths = routes.iter().map(|route| route.path()).collect::<Vec<_>>();
        assert!(paths.contains(&"/account"), "Registered routes: {paths:?}");
        assert!(!paths.iter().any(|path| path.starts_with("/phone/")));
    }
}
