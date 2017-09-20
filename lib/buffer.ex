defmodule Buffer do
    use Application
    require Logger

    def start _type, _args do
        Logger.info("Application started...")
        redix = Buffer.Redixcontrol.start_link(name: Buffer.Redixcontrol)
    end

    def stop _args do
        Logger.info("Application stopped...")
    end
end
