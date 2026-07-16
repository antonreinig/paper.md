# Releasing paper.md

Public binaries must be signed with a Developer ID Application certificate, use the hardened runtime, and be notarized by Apple. Development builds and CI builds intentionally do not contain distribution credentials.

## Prerequisites

- active Apple Developer Program membership
- Developer ID Application certificate in the login keychain
- App Store Connect API key or a notarization keychain profile
- clean `main` branch with passing CI

## Release checklist

1. Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
2. Run `./scripts/test.sh`.
3. Generate the project with `./scripts/bootstrap.sh`.
4. Archive the `PaperMD` scheme with the Developer ID identity.
5. Export the app for Developer ID distribution.
6. Put the app in a DMG, sign the DMG, and submit it with `xcrun notarytool`.
7. Staple and validate the ticket with `xcrun stapler`.
8. Verify with `spctl --assess --type execute --verbose` on a clean Mac account.
9. Create a signed Git tag and attach the notarized DMG to a GitHub Release.

Never store certificates, `.p8` files, passwords, or notary credentials in the repository.

## GitHub environment

The manual `Release` workflow performs the archive, Developer ID signing, DMG creation, notarization, stapling, validation, and GitHub Release publication. Create a protected GitHub environment named `release` and add these secrets:

- `APPLE_CERTIFICATE_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `KEYCHAIN_PASSWORD`
- `APPLE_API_KEY_BASE64`
- `APPLE_API_KEY_ID`
- `APPLE_API_ISSUER_ID`
- `APPLE_TEAM_ID`
