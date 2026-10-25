FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

# pubspec.lock is committed (see .gitignore), so copy it too, and the image resolves the exact same
# dependency versions as your machine and as the CI release builds.
COPY src/Enotes.App/pubspec.yaml src/Enotes.App/pubspec.lock ./
RUN flutter pub get

COPY src/Enotes.App/ ./
RUN flutter build web --release

FROM nginx:alpine
COPY src/Enotes.App/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
