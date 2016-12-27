module Redata
	class Ssh
		def initialize
			@ssh = RED.ssh
		end

		def run_with_ssh?
			if RED.is_ssh && @ssh && !RED.production?
				Log.warning "WARNING: Using gateway server #{@ssh['HostName']}"
				return true
			end

			if RED.is_ssh
				Log.warning "WARNING: SSH config file was not found. Ignore this config." unless @ssh
				Log.warning "WARNING: Could not use ssh mode in production. Ignore this config." if RED.production?
			end
			return false
		end

		def upload_file(file, target_file=nil)
			system "scp -i #{@ssh['IdentityFile']} #{file} #{@ssh['User']}@#{@ssh['HostName']}:~/tmp/#{target_file}"
		end

		def run_command(cmd)
			system "ssh -i #{@ssh['IdentityFile']} #{@ssh['User']}@#{@ssh['HostName']} \"#{cmd}\""
		end
	end
end
