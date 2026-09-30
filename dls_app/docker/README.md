# Containerised Build Toolchain

Everything needed to build and test the DLS app reproducibly.

| File | Purpose |
|---|---|
| `Dockerfile.dev` | Builds on `ghcr.io/cirruslabs/flutter:3.41.6` (Ubuntu 24.04, JDK 21, Android SDK 36) |
| `docker-compose.yml` | `test`, `build-web`, `build-apk`, `shell` services over one image |
| `../.dockerignore` | Build-context exclusions — **must stay at the project root** |

## Why a prebuilt Flutter base image

The base tag pins Flutter to the exact revision the release candidate was
audited on — **3.41.6, revision `db50e20168`**, identical to the developer
machine. Installing the SDK inside the Dockerfile means downloading a ~1444 MB
archive on every cold build; on the network this was written against that took
**3h38m** and failed mid-transfer (`curl` error 56). The published image ships
the SDK, the Android SDK and a warmed pub cache, so the build is fast and cannot
drift from the audited SDK.

## Why `.dockerignore` is not in this folder

BuildKit only reads `.dockerignore` from the **build context root**, and the
context here is the Flutter project root (`..`). A `.dockerignore` inside this
folder would be silently ignored, so the build context would balloon with
`build/` output and Gradle caches.

## Usage

```bash
cd docker

docker compose build              # once: Flutter + Android SDK + NDK (slow link, see below)
docker compose run --rm test      # analyze + full unit suite
docker compose run --rm build-web # -> build/web/
docker compose run --rm build-apk # -> build/app/outputs/flutter-apk/
docker compose run --rm shell     # interactive bash
docker compose run --rm shell -c 'flutter doctor -v'   # one-off command
```

`shell` uses `bash` as its **entrypoint**, so trailing arguments are appended to
it. `shell -c '<cmd>'` therefore becomes `bash -c '<cmd>'` rather than replacing
the shell binary.

From the project root, pass the file explicitly instead:

```bash
docker compose -f docker/docker-compose.yml run --rm test
```

## Git and source control

Compose mounts the repository root at `/workspace` and opens the Flutter app at
`/workspace/dls_app`, so Git commands in `shell` use the same checkout as VS
Code. Git is included in the image. The container sets `core.autocrlf=true` to
match this Windows checkout and hides the image's default global Git identity;
this prevents false line-ending changes and commits attributed to `Cirrus CI`.

Before committing from the container, configure an identity for this checkout:

```bash
git config --local user.name "Your Name"
git config --local user.email "you@example.com"
```

The local identity is stored in the shared `.git/config`. No Git credentials or
SSH keys are mounted, so use VS Code on the host for authenticated fetch/push.

## Extracting build artifacts

`build/` lives in a **named volume**, not on the host — that is deliberate, so
thousands of generated files do not crawl through the Windows bind mount. Copy
artifacts out when you need them:

```bash
cd docker

# Web bundle -> ../docker-out/web  (deploy this to any static host)
docker run --rm --entrypoint sh \
  -v dls_build-output:/build \
  -v "${PWD}/../docker-out:/out" \
  dls-flutter:3.41.6 \
  -c 'cp -r /build/web /out/web'

# Release APK -> ../docker-out/app-release.apk
docker run --rm --entrypoint sh \
  -v dls_build-output:/build \
  -v "${PWD}/../docker-out:/out" \
  dls-flutter:3.41.6 \
  -c 'cp /build/app/outputs/flutter-apk/app-release.apk /out/'
```

## Verifying a build is actually correct

`✓ Built ...` only proves the command exited zero. These are the checks worth
running before trusting an artifact.

**Both builds — confirm nothing was re-downloaded.** Search the log for
`Downloading` and `Installing`. `flutter pub get` prints "Downloading packages..."
on every run even when everything is cached, so ignore that; a line mentioning
`ndk`, `platforms;` or `build-tools;` means a cache miss.

**Both builds — confirm the artifact is real, not just present.**

```bash
# Web: a release bundle has canvaskit/, a minified main.dart.js and no *.map
docker run --rm --entrypoint sh -v dls_build-output:/build dls-flutter:3.41.6 \
  -c 'du -sh /build/web; head -c 200 /build/web/main.dart.js; ls /build/web'

# APK: should be ~67 MB and a valid zip
docker run --rm --entrypoint sh -v dls_build-output:/build dls-flutter:3.41.6 \
  -c 'cd /build/app/outputs/flutter-apk && ls -lh app-release.apk && unzip -l app-release.apk | head'
```

**Web — serve it before shipping it.** Static bundles fail in ways a build step
never catches (wrong `<base href>`, missing engine files):

```bash
cd docker && docker run --rm --entrypoint sh \
  -v dls_build-output:/build dls-flutter:3.41.6 -c '
    cd /build/web && python3 -m http.server 8099 &
    sleep 3
    for f in index.html main.dart.js flutter_bootstrap.js canvaskit/canvaskit.wasm; do
      printf "%-32s %s\n" "$f" \
        "$(curl -s -o /dev/null -w "HTTP %{http_code} %{size_download}b" http://localhost:8099/$f)"
    done'
```

Every path should answer `HTTP 200` with a non-zero size.

