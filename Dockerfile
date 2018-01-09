FROM elixir

EXPOSE 5671:5671

WORKDIR /routing
COPY    config ./config
COPY    lib ./lib
COPY    mix.exs .
COPY    mix.lock .

RUN mix local.hex --force
RUN mix deps.get

CMD mix local.rebar --force && iex -S mix
