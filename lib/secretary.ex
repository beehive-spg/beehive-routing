defmodule Routing.Secretary do
  require Logger
  use Timex
  use Quantum.Scheduler, otp_app: :routing

  alias Routing.Redixcontrol

  # Do not dare to implement the init method. It is already implemented by Quantum.Scheduler

  def check do
    Logger.debug "Time checking ..."
    jobs = []
    jobs = Redixcontrol.active_jobs
    if jobs != [] do
      [next | _] = jobs
      Logger.debug "Next job: #{next}"
      time_str = Redixcontrol.query ["HGET", next, "time"]
      time_form = Timex.parse!(time_str, Application.fetch_env!(:timex, :datetime_format))

     if Timex.diff(Timex.shift(Timex.now, hours: 1), time_form, :seconds) >= 0 do
        execute_job(next)
      end
    end
  end

  def execute_job(job) do
    Logger.info("Executing #{job}")
    prefix = String.split(job, "_")
    case prefix do
      ["arr", _] -> execute_arrival(job)
      ["dep", _] -> execute_depart(job)
      _     -> unknown_job(job)
    end
  end

  def execute_arrival(arr) do
    # TODO Notify database about completed hop. Update drone status. Update package status. To be implemented.
    dbdata = mapify(Redixcontrol.query(["HGETALL", arr]))
    data = Map.merge(%{type: "arr"}, dbdata)
    json = Poison.encode!(data)
    Routing.Eventcomm.publish(json)
    Redixcontrol.remove_arrival(arr)
  end

  def execute_depart(dep) do
    # TODO Notify database about completed hop. Update drone status. Update package status. To be implemented.
    dbdata = mapify(Redixcontrol.query(["HGETALL", dep]))
    mapdata = Map.merge(%{type: "dep", destination: "#{Map.get(dbdata, :location)}"}, dbdata)
    arrival = Redixcontrol.query(["HGET", Map.get(dbdata, :arrival), "location"])
    mapdata = Map.merge(%{type: "dep", destination: arrival}, dbdata)
    json = Poison.encode!(mapdata)
    Routing.Eventcomm.publish(json)
    Redixcontrol.remove_departure(dep)
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

