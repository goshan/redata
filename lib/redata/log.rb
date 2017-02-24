module Redata
	class Log
		def self.error!(msg)
			puts msg.red
			self.file msg
			exit 1
		end

		def self.warning(msg)
			puts msg.yellow
			self.file msg
		end

		def self.action(msg)
			puts msg.cyan
			self.file msg
		end

		def self.log(msg)
			puts msg
			self.file msg
		end

		def self.file(msg)
			File.open RED.log_file, 'a' do |f|
				f.puts "[#{RED.current_time}] #{msg}"
			end
		end
	end
end
