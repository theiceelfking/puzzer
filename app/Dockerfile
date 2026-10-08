# Builds the Flutter web app and serves it with nginx.
FROM ghcr.io/cirruslabs/flutter:3.41.3 AS build

WORKDIR /src
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .
# Address of the game server the web app connects to.
ARG SERVER_URL=wss://puzzer.deadgroup.dev
RUN flutter build web --release --dart-define=SERVER_URL=$SERVER_URL

FROM nginx:1.27-alpine
COPY --from=build /src/build/web /usr/share/nginx/html
EXPOSE 80
