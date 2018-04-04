defmodule Routing.Consumer do
  use GenServer
  use AMQP
  require Logger

  alias Routing.{Routehandler, Errorcomm}

  def child_spec([{url, exchange, queue}, function] = args)
  when is_bitstring(url) and is_bitstring(exchange) and is_bitstring(queue) and is_function(function) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, args},
      type: :worker,
      shutdown: 2_000,
      restart: :permanent
    }
  end

  def start_link(opts, spec), do: GenServer.start_link(__MODULE__, [opts, spec], [])

  def init([{url, exchange, queue} = opts, function]), do: connect(opts, function)

  def connect({url, exchange, queue} = opts, function) do
    case Connection.open(url) do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan, queue, exchange)
        Basic.qos(chan, prefetch_count: 100)
        {:ok, _consumer_tag} = Basic.consume(chan, queue)
        {:ok, {chan, function, opts}}

      {_status, _message} ->
        Logger.warn("Cannot connect to RabbitMQ with url #{url}")
        :timer.sleep(1000)
        connect(opts, function)
    end
  end

  def setup_queue(chan, queue, exchange) do
    Queue.declare(chan, queue, durable: true)
    Exchange.direct(chan, exchange, durable: true) # Declaring the exchange
    Queue.bind(chan, queue, exchange) # Binding the two above
  end

  # Handling confirmation of registering the consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, {chan, function, args}) do
    Logger.info("Consumer for #{inspect(function)} successfully connected")
    {:noreply, {chan, function, args}}
  end

  # Handling unexpected cancelling
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, {chan, function, args}) do
    Logger.warn("Consumer for #{inspect(function)} cancelled unexpectedly")
    {:stop, :normal, {chan, function, args}} # let it be restarted in the supervisor
  end

  # Handling down notification - try to reconnect
  def handle_info({:DOWN, _, :process, _pid, _reason}, {_, function, args}) do
    {:ok, {chan, function, args}} = connect(args, function)
    {:noreply, {chan, function, args}}
  end

  # Handling received message
  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: _}}, {chan, function, args}) do
    Logger.debug("Handling incoming message #{payload}")
	function.(payload)
    Basic.ack(chan, tag)
    {:noreply, {chan, function, args}}
  end
end

