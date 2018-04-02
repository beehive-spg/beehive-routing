defmodule Routing.Errorcomm do
  use GenServer
  use AMQP
  require Logger

  def start_link(_args), do: start_link()
  def start_link, do: GenServer.start(__MODULE__, [], name: :errorcomm)

  def init(_args), do: connect_rabbitmq()

  @exchange "errorex"
  @queue    "error_result"

  def connect_rabbitmq do
    case Connection.open("#{Application.get_env(:routing, :cloudamqp_url)}") do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan)
        Basic.qos(chan, prefetch_count: 100)
        Logger.info("Errorcomm registered for exchange #{@exchange} and queue #{@queue}")
        {:ok, chan}

      {status, message} ->
        Logger.warn("Unknwon connection state: #{status}, #{message}")
        :timer.sleep(1000)
        connect_rabbitmq()
    end
  end

  def setup_queue(chan) do
    Queue.declare(chan, @queue, durable: true)
    Exchange.direct(chan, @exchange, durable: true)
    Queue.bind(chan, @queue, @exchange)
  end

  # Handle down notification - try to reconnect
  def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
    Logger.info("Connection canceled unexpectedly for Errorcomm")
    {:ok, chan} = connect_rabbitmq()
    {:noreply, chan}
  end

  def publish(data) do
    case GenServer.whereis(:errorcomm) do
      nil ->
        start_link()
        publish(data)
      _ ->
        GenServer.cast(:errorcomm, {:send, data})
    end
  end

  def handle_cast({:send, message}, state) do
    Basic.publish(state, @exchange, "", message)
    {:noreply, state}
  end
end

