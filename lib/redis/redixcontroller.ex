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
    # pwd  = Application.fetch_env!(:redix, :password)

    Logger.debug("Creating Redix pool: poolsize: #{poolsize}, url: #{host}, port: #{port}, password: #{pwd}")

    pool = for i <- 0..(poolsize-1) do
      # args = [[host: host, port: port, password: pwd], [name: :"redix_#{i}"]]
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

    Logger.debug("Executing #{command} on instance #{name}")
    {status, resp} = Redix.command(name, command)
    Logger.debug("Command executed. Status: #{status}")
    resp
  end

  def pipe(commands, worker \\ -1) when is_list(commands) do

    name = case worker do
      -1 -> :"redix_#{randomize()}"
      _  -> :"redix_#{worker}"
    end

    Logger.debug("Executing #{commands} on instance #{name}")
    {status, resp} = Redix.pipeline(name, commands)
    Logger.debug("Command executed. Status: #{status}")
    resp
  end

  # route = %{:is_delivery => true/false, :route => [%{from => "Vienna", to => "Berlin", dep_time => "Mon", arr_time => "Tue", drone => "512"}, ...]}
  def add_route(route) when is_map(route) do
    delivery = route[:is_delivery]
    ids = insert_hops_db(route[:route], delivery)
    link_hops(ids)
    ids
  end

  defp insert_hops_db([head | []], is_delivery) do
    dep_id = add_departure(head[:dep_time], head[:drone], head[:from], is_delivery)
    arr_id = add_arrival(head[:arr_time], head[:drone], head[:to], is_delivery)
    [[dep_id, arr_id]]
  end
  defp insert_hops_db([head | tail], is_delivery) do
    dep_id = add_departure(head[:dep_time], head[:drone], head[:from], is_delivery)
    arr_id = add_arrival(head[:arr_time], head[:drone], head[:to], is_delivery)
    [[dep_id, arr_id]] ++ insert_hops_db(tail, is_delivery)
  end

  defp link_hops([head | []]) do
    command = ["HSET", "dep_#{Enum.at(head, 0)}", "arrival", "arr_#{Enum.at(head, 1)}"]
    query(command)
  end
  defp link_hops([head | tail]) do
    command = ["HSET", "dep_#{Enum.at(head, 0)}", "arrival", "arr_#{Enum.at(head, 1)}"]
    query(command)
    link_hops(tail)
  end

  # [%{:departure => "dep_124", :arrival => "dep_256", :hop_id => "64"}, ...]
  # TODO What is stored in the database? Key or ID? Currently acting like key
  def link_hops_db_id([head | []]) do
    query(["HSET", "#{head[:from]}", "db_id", "#{head[:hop_id]}"])
    query(["HSET", "#{head[:to]}", "db_id", "#{head[:hop_id]}"])
  end
  def link_hops_db_id([head | tail]) do
    query(["HSET", "#{head[:from]}", "db_id", "#{head[:hop_id]}"])
    query(["HSET", "#{head[:to]}", "db_id", "#{head[:hop_id]}"])
    link_hops_db_id(tail)
  end

  # TODO maybe merge the two methods for each type is entry to make it more DRY
  def add_arrival(time, drone, location, is_delivery) do
    Logger.debug("Adding arrival for drone: time: #{time}, drone: #{drone}, location: #{location}, is_delivery: #{is_delivery}")
    id = get_next_id("arr")
    # TODO add proper debug info for list of active arr ids and the added object (same for departure and removal)

    commands = [["MULTI"]]
    commands = commands ++ [["HSET", "arr_#{id}", "time", "#{time}"]]
    commands = commands ++ [["HSET", "arr_#{id}", "drone", "#{drone}"]]
    commands = commands ++ [["HSET", "arr_#{id}", "location", "#{location}"]]
    commands = commands ++ [["HSET", "arr_#{id}", "is_delivery", "#{is_delivery}"]]
    commands = commands ++ [["RPUSH", "active_jobs", "arr_#{id}"]]
    commands = commands ++ [["EXEC"]]
    pipe(commands)

    Logger.debug("Arrival successfully added")
    id
  end

  def add_departure(time, drone, location, is_delivery) do
    Logger.debug("Adding departure for drone: time: #{time}, drone: #{drone}, location: #{location}, is_delivery: #{is_delivery}")
    id = get_next_id("dep")

    commands = [["MULTI"]]
    commands = commands ++ [["HSET", "dep_#{id}", "time", "#{time}"]]
    commands = commands ++ [["HSET", "dep_#{id}", "drone", "#{drone}"]]
    commands = commands ++ [["HSET", "dep_#{id}", "location", "#{location}"]]
    commands = commands ++ [["HSET", "dep_#{id}", "is_delivery", "#{is_delivery}"]]
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

    Logger.debug("Arrival deleted")
  end

  def remove_departure(key) when is_bitstring(key) do
    Logger.debug("Deleting departure for key: #{key}")

    commands = [["MULTI"]]
    commands = commands ++ [["DEL", key]] # remove hash from db
    commands = commands ++ [["LREM", "active_jobs", "1", key]] # set key inactive
    commands = commands ++ [["EXEC"]]
    pipe(commands)

    Logger.debug("Departure deleted")
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

  def get_next_job() do
    next(active_jobs())
  end
  defp next([]) do
    nil
  end
  defp next([h | t]) do
    item_time = Timex.parse!(query(["HGET", h, "time"]), Application.fetch_env!(:timex, :datetime_format))
    if Timex.diff(Timex.shift(Timex.now, hours: 1), item_time, :seconds) < 0 do
      result = next(t)
    else
      result = h
    end
    result
  end

  def get_next_id(from) when is_bitstring(from) do
    query(["INCR", "#{from}_next_id"])
  end

  def get(key, worker \\ -1) do
    query(["GET", "#{key}"], worker)
  end

  def set(key, value, worker \\ -1) do
    query(["SET", "#{key}", "#{value}"], worker)
  end

  defp randomize() do
    rem(System.unique_integer([:positive]), 3)
  end
end
