# Build image
FROM swift:5.2.4-bionic as build


RUN apt-get update -y \
	&& apt-get install -y libsqlite3-dev

WORKDIR /build

COPY . .


RUN swift build \
	--enable-test-discovery \
	-c release \
	-Xswiftc -g


# Run image
FROM swift:5.2.4-bionic-slim

RUN useradd --user-group --create-home --home-dir /app vapor

WORKDIR /app

COPY --from=build --chown=vapor:vapor /build/.build/release /app
COPY --from=build --chown=vapor:vapor /build/Support /app/Support

COPY .env /app
COPY .env /app/.env.production

USER vapor
ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "8080"]
