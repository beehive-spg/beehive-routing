defmodule Routing.Eventcomm do
  use GenServer
  use AMQP
  require Logger

  def start_link, do: GenServer.start(__MODULE__, [], name: :eventcomm)

  def init(_args), do: connect_rabbitmq()

  @exchange "eventex"
  @queue    "hop_event"
  @error    "#{@queue}_error"

  def connect_rabbitmq do
    # TODO see neworders for details about this workaround
    # case Connection.open("#{Application.get_env(:routing, :cloudamqp_url)}") do
    case Connection.open("#{System.get_env("CLOUDAMQP_URL")}") do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan)
        Basic.qos(chan, prefetch_count: 100)
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

  def publish(data) do
    case GenServer.whereis(:eventcomm) do
      nil ->
        {:ok, _} = start_link()
        publish(data)
      _ ->
        GenServer.cast(:eventcomm, {:send, data})
    end
  end

  def handle_cast({:send, message}, state) do
    Basic.publish(state, @exchange, "", message)
    {:noreply, state}
  end
end

