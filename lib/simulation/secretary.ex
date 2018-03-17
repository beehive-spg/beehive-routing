defmodule Routing.Secretary do
  require Logger
  use Timex
  use Quantum.Scheduler, otp_app: :routing

  alias Routing.Redixcontrol

  # Do not dare to implement the init method. It is already implemented by Quantum.Scheduler

  def check do
    Logger.debug "Time checking ..."
    jobs = Redixcontrol.get_next_job()
    if jobs != [] do
      Enum.each(jobs, fn(job) ->
        Task.start(fn ->
          execute_job(job)
        end)
      end)
    end
  end

  def execute_job(job) do
    # Logger.info("Executing #{job}")
    prefix = String.split(job, "_")
    case prefix do
      ["arr", _] -> execute_arrival(job)
      ["dep", _] -> execute_depart(job)
      _     -> unknown_job(job)
    end
  end

  def execute_arrival(arr) do
    dbdata = mapify(Redixcontrol.query(["HGETALL", arr]))
    data = Map.merge(%{type: "arr"}, dbdata)
    data = Map.get(data, :time)
           |> Timex.parse!(Application.fetch_env!(:timex, :datetime_format))
           |> Timex.to_unix
           |> Kernel.*(1000)
           |> (fn x -> Map.replace(data, :time, x) end).()
    json = Poison.encode!(data)

    case HTTPotion.get("http://beehive-database:3000/one/hops/#{data[:hop_id]}") do
      %{:body => b, :headers => _, :status_code => 200} ->	
        if b == "" do
          Logger.info("!! ERROR !! Arrival hop #{:hop_id} does not exist")
        else
          Logger.info("Success: Arrival hop to be executed exists")
        end
      _ ->
        Logger.error("Could not check for hop")
    end

    # TODO publish notification to frontend only of database confirms event (when Emin fixes the bug)

    Routing.Eventcomm.publish(json)
    Map.update!(data, :hop_id, &(String.to_integer(&1)))
      |> Map.update!(:route_id, &(String.to_integer(&1)))
      |> Routing.Routerepo.notify_arrival
    Redixcontrol.remove_arrival(arr)
    Logger.info("Executed arrival #{arr} for hop #{data[:hop_id]} in route #{data[:route_id]}")
  end

  def execute_depart(dep) do
    dbdata = mapify(Redixcontrol.query(["HGETALL", dep]))
    data = Map.merge(%{type: "dep"}, dbdata)
    data = Map.get(data, :time)
           |> Timex.parse!(Application.fetch_env!(:timex, :datetime_format))
           |> Timex.to_unix
           |> Kernel.*(1000) |> (fn x -> Map.replace(data, :time, x) end).()
    json = Poison.encode!(data)

    case HTTPotion.get("http://beehive-database:3000/one/hops/#{data[:hop_id]}") do
      %{:body => b, :headers => _, :status_code => 200} ->	
        if b == "" do
          Logger.info("!! ERROR !! Departure hop #{:hop_id} does not exist")
        else
          Logger.info("Success: Departure hop to be executed exists")
        end
      _ ->
        Logger.error("Could not check for hop")
    end

    Routing.Eventcomm.publish(json)
    Map.update!(data, :hop_id, &(String.to_integer(&1)))
      |> Map.update!(:route_id, &(String.to_integer(&1)))
      |> Map.delete(:arrival)
      |> Routing.Routerepo.notify_departure
    Redixcontrol.remove_departure(dep)
    Logger.info("Executed departure #{dep} for hop #{data[:hop_id]} in route #{data[:route_id]}")
  end

  def unknown_job(job) do
    Logger.error("Unknown job #{job}! Removing it from list.")
    Redixcontrol.query(["LREM", "active_jobs", "-1", "#{job}"])
  end

  def mapify([key | [value | []]]) do
    %{"#{key}": "#{value}"}
  end
  def mapify([key | [value | t]]) do
    Map.merge(%{"#{key}": "#{value}"}, mapify(t))
  end
end

