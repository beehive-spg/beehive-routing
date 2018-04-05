defmodule Routing.RabbitMQ do
  use Supervisor
  require Logger

  alias Routing.{Errorcomm, Eventcomm, Routehandler}

  @url Application.fetch_env!(:routing, :amqp_url)

  def start_link(_opts), do: Supervisor.start_link(__MODULE__, :ok, [])

  def init(_args) do
    Logger.debug("Starting AMQP workers with url #{@url}")
    pool = [
      # Consumer
      Supervisor.child_spec({Routing.Consumer,
                            [[@url, "newx", "new_orders", :direct], &consume_new_order/1]},
                            id: :neworder),
      Supervisor.child_spec({Routing.Consumer,
                            [[@url, "genx", "generated_order", :direct], &consume_generated_order/1]},
                            id: :generated),
      Supervisor.child_spec({Routing.Consumer,
                            [[@url, "distributionex", "distribution", :direct], &consume_distribution/1]},
                            id: :distribution),
      Supervisor.child_spec({Routing.Consumer,
                            [[@url, "settingsx", "routing_settings", :fanout], &consume_new_order/1]},
                            id: :settings),
      # Producer
      Routing.Eventcomm.child_spec([]),
      Routing.Errorcomm.child_spec([])
    ]
    Supervisor.init(pool, [strategy: :one_for_one, name: Routing.RabbitMQ])
  end

  def consume_new_order(payload), do: consume(&Routehandler.calc_delivery/1, payload)

  def consume_generated_order(payload), do: consume(&Routehandler.calc_generated/1, payload)

  def consume_distribution(payload), do: consume(&Routehandler.calc_distribution/1, payload)

  def consume_settings(payload), do: consume(nil, payload)

  def consume(function, payload) do
    case function.(payload) do
      {:err, message} ->
        Logger.warn(message)
        send_error(message)
      {:ok, message} ->
        Logger.info(message)
      message ->
        Logger.warn("Calculating #{inspect(function)} for #{payload} resulted in an unkown error: #{message}")
    end
  end

  def send_error(message), do: Errorcomm.publish(message)

  def send_event(message), do: Eventcomm.publish(message)
end

