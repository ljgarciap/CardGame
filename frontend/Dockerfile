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

# --pwa-strategy=none genera flutter_service_worker.js vacío (0 bytes) --
# un dispositivo que ya tenía instalado el service worker viejo (de un
# build previo a este fix, con cacheo agresivo offline-first) no lo pierde
# solo con que el archivo nuevo esté vacío: por default, un service worker
# nuevo queda "esperando" hasta que se cierren TODAS las pestañas que usan
# el viejo -- nada obliga a eso, así que ese dispositivo puede seguir
# atascado en la versión vieja para siempre sin que ningún usuario haga
# nada raro. Se reemplaza el archivo vacío por uno mínimo que se activa
# de inmediato (skipWaiting + clients.claim) y no cachea nada -- combinado
# con el listener de controllerchange en index.html, la transición pasa
# sola en el próximo request sin que el usuario tenga que limpiar nada a
# mano. Nota (2026-07-20): este deploy de prueba es HTTP plano sin dominio
# (ver docker-compose.prod.yml) -- los service workers solo corren en
# "secure contexts" (HTTPS o localhost), así que este mecanismo hoy es
# inerte acá y solo entra en juego cuando haya dominio + TLS reales. La
# causa real de "sigo sin poder entrar" resultó ser otra, ver el ARG
# BUILD_ID más abajo.
RUN printf "self.addEventListener('install', () => self.skipWaiting());\nself.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));\n" > /app/build/web/flutter_service_worker.js

# Causa real confirmada 2026-07-20 (incógnito cargaba bien, perfil normal
# no -- no era el service worker, ver nota arriba): antes de que
# nginx.conf le pusiera "no-cache" a main.dart.js (commit b35e740),
# este archivo caía en el bucket genérico de assets y se servía con
# "Cache-Control: public, max-age=604800, immutable" -- cualquier
# celular que lo haya cargado en esa ventana lo tiene cacheado como
# immutable por 7 días: el navegador ni siquiera vuelve a preguntarle
# al servidor en ese tiempo, así que ningún cambio de headers posterior
# (ni el service worker) le llega. No hay forma de invalidar server-side
# una respuesta ya cacheada -- la solución real es que la URL cambie en
# cada deploy, para que un dispositivo con caché envenenado pida una URL
# que nunca vio en vez de depender de que la vieja se invalide.
ARG BUILD_ID=dev
RUN sed -i "s/\"mainJsPath\":\"main.dart.js\"/\"mainJsPath\":\"main.dart.js?v=${BUILD_ID}\"/" /app/build/web/flutter_bootstrap.js

# flutter_bootstrap.js mismo cae en el mismo bucket genérico pre-b35e740 --
# un dispositivo con ESE archivo cacheado como immutable nunca vería el
# sed de arriba, porque ni siquiera volvería a pedirlo. index.html no
# quedó nunca immutable-cacheado (no matchea esa regex), así que
# versionar acá la referencia sí le llega: fuerza a pedir un
# flutter_bootstrap.js que el navegador nunca vio, en vez de depender de
# que el viejo se invalide solo.
RUN sed -i "s/src=\"flutter_bootstrap.js\"/src=\"flutter_bootstrap.js?v=${BUILD_ID}\"/" /app/build/web/index.html

# ---- serve stage ----
FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
