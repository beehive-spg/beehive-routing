defmodule Buffer.Secretary do
    require Logger
    use Timex
    use Quantum.Scheduler, otp_app: :buffer

    # Do not dare to implement the init method. It is already implemented by Quantum.Scheduler

    def check do
      #     Logger.debug "Time checking ..."
        # get closest job from redis
        # calculate difference
        # if now -> execute_job
        # else nothing

        #[next | _] = Buffer.Redixcontrol.active_jobs
        #time_str = Buffer.Redixcontrol.get(next)
        #time_form = Timex.parse!(time_str, Application.fetch_env!(:timex, :datetime_format))

        #if Timex.diff(Timex.now, time_form, :seconds) <= 0 do
        #   execute_job(Buffer.Redixcontrol.get(next))
        #end

    end

    def execute_job(job) do
        true
    end

end
