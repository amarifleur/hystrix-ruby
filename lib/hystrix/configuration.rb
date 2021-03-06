module Hystrix
	class Configuration
		def self.on_success(&block)
			@on_success = block
		end
		def self.notify_success(command_name, duration)
			if @on_success
				@on_success.call(command_name, duration)
			end
		end

		def self.on_fallback(&block)
			@on_fallback = block
		end
		def self.notify_fallback(command_name, duration, error)
			if @on_fallback
				@on_fallback.call(command_name, duration, error)
			end
		end

		def self.on_failure(&block)
			@on_failure = block
		end
		def self.notify_failure(command_name, duration, error)
			if @on_failure
				@on_failure.call(command_name, duration, error)
			end
		end

		def self.reset
			@on_success = nil
			@on_fallback = nil
			@on_failure = nil
		end
	end
end