**Reproducibility.** Two consecutive builds should be byte-identical. If they
differ, something in the environment is not pinned:

```bash
docker run --rm --entrypoint sh -v dls_build-output:/build dls-flutter:3.41.6 \
  -c 'sha256sum /build/web/main.dart.js'
```

### Known limits of this setup

- **No browser is installed in the image**, so the bundle is verified as
  *buildable and serveable*, not *rendered*. Nothing here proves the app paints
  in a real browser. The test suite is VM-only as well — there are no
  `@TestOn('browser')` tests. Adding Chromium to the image would allow
  `flutter test --platform chrome` and close this gap.
- The release APK is signed with the **debug** key and keeps
  `applicationId = com.example.dls_app`, so it is not store-submittable.


`pub-cache`, `gradle-cache`, `android-sdk`, `build-output`, `dart-tool`.
These survive container rebuilds; delete them with
`docker compose down -v` if you need a genuinely cold build.

### Mount every cache at the path the image actually uses

A named volume mounted at the *wrong* path is worse than no volume at all: it
looks configured, passes `docker compose config`, and silently discards
everything written to the real location. This already happened once — the
`android-sdk` volume was pointed at `/opt/android-sdk` while the base image sets
`ANDROID_HOME=/opt/android-sdk-linux`, so ~1 GB of NDK, CMake and platform
packages landed in the throwaway container layer and were destroyed by
`run --rm`. Every single APK build re-downloaded the lot.

The table below is verified against the built image, not assumed:

| Volume | Container path | Backed by |
|---|---|---|
| `pub-cache` | `/root/.pub-cache` | `PUB_CACHE` (set in `Dockerfile.dev`) |
| `gradle-cache` | `/root/.gradle` | `GRADLE_USER_HOME` (set in `Dockerfile.dev`) |
| `android-sdk` | `/opt/android-sdk-linux` | `ANDROID_HOME` (set by the **base image**) |
| `build-output` | `/workspace/dls_app/build` | Flutter's build dir |
| `dart-tool` | `/workspace/dls_app/.dart_tool` | Flutter's package config |

`ANDROID_SDK_ROOT` is set to the same path as `ANDROID_HOME`, because some
Gradle/AGP versions read the former and others the latter; they must not drift
apart or one of them will resolve to an empty directory.

Check a volume is actually being used before trusting it:

```bash
docker run --rm -v dls_android-sdk:/v --entrypoint sh dls-flutter:3.41.6 \
  -c 'du -sh /v'
```

A few kilobytes means the mount is in the wrong place. A populated Android SDK
placed 3.9 GB in `android-sdk` and the warm Gradle cache held 5.1 GB; if `du`
reports a handful of kilobytes, something is writing elsewhere.

### Do not run two services at once

`build-output` and `dart-tool` are mounted into `test`, `build-web` and
`build-apk` alike, so two of them running concurrently write the same
`build/` and `.dart_tool/` trees and corrupt each other. Run them one at a
time. The caches (`pub-cache`, `gradle-cache`, `android-sdk`) are safe to share
and are worth sharing.

## Why the Android SDK is baked into the image

`Dockerfile.dev` installs `platform-tools`, platforms 34–36, build-tools 35 and
36, NDK 28.2.13676358 and CMake 3.22.1 at image build time, which lands ~3.9 GB
at `$ANDROID_HOME`. Gradle resolves these on demand otherwise, and on a slow link
that is the slowest part of the process by a wide margin. Baking them in also
means the `android-sdk` volume is seeded with a complete SDK the first time it
is mounted, so a cold volume still costs nothing to fill — even after
`docker volume rm dls_android-sdk`.

The project does **not** pin an SDK or NDK version itself. `android/app/build.gradle.kts`
defers to the Flutter Gradle plugin:

```kotlin
compileSdk = flutter.compileSdkVersion
ndkVersion = flutter.ndkVersion
```

Those values come from the Flutter SDK, so they are deterministic for the pinned
`3.41.6` tag but **can move when the Flutter tag moves**. AGP here is 8.11.1.
That is the real reason the `android-sdk` volume matters and the image alone is
not enough: bumping the `FROM` tag can change `flutter.ndkVersion`, and the new
side-by-side NDK lands in the volume rather than being re-fetched on every build.

The lists above are a deliberate superset — platforms 34 and 35 and build-tools
35 are insurance for plugins that hard-code an older target, not strict
requirements of this project.

### Expect the image build to be slow on a poor link

Baking the NDK in moves roughly 1 GB of downloads from "every APK build" to
"once per image version", and the download happens inside `docker build` where
layer caching protects it. It is not free: measured against
`storage.googleapis.com` at ~0.03 MB/s this step dominated a 70-minute first APK
build. The trade is deliberate — pay it once at image build, never again during
`build-apk` until the `FROM` tag or the NDK version changes.

If you only ever run `test`, none of this matters: the SDK components are never
touched by `flutter analyze` or `flutter test`.

## Updating Flutter

Bump the `FROM` tag in `Dockerfile.dev` and the `image:` tag in
`docker-compose.yml` together, then `docker compose build`. Never use `latest` —
the pin is the whole point.
