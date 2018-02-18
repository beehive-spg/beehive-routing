defmodule Routing.Neworder do
  use GenServer
  use AMQP
  require Logger

  alias Routing.Routehandler

  def start_link(_opts), do: GenServer.start(__MODULE__, [], [])

  def init(_args), do: connect_rabbitmq()

  @exchange "amq.direct"
  @queue    "new_orders"
  @error    "#{@queue}_error"

  def connect_rabbitmq do
    case Connection.open("#{Application.fetch_env!(:routing, :cloudamqp_url)}") do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan)
        Basic.qos(chan, prefetch_count: 100)
        {:ok, _consumer_tag} = Basic.consume(chan, @queue)
        {:ok, chan}

      {status, message} ->
        Logger.warn("Unknown connection state: #{status}, #{message}")
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
    Logger.info("Consumer #{consumer_tag} registered for exchange #{@exchange} and queue #{@queue}")
    {:noreply, chan}
  end

  # Handling unexpected cancelling
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, chan) do
    Logger.info("Connection canceled unexpectedly for consumer #{consumer_tag}")
    {:stop, :normal, chan}
  end

  # Handling down notification - try to reconnect
  def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
    {:ok, chan} = connect_rabbitmq()
    {:noreply, chan}
  end

  # Handling received message
  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: _}}, chan) do
    Logger.debug("Handling incoming message")
    Basic.ack(chan, tag)
    {:ok, pid} = Task.Supervisor.start_link()
    result = Task.Supervisor.async_nolink(pid, Routehandler, :calc_delivery, [payload]) |> Task.yield
    case inspect(result) do
      {:err, message} ->
        Logger.warn(message)
      {:ok, message} ->
        Logger.debug(message)
      message ->
        Logger.warn("Calculating delivery for #{payload} resulted in an error: #{message}")
    end
    {:noreply, chan}
  end
end

