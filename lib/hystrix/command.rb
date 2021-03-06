# TODO: implement pluggable metrics collection. implement separate statsd impl

module Hystrix
	class ExecutorPoolFullError < StandardError; end
	class CircuitClosedError < StandardError; end

	class Command
		include Celluloid

		attr_accessor :executor_pool, :circuit

		@default_pool_size = 10
		def self.default_pool_size
			@default_pool_size
		end

		def initialize(*args)
			self.executor_pool = CommandExecutorPools.instance.get_pool(executor_pool_name, self.class.default_pool_size)
			self.circuit = self.executor_pool.circuit_supervisor.actors.first
		end

		# Run the command synchronously
		def execute
			raise 'No executor pool found! Did you forget to call super in your initialize method?' unless executor_pool

			executor = nil
			start_time = Time.now

			begin
				raise CircuitClosedError unless self.circuit.is_closed?

				executor = executor_pool.take
				
				result = executor.run(self)
				duration = Time.now - start_time

				Configuration.notify_success(executor_pool_name, duration)
			rescue Exception => main_error
				duration = Time.now - start_time

				begin
					if main_error.respond_to?(:cause)
						result = fallback(main_error.cause)
						Configuration.notify_fallback(executor_pool_name, duration, main_error.cause)
					else
						result = fallback(main_error)
						Configuration.notify_fallback(executor_pool_name, duration, main_error)
					end
				rescue NotImplementedError => fallback_error
					Configuration.notify_failure(executor_pool_name, duration, main_error)
					raise main_error
				end
			ensure
				executor.unlock if executor
				self.terminate
			end

			return result
		end

		# Commands which share the value of executor_pool_name will use the same pool
		def executor_pool_name
			@executor_pool_name || self.class.name
		end

		# Run the command asynchronously
		def queue
			future.execute
		end

		def fallback(error)
			raise NotImplementedError
		end

		def self.pool_size(size)
			@default_pool_size = size
		end
	end
end