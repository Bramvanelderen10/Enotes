FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

COPY src/Enotes.App/pubspec.yaml src/Enotes.App/pubspec.lock ./
RUN flutter pub get

COPY src/Enotes.App/ ./
RUN flutter build web --release

FROM nginx:alpine
COPY src/Enotes.App/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
