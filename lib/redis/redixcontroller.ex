defmodule Routing.Redixcontrol do
  use Supervisor
  require Logger

  # NOTE that when creating a arrival / departure you get back only the number of the key (= id) and
  # not the key intself. The id is used for creating and deleting arrivals/departures. However,
  # when calling get/set you need the key.
  # E.g. key = arr_00, id = 00

  def start_link(opts), do: Supervisor.start_link(__MODULE__, :ok, opts)

  def init(_args) do
    poolsize = 3
    host = Application.fetch_env!(:redix, :host)
    port = Application.fetch_env!(:redix, :port)

    Logger.debug("Creating Redix pool: poolsize: #{poolsize}, url: #{host}, port: #{port}, password: #{pwd}")

    pool = for i <- 0..(poolsize-1) do
      args = [[host: host, port: port], [name: :"redix_#{i}"]]
      Supervisor.child_spec({Redix, args}, id: {Redix, i})
    end

    opts = [strategy: :one_for_one, name: Routing.Redixcontrol]
    Supervisor.init(pool, opts)
  end

  def query(command, worker \\ -1) when is_list(command) do
    name = case worker do
      -1 -> :"redix_#{randomize()}"
      _  -> :"redix_#{worker}"
    end

    {status, resp} = Redix.command(name, command)
    Logger.debug("#{command} executed on #{name}. Status: #{status}")
    resp
  end

  def pipe(commands, worker \\ -1) when is_list(commands) do
    name = case worker do
      -1 -> :"redix_#{randomize()}"
      _  -> :"redix_#{worker}"
    end

    {status, resp} = Redix.pipeline(name, commands)
    Logger.debug("#{commands} executed on #{name}. Status: #{status}")
    resp
  end

  # route = [%{:dep_time => "2018-01-01 00:00:00", :arr_time => "2018-01-01 00:05:00", :hop => "1720394393", :route_id => "1723423421"}]
  def add_route(route) when is_list(route) do
    ids = insert_hops_redis(route)
    link_hops(ids)
    ids
  end

  defp insert_hops_redis([]), do: []
  defp insert_hops_redis([head | tail]) do
    dep_id = add_departure(head[:dep_time], head[:hop], head[:route_id])
    arr_id = add_arrival(head[:arr_time], head[:hop], head[:route_id])
    [[dep_id, arr_id]] ++ insert_hops_redis(tail)
  end

  defp link_hops([]), do: Logger.debug("Route inserted successfully")
  defp link_hops([head | tail]) do
    command = ["HSET", "dep_#{Enum.at(head, 0)}", "arrival", "arr_#{Enum.at(head, 1)}"]
    query(command)
    link_hops(tail)
  end

  # TODO maybe merge the two methods for each type is entry to make it more DRY
  def add_arrival(time, hop, route_id) do
    Logger.debug("Adding arrival, time: #{time}, hop_id: #{hop}, route_id: #{route_id}")

    id = get_next_id("arr")
    commands = [["MULTI"]]
    commands = commands ++ [["HSET", "arr_#{id}", "time", "#{time}"]]
    commands = commands ++ [["HSET", "arr_#{id}", "hop_id", "#{hop}"]]
    commands = commands ++ [["HSET", "arr_#{id}", "route_id", "#{route_id}"]]
    commands = commands ++ [["RPUSH", "active_jobs", "arr_#{id}"]]
    commands = commands ++ [["EXEC"]]
    pipe(commands)

    Logger.debug("Arrival successfully added")
    id
  end

  def add_departure(time, hop, route_id) do
    Logger.debug("Adding departure, time: #{time}, hop_id: #{hop}, route_id: #{route_id}")

    id = get_next_id("dep")
    commands = [["MULTI"]]
    commands = commands ++ [["HSET", "dep_#{id}", "time", "#{time}"]]
    commands = commands ++ [["HSET", "dep_#{id}", "hop_id", "#{hop}"]]
    commands = commands ++ [["HSET", "dep_#{id}", "route_id", "#{route_id}"]]
    commands = commands ++ [["RPUSH", "active_jobs", "dep_#{id}"]]
    commands = commands ++ [["EXEC"]]
    pipe(commands)

    Logger.debug("Departure successfully added")
    id
  end

  def remove_arrival(key) when is_bitstring(key) do
    Logger.debug("Deleting arrival for key: #{key}")

    commands = [["MULTI"]]
    commands = commands ++ [["DEL", key]] # remove hash from db
    commands = commands ++ [["LREM", "active_jobs", "1", key]] # set key inactive
    commands = commands ++ [["EXEC"]]
    pipe(commands)
  end

  def remove_departure(key) when is_bitstring(key) do
    Logger.debug("Deleting departure for key: #{key}")

    commands = [["MULTI"]]
    commands = commands ++ [["DEL", key]] # remove hash from db
    commands = commands ++ [["LREM", "active_jobs", "1", key]] # set key inactive
    commands = commands ++ [["EXEC"]]
    pipe(commands)
  end

  def active_jobs() do
    jobs = query(["LRANGE", "active_jobs", "0", "-1"])
    case jobs do
      [next | _] ->
        if query(["HGET", next, "time"]) == nil do
          query(["LREM", "active_jobs", "1", next])
          active_jobs()
        end
      [] ->
        []
    end
    jobs
  end

  def get_next_job, do: next(active_jobs())
  defp next([]), do: []
  defp next([h | t]) do
    item_time = Timex.parse!(query(["HGET", h, "time"]), Application.fetch_env!(:timex, :datetime_format))
    result = if Timex.diff(Timex.shift(Timex.now, hours: 1), item_time, :seconds) < 0 do
      next(t)
    else
      [h] ++ next(t)
    end
    result
  end

  def get_next_id(from) when is_bitstring(from), do: query(["INCR", "#{from}_next_id"])

  def get(key, worker \\ -1), do: query(["GET", "#{key}"], worker)

  def set(key, value, worker \\ -1), do: query(["SET", "#{key}", "#{value}"], worker)

  defp randomize, do: rem(System.unique_integer([:positive]), 3)
end

