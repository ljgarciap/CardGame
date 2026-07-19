# Misma versión que usa la CI (.github/workflows/ci.yml) y el dev local --
# el canal "stable" es un blanco móvil, ver docs/memory.md 2026-07-17 sobre
# por qué "stable" rompió la build una vez ya (font_awesome_flutter vs.
# IconData final class).
FROM ghcr.io/cirruslabs/flutter:3.32.8 AS build
WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Se hornea en el bundle JS en tiempo de build (String.fromEnvironment no
# es un valor que se pueda cambiar después sin recompilar) -- ver
# lib/core/api_config.dart. Default apunta a localhost a propósito, para
# que un build local sin --build-arg no falle silenciosamente contra un
# backend real.
ARG API_BASE_URL=http://localhost:8001
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

# ---- serve stage ----
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
