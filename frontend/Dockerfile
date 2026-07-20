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
# --pwa-strategy=none: el build por default registra un service worker que
# cachea el app shell en el Cache Storage del navegador -- una capa de
# caché totalmente aparte de los headers HTTP (nginx.conf ya sirve
# main.dart.js con no-cache, pero el service worker igual puede servir la
# versión vieja sin tocar la red). Encontrado en vivo: un fix ya desplegado
# no le llegaba al celular pese al no-cache de nginx. Este juego no
# necesita soporte offline -- prioridad es que cada carga sea siempre la
# versión real del servidor, no cachear para uso sin conexión.
RUN flutter build web --release --pwa-strategy=none --dart-define=API_BASE_URL=${API_BASE_URL}

# ---- serve stage ----
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
