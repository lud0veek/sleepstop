# Google Home APIs SDK (not committed)

Drop the AAR files of the Home APIs Android SDK here (release 1.11 or later):

- play-services-home-<version>.aar
- play-services-home-types-<version>.aar

Download: https://developers.home.google.com/apis/android/release-notes (sign in with a Google Home Developers account).

When at least one .aar is present, Gradle compiles src/homeapis (real Google Home controller) instead of src/homeapis-stub, adds kotlinx-coroutines and the -Xskip-metadata-version-check flag required by the Kotlin 2.4 metadata of the SDK.
