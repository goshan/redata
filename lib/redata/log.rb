module Redata
	class Log
		def self.error!(msg)
			puts "[#{RED.current_time}] #{msg.red}"
			exit 1
		end

		def self.warning(msg)
			puts "[#{RED.current_time}] #{msg.yellow}"
		end

		def self.action(msg)
			puts "[#{RED.current_time}] #{msg.cyan}"
		end

		def self.log(msg)
			puts "[#{RED.current_time}] #{msg}"
		end
	end
end
