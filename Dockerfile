################
### Building ###
################

FROM bitwalker/alpine-elixir:1.5 as build

# Setup the environment variables
COPY .env .
RUN source .env

# Import project
COPY config ./config
COPY lib ./lib
COPY mix.exs .
COPY mix.lock .

# Build project and create executable
RUN export MIX_ENV=prod && \
    mix deps.get && \
    mix local.hex --force && \
    mix local.rebar --force && \
    mix release.init && \
    mix release

# Export executable
RUN APP_NAME="routing" && \
    RELEASE_DIR=`ls -d _build/prod/rel/$APP_NAME/releases/0.1.0/` && \
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
