defmodule Routing do
  use Application
  require Logger

  def start _type, _args do
    Logger.info "Application started..."

    children = [
      Routing.Neworder.child_spec []
    ]

    opts = [strategy: :one_for_one, name: Routing]
    Supervisor.start_link(children, opts)
  end

  def stop _args do
    Logger.info "Application stopped..."
  end

end
