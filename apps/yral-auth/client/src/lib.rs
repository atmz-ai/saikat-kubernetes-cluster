#[cfg(feature = "release-lib")]
#[wasm_bindgen::prelude::wasm_bindgen]
pub fn hydrate() {
    yral_auth::hydrate();
}
