################
### Building ###
################

FROM bitwalker/alpine-elixir:1.6.1 as build

# Import project
COPY mix.exs .
COPY mix.lock .

# Install deps
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get

# Build and export executable
COPY config ./config
COPY lib ./lib

RUN export MIX_ENV=prod && \
    mix release.init && \
    mix release

# Export executable
RUN APP_NAME="routing" && \
    RELEASE_DIR=`ls -d _build/prod/rel/$APP_NAME/releases/0.*/` && \
    mkdir /export && \
    tar -xf "$RELEASE_DIR/$APP_NAME.tar.gz" -C /export

##################
### Deployment ###
##################

FROM pentacent/alpine-erlang-base:latest

# Import executable
COPY --from=build /export/ .

# Change user
USER default

# Port needed for amqp
EXPOSE 5671:5671

# Start application in console mode (enables later interaction if needed)
ENTRYPOINT ["/opt/app/bin/routing"]
CMD ["console"]
