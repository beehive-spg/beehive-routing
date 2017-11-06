defmodule Routing.Neworder do
  use GenServer
  use AMQP
  require Logger

  def start_link(opts) do
    GenServer.start(__MODULE__, [], [])
  end

  @exchange "amq.direct"
  @queue    "new_orders"
  @error    "#{@queue}_error"

  def init(args) do
    Logger.info Application.get_env :routing, :cloudamqp_url
    {:ok, conn} = Connection.open "#{Application.get_env(:routing, :cloudamqp_url)}"
    {:ok, chan} = Channel.open conn
    setup_queue chan

    Basic.qos chan, prefetch_count: 100
    {:ok, _consumer_tag} = Basic.consume chan, @queue
    {:ok, chan}
  end

  def setup_queue(chan) do
    Queue.declare chan, @error, durable: true
    Queue.declare chan, @queue, durable: true
    Exchange.direct chan, @exchange, durable: true # Declaring the exchange
    Queue.bind chan, @queue, @exchange # Binding the two above
  end

  # Handling confirmation of registering the consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: consumer_tag}}, chan) do
    Logger.info "Consumer #{consumer_tag} registered for exchange #{@exchange} and queue #{@queue}"
    {:noreply, chan}
  end

  # Handling unexpected cancelling
  def handle_info({:basic_cancel, %{consumer_tag: consumer_tag}}, chan) do
    Logger.info "Connection canceled unexpectedly for consumer #{consumer_tag}"
    {:stop, :normal, chan}
  end

  # Handling received message
  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: redelivered}}, chan) do
    Logger.info "Handling incoming message"
    spawn fn -> process_message chan, tag, redelivered, payload end
    {:noreply, chan}
  end

  def process_message(chan, tag, redelivered, payload) do
    Basic.ack chan, tag
    IO.puts "Received: Tag: #{tag}, Redelivered: #{redelivered}, Payload: #{payload}"
  end

end
