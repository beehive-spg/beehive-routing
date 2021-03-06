defmodule Routing.Consumer do
  use GenServer
  use AMQP
  require Logger

  alias Routing.{Routehandler, Errorcomm}

  def child_spec([[url, exchange, queue], function]), do: child_spec([[url, exchange, queue, :direct], function])
  def child_spec([[url, exchange, queue, type], function] = opts)
  when is_bitstring(url) and is_bitstring(exchange) and is_bitstring(queue) and is_atom(type) and is_function(function) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, opts},
      type: :worker,
      shutdown: 2_500,
      restart: :transient
    }
  end

  def start_link(opts, spec), do: GenServer.start_link(__MODULE__, [opts, spec], [])

  def init([[url, exchange, queue, type] = opts, function]), do: connect(opts, function)

  def connect([url, exchange, queue, type] = opts, function) do
    case Connection.open(url) do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan, queue, exchange, type)
        Basic.qos(chan, prefetch_count: 100)
        {:ok, _consumer_tag} = Basic.consume(chan, queue)
        {:ok, {chan, function, opts}}

      {status, message} ->
        Logger.warn("Unknwon connection state: #{status}, #{message} for url #{url}")
        :timer.sleep(1000)
        connect(opts, function)
    end
  end

  def setup_queue(chan, queue, exchange, type) do
    Queue.declare(chan, queue, durable: true)
    case type do
      :direct ->
        Exchange.direct(chan, exchange, durable: true) # Declaring the exchange
      :fanout ->
        Exchange.fanout(chan, exchange, durable: true) # Declaring the exchange
    end
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
    {:stop, :cancelled_connection, {chan, function, args}}
  end

  # Handling down notification
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

