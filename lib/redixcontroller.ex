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

    # TODO maybe merge the two methods for each type is entry to make it more DRY
    def add_arrival(time, drone, hive, is_delivery) when is_bitstring(time) and is_bitstring(drone) and is_bitstring(hive) and (is_boolean(is_delivery) or is_bitstring(is_delivery)) do
        Logger.debug "Adding arrival for drone: time: #{time}, drone: #{drone}, hive: #{hive}, is_delivery: #{is_delivery}"
        id = get_next_id("arr")
        # TODO add proper debug info for list of active arr ids and the added object (same for departure and removal)
        # TODO make the list sorted (use isert_sorted)

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

    def add_departure(time, drone, hive, is_delivery) when is_bitstring(time) and is_bitstring(drone) and is_bitstring(hive) and (is_boolean(is_delivery) or is_bitstring(is_delivery)) do
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

    def remove_arrival(id) when is_bitstring(id) do
        Logger.debug "Deleting arrival for key: arr_#{id}"

        commands = [["MULTI"]]
        commands = commands ++ [["DEL", "arr_#{id}"]] # remove hash from db
        commands = commands ++ [["LREM", "active_jobs", "-1", "arr_#{id}"]] # set key inactive
        commands = commands ++ [["EXEC"]]
        pipe commands

        Logger.debug "Arrival deleted"
    end

    def remove_departure(id) when is_bitstring(id) do
        Logger.debug "Deleting departure for key: dep_#{id}"

        commands = [["MULTI"]]
        commands = commands ++ [["DEL", "dep_#{id}"]] # remove hash from db
        commands = commands ++ [["LREM", "active_jobs", "-1", "dep_#{id}"]] # set key inactive
        commands = commands ++ [["EXEC"]]
        pipe commands

        Logger.debug "Departure deleted"
    end

    def active_jobs() do
        query ["LRANGE", "active_jobs", "0", "-1"]
    end

    def get_next_id(from) when is_bitstring(from) do
        worker = randomize()
        query ["MULTI"], worker # start transaction

        get "#{from}_next_id", worker
        query ["INCR", "#{from}_next_id"], worker

        [resp | _] = query ["EXEC"], worker # commit
        resp
    end

    def get(key, worker \\ -1) do
        query ["GET", "#{key}"], worker
    end

    def set(key, value, worker \\ -1) do
        query ["SET", "#{key}", "#{value}"], worker
    end

    def insert_sorted(item) do
        active_ids = query ["LRANGE", "active_jobs", "0", "-1"]
        array =  sorted_array(active_ids, item)
        commands = [["MULTI"]]
        commands = commands ++ commands_insert_array(array)
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
