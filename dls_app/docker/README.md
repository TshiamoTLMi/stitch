# Containerised Build Toolchain

Everything needed to build and test the DLS app reproducibly.

| File | Purpose |
|---|---|
| `Dockerfile.dev` | Ubuntu 22.04 + JDK 17 + Android SDK + **Flutter 3.41.6 (pinned)** |
| `docker-compose.yml` | `test`, `build-web`, `build-apk`, `shell` services over one image |
| `../.dockerignore` | Build-context exclusions — **must stay at the project root** |

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

## Cached volumes

`pub-cache`, `gradle-cache`, `android-sdk`, `build-output`, `dart-tool`.
These survive container rebuilds; delete them with
`docker compose down -v` if you need a genuinely cold build.

## Updating Flutter

Bump `FLUTTER_VERSION` in `Dockerfile.dev` and the `image:` tag in
`docker-compose.yml` together, then `docker compose build`. Never use `latest` —
the pin is the whole point.
