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

docker compose build              # once (~25 min: Flutter + Android SDK)
docker compose run --rm test      # analyze + full unit suite
docker compose run --rm build-web # -> build/web/
docker compose run --rm build-apk # -> build/app/outputs/flutter-apk/
docker compose run --rm shell     # interactive bash
```

From the project root, pass the file explicitly instead:

```bash
docker compose -f docker/docker-compose.yml run --rm test
```

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

## Cached volumes

`pub-cache`, `gradle-cache`, `android-sdk`, `build-output`, `dart-tool`.
These survive container rebuilds; delete them with
`docker compose down -v` if you need a genuinely cold build.

## Updating Flutter

Bump the `FROM` tag in `Dockerfile.dev` and the `image:` tag in
`docker-compose.yml` together, then `docker compose build`. Never use `latest` —
the pin is the whole point.
