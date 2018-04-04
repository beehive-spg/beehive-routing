defmodule Routing.AMQP_Supervisor do
  use Supervisor
  require Logger

  alias Routing.{Errorcomm, Routehandler}

  @url Application.fetch_env!(:routing, :amqp_url)

  def start_link(_opts), do: Supervisor.start_link(__MODULE__, :ok, [])

  def init(_args) do
    Logger.debug("Starting AMQP workers with url #{@url}")
    pool = [
      Supervisor.child_spec({Routing.Consumer,
                            [{@url, "newx", "new_orders"}, &consume_new_order/1]},
                            id: {Routing.Consumer, "Neworders"}),
      Supervisor.child_spec({Routing.Consumer,
                            [{@url, "genx", "generated_order"}, &consume_generated_order/1]},
                            id: {Routing.Consumer, "Generated"}),
      Supervisor.child_spec({Routing.Consumer,
                            [{@url, "distributionex", "distribution"}, &consume_distribution/1]},
                            id: {Routing.Consumer, "Distribution"})
    ]
   Supervisor.init(pool, [strategy: :one_for_one, name: Routing.AMQP_Supervisor])
  end

  def consume_new_order(payload), do: consume(&Routehandler.calc_delivery/1, payload)

  def consume_generated_order(payload), do: consume(&Routehandler.calc_generated/1, payload)

  def consume_distribution(payload), do: consume(&Routehandler.calc_distribution/1, payload)

  def consume(function, payload) do
    case function.(payload) do
      {:err, message} ->
        Logger.warn(message)
        Errorcomm.publish(message)
      {:ok, message} ->
        Logger.info(message)
      message ->
        Logger.warn("Calculating #{inspect(function)} for #{payload} resulted in an unkown error: #{message}")
    end
  end
end
