# Goose Hosting

Native OCI packaging may generate a temporary, secret-free build configuration outside the checkout. This is an approved exception to the generated-config restriction; root mise declarations remain authoritative. The generated configuration must not include repository/global environments, bootstrap resources, dotfiles, tasks, or includes.

Verify the official runtime base's provenance before changing its digest. Keep upstream source unmodified; select upstream-supported feature presets rather than maintaining a custom feature combination.