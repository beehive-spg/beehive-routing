defmodule Buffer.Redixcontrol do
    use Supervisor
    require Logger

    # NOTE that when creating a arrival / departure you get back only the number of the key (= id) and
    # not the key intself. The id is used for creating and deleting arrivals/departures. However,
    # when calling get/set you need the key.
    # E.g. key = arr_00, id = 00

    def start_link(opts) do
        Supervisor.start_link(__MODULE__, :ok, opts)
    end

    def init(:ok) do
        poolsize = 3
        host = Application.fetch_env!(:redix, :host)
        port = Application.fetch_env!(:redix, :port)

        Logger.debug "Creating Redix pool: poolsize: #{poolsize}, url: #{host}, port: #{port}"

        pool = for i <- 0..(poolsize-1) do
            args = [[host: host, port: port], [name: :"redix_#{i}"]]
            Supervisor.child_spec({Redix, args}, id: {Redix, i})
        end

        opts = [strategy: :one_for_one, name: Buffer.Redixcontrol]
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
        # Here goes the code for: link departures and arrivals to each other
        # -currently not wanted, but there was a reason why I thought about that, not sure atm-
        # Access last item of a list:
        # [h | t] = Enum.reverse(list)
        # do something with t
        # method(Enum.reverse(h)) --> to restore normal order
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

    # TODO maybe merge the two methods for each type is entry to make it more DRY
    def add_arrival(time, drone, hive, is_delivery) do
        Logger.debug "Adding arrival for drone: time: #{time}, drone: #{drone}, hive: #{hive}, is_delivery: #{is_delivery}"
        id = get_next_id("arr")
        # TODO add proper debug info for list of active arr ids and the added object (same for departure and removal)

        commands = [["MULTI"]]
        commands = commands ++ [["HSET", "arr_#{id}", "time", "#{time}"]]
        commands = commands ++ [["HSET", "arr_#{id}", "drone", "#{drone}"]]
        commands = commands ++ [["HSET", "arr_#{id}", "hive", "#{hive}"]]
        commands = commands ++ [["HSET", "arr_#{id}", "is_delivery", "#{is_delivery}"]]
        commands = commands ++ [["EXEC"]]
        pipe commands

        insert_sorted("arr_#{id}")
        Logger.debug "Arrival successfully added"
        id
    end

    def add_departure(time, drone, hive, is_delivery) do
        Logger.debug "Adding departure for drone: time: #{time}, drone: #{drone}, hive: #{hive}, is_delivery: #{is_delivery}"
        id = get_next_id("dep")

        commands = [["MULTI"]]
        commands = commands ++ [["HSET", "dep_#{id}", "time", "#{time}"]]
        commands = commands ++ [["HSET", "dep_#{id}", "drone", "#{drone}"]]
        commands = commands ++ [["HSET", "dep_#{id}", "hive", "#{hive}"]]
        commands = commands ++ [["HSET", "dep_#{id}", "is_delivery", "#{is_delivery}"]]
        commands = commands ++ [["EXEC"]]
        pipe commands

        insert_sorted("dep_#{id}")
        Logger.debug "Departure successfully added"
        id
    end

    def remove_arrival(key) when is_bitstring(key) do
        Logger.debug "Deleting arrival for key: #{key}"

        commands = [["MULTI"]]
        commands = commands ++ [["DEL", key]] # remove hash from db
        commands = commands ++ [["LREM", "active_jobs", "-1", key]] # set key inactive
        commands = commands ++ [["EXEC"]]
        pipe commands

        Logger.debug "Arrival deleted"
    end

    def remove_departure(key) when is_bitstring(key) do
        Logger.debug "Deleting departure for key: #{key}"

        commands = [["MULTI"]]
        commands = commands ++ [["DEL", key]] # remove hash from db
        commands = commands ++ [["LREM", "active_jobs", "-1", key]] # set key inactive
        commands = commands ++ [["EXEC"]]
        pipe commands

        Logger.debug "Departure deleted"
    end

    def active_jobs() do
        query ["LRANGE", "active_jobs", "0", "-1"]
    end

    def get_next_id(from) when is_bitstring(from) do
        query ["INCR", "#{from}_next_id"]
    end

    def get(key, worker \\ -1) do
        query ["GET", "#{key}"], worker
    end

    def set(key, value, worker \\ -1) do
        query ["SET", "#{key}", "#{value}"], worker
    end

    defp wait_for_not_locked() do
        accessible = query ["SETNX", "locked", "true"]
        IO.puts accessible
        if accessible == 0 do
            :timer.sleep(10)
            wait_for_not_locked()
        end
    end

    def insert_sorted(item) do
        Task.async(fn -> wait_for_not_locked() end) |> Task.await
        array =  sorted_array(active_jobs(), item)
        commands = [["MULTI"]]
        commands = commands ++ [["DEL", "active_jobs"]]
        commands = commands ++ commands_insert_array(array)
        commands = commands ++ [["DEL", "locked"]]
        commands = commands ++ [["EXEC"]]
        pipe commands
    end

    defp commands_insert_array([head | []]) do
        [["RPUSH", "active_jobs", "#{head}"]]
    end

    defp commands_insert_array([head | tail]) do
        [["RPUSH", "active_jobs", "#{head}"]] ++ commands_insert_array(tail)
    end

    defp sorted_array([], item) do
        [item]
    end

    defp sorted_array([head | tail], item) do
        head_db = query ["HGET", "#{head}", "time"]
        item_db = query ["HGET", "#{item}", "time"] # TODO pass this as a parameter during the recursion -> stays the same
        diff = compare_time(head_db, item_db)
        if diff > 0 do # head time is bigger than item time -> item needs to be before head
            if tail == [] do
                [item | head]
            end
            [item, head | tail]
        else # item time is bigger than head time -> needs to be after head
            if tail == [] do # if there is no other item behind head
                [head | item]
            end
            [head | sorted_array(tail, item)]
        end
    end

    # Returns >0 if time2 is smaller (needs to be executed earlier)
    # Returns 0 if times are equal (in seconds)
    # Returns <0 if time1 is smaller (needs to be executed earlier)
    # NOTE this is to be used to compare times saved in the redis db. If you want to set time1/2 to Timex.now
    # just comment Timex.parse!
    defp compare_time(time1, time2) when is_bitstring(time1) and is_bitstring(time2) do
        time1 = Timex.parse!(time1, Application.fetch_env!(:timex, :datetime_format))
        time2 = Timex.parse!(time2, Application.fetch_env!(:timex, :datetime_format))
        Timex.diff(time1, time2, :seconds)
    end

    defp randomize() do
        rem(System.unique_integer([:positive]), 3)
    end
end
