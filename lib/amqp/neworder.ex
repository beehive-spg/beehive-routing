defmodule Routing.Neworder do
  use GenServer
  use AMQP
  require Logger

  alias Routing.Routecalc

  def start_link(_opts), do: GenServer.start(__MODULE__, [], [])

  def init(_args), do: connect_rabbitmq()

  @exchange "amq.direct"
  @queue    "new_orders"
  @error    "#{@queue}_error"

  def connect_rabbitmq do
    # TODO workaround because when building an executable elixir cannot find the env variable - idk why
    case Connection.open("#{System.get_env("CLOUDAMQP_URL")}") do
    # case Connection.open("#{Application.fetch_env!(:routing, :cloudamqp_url)}") do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan)
        Basic.qos(chan, prefetch_count: 100)
        {:ok, _consumer_tag} = Basic.consume(chan, @queue)
        {:ok, chan}

      {:eror, _} ->
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

  # Handling received message
  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, chan) do
    Logger.debug("Handling incoming message")
    Basic.ack(chan, tag)
    {:ok, order} = process_message(chan, tag, redelivered, payload)
    if is_map order do
      Logger.info("Order for: ID: #{order["id"]}: #{order["from"]}, #{order["to"]}")
      # TODO call routing engine with order
      Task.start(fn -> Routecalc.calc(order) end)
    end
    {:noreply, chan}
  end

  defp process_message(chan, tag, redelivered, payload) do
    order = Poison.decode!(~s(#{payload}))
    {:ok, order}
  rescue
    Protocol.UndefinedError ->
      Logger.warn("New Orders: Could not process message: #{payload}")
    Poison.SyntaxError ->
      Logger.warn("New Orders: Could not process message: #{payload}")
      # TODO implement replying to message that something went wrong
    {:ok, "Requeued due to error during processing."}
  end
end

