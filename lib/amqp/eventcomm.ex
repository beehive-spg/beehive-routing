defmodule Routing.Eventcomm do
  use GenServer
  use AMQP
  require Logger

  def start_link(_args), do: start_link()
  def start_link, do: GenServer.start(__MODULE__, [], name: :eventcomm)

  def init(_args), do: connect_rabbitmq()

  @url          Application.get_env(:routing, :amqp_url)
  @exchange     "eventex"
  @front_queue  "hop_event"
  @dist_queue   "dist_event"

  def connect_rabbitmq do
    case Connection.open(@url) do
      {:ok, conn} ->
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan)
        Basic.qos(chan, prefetch_count: 100)
        Logger.info("Eventcomm registered for exchange #{@exchange} and queue #{@front_queue} and #{@dist_queue}")
        {:ok, chan}

      {status, message} ->
        Logger.warn("Unknwon connection state: #{status}, #{message} for url #{@url}")
        :timer.sleep(1000)
        connect_rabbitmq()
    end
  end

  def setup_queue(chan) do
    Queue.declare(chan, @front_queue, durable: true)
    Queue.declare(chan, @dist_queue, durable: true)
    Exchange.fanout(chan, @exchange, durable: true)
    Queue.bind(chan, @front_queue, @exchange)
    Queue.bind(chan, @dist_queue, @exchange)
  end

  # Handle down notification - try to reconnect
  def handle_info({:DOWN, _, :process, _pid, _reason}, _) do
    Logger.info("Connection canceled unexpectedly for Eventcomm")
    {:ok, chan} = connect_rabbitmq()
    {:noreply, chan}
  end

  def publish(data) do
    case GenServer.whereis(:eventcomm) do
      nil ->
        start_link()
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

