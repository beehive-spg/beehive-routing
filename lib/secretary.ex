defmodule Buffer.Secretary do
	require Logger
	use Quantum.Scheduler, otp_app: :buffer

	def check do
		#import Buffer.Redixcontrol

		Logger.debug "Checking for job started ..."


	end

	# Do not dare to implement the init method. It is already implemented by Quantim.Scheduler
	

end