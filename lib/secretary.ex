defmodule Routing.Secretary do
  require Logger
  use Timex
  use Quantum.Scheduler, otp_app: :routing

  alias Routing.Redixcontrol

  # Do not dare to implement the init method. It is already implemented by Quantum.Scheduler

  def check do
    #Logger.debug "Time checking ..."
    #jobs = []
    jobs = Redixcontrol.active_jobs
    if jobs != [] do
      [next | _] = jobs
      Logger.debug "Next job: #{next}"
      time_str = Redixcontrol.query ["HGET", next, "time"]
      time_form = Timex.parse!(time_str, Application.fetch_env!(:timex, :datetime_format))

      if Timex.diff(Timex.now, time_form, :seconds) >= 0 do
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
    Logger.debug("Notify database about completed hop. Update drone status. Update package status. To be implemented.") # TODO
    Redixcontrol.remove_arrival(arr)
  end

  def execute_depart(dep) do
    Logger.debug("Notify database about started hop. Update drone status. Update package status. To be implemented.") # TODO
    Redixcontrol.remove_departure(dep)
  end

  def unknown_job(job) do
    Logger.error("Unknown job #{job}! Removing it from list.")
    Redixcontrol.query(["LREM", "active_jobs", "-1", "#{job}"])
  end

end
