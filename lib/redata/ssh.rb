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

		def upload_dir(dir)
			`scp -r -i #{@ssh['IdentityFile']} #{dir} #{@ssh['User']}@#{@ssh['HostName']}:~/tmp/`
		end

		def run_command(cmd)
			out, err, status = Open3.capture3 "ssh -i #{@ssh['IdentityFile']} #{@ssh['User']}@#{@ssh['HostName']} \"#{cmd}\""
			puts err unless err.empty?
			Log.file out unless out.empty?
			Log.file err unless err.empty?
		end

		def local_command(cmd)
			out, err, status = Open3.capture3 cmd
			puts err unless err.empty?
			Log.file out unless out.empty?
			Log.file err unless err.empty?
		end

		def remove_dir(dir)
			`ssh -i #{@ssh['IdentityFile']} #{@ssh['User']}@#{@ssh['HostName']} \"rm -rf #{dir}\"`
		end
	end
end
