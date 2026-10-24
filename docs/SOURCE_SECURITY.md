# Source security

Atelier runs offline and does not use Mapbox or require API tokens, account
credentials, environment variables or a backend. Runtime fonts and sounds are
bundled locally. The Android release has no INTERNET permission.

Sound-source pages are represented by minimal JSON license receipts containing
the author, source/license URLs and a source-page SHA-256. Full third-party HTML
is excluded: unrelated website scripts and credentials are not app assets.
Original audio, font licenses, attribution and the asset hash manifest remain
included. Source packaging is checked for embedded Mapbox tokens, including
compressed ZIP/APK members, without printing token values. This focused check
does not replace a comprehensive secret scanner.

Before publishing any copy, inspect the files being added and keep generated
build output, private configuration and credentials outside version control.
If a real secret is ever exposed, revoke or rotate it with its provider;
removing a file or replacing Git history alone cannot invalidate credentials.

References: [Mapbox token types](https://docs.mapbox.com/help/dive-deeper/access-tokens/)
and [GitHub sensitive-data removal](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository).
