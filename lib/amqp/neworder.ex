defmodule Routing.Neworder do
  use GenServer
  use AMQP
  require Logger

  alias Routing.Routehandler

  def start_link(_opts), do: GenServer.start(__MODULE__, [], [])

  def init(_args), do: connect_rabbitmq()

  @url      Application.fetch_env!(:routing, :cloudamqp_url)
  @exchange "newx"
  @queue    "new_orders"
  @error    "#{@queue}_error"

  def connect_rabbitmq do
    case Connection.open(@url) do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan)
        Basic.qos(chan, prefetch_count: 100)
        {:ok, _consumer_tag} = Basic.consume(chan, @queue)
        {:ok, chan}

      {_status, _message} ->
        Logger.warn("Cannot connect to RabbitMQ with url #{@url}")
        :timer.sleep(1000)
        connect_rabbitmq()
    end
  end

  def setup_queue(chan) do
    Queue.declare(chan, @error, durable: true)
    Queue.declare(chan, @queue, durable: true)
    Exchange.direct(chan, @exchange, durable: true) # Declaring the exchange
    Queue.bind(chan, @queue, @exchange) # Binding the two above
  end

  # Handling confirmation of registering the consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, chan) do
    Logger.info("Neworder #{consumer_tag} registered for exchange #{@exchange} and queue #{@queue}")
    {:noreply, chan}
  end

  # Handling unexpected cancelling
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, chan) do
    Logger.info("Connection canceled unexpectedly for Neworder #{consumer_tag}")
    {:stop, :normal, chan}
  end

  # Handling down notification - try to reconnect
  def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
    {:ok, chan} = connect_rabbitmq()
    {:noreply, chan}
  end

  # Handling received message
  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: _}}, chan) do
    Logger.debug("Handling incoming message #{payload}")
    consume(payload)
    Basic.ack(chan, tag)
    {:noreply, chan}
  end

  def consume(payload) do
    case Routehandler.calc_delivery(payload) do
      {:err, message} ->
        IO.inspect(message) |> Logger.warn
        # Logger.warn(message)
      {:ok, message} ->
        Logger.info(message)
      message ->
        Logger.warn("Calculating delivery for #{payload} resulted in an unkown error: #{message}")
    end
  end
end

