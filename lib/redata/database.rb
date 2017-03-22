module Redata
	class DataBase
		REDSHIFT_PORT = 5439

		def initialize
			Log.error! "ERROR: Database of #{RED.env} was not declared in config/red_access.yml" unless RED.root.join('config', 'red_access.yml').exist?
			@config = YAML.load(ERB.new(File.read(RED.root.join 'config', 'red_access.yml')).result(binding))[RED.env]
			Log.error! "ERROR: Database of #{RED.env} was not declared in config/red_access.yml" unless @config

			@ssh = Ssh.new
		end

		def connect_redshift(config)
			cmd = make_redshift_cmd
			if @ssh.run_with_ssh?
				@ssh.upload_dir config.tmp_file_dir
				@ssh.run_command "export PGPASSWORD='#{ENV['PGPASSWORD']}';#{cmd} -f ~/tmp/#{config.tmp_file_dir.basename}/exec.sql"
				@ssh.remove_dir "~/tmp/#{config.tmp_file_dir.basename}"
			else
				@ssh.local_command "#{cmd} -f #{config.tmp_exec_file}"
			end
		end

		def inject_data(config, stage)
			target_config = @config['deploy'][config.category.to_s]
			Log.error! "ERROR: Export config of #{config.category} was not found" unless target_config

			target_config = target_config[stage] if stage
			Log.error! "ERROR: Export config of #{config.category} for stage #{stage} was not found" unless target_config

			if target_config['local_dir']
				if Pathname.new(target_config['local_dir']).absolute?
					local_dir = Pathname.new(target_config['local_dir'])
				else
					local_dir = RED.root.join target_config['local_dir']
				end
				cmd = "mv #{config.tmp_data_file} #{local_dir}/#{config.source_name}.tsv"
			elsif target_config['database']
				import_params = "--local #{RED.is_append ? '' : '--delete'} --fields-terminated-by='\\t' --fields-enclosed-by='\\\"' --lines-terminated-by='\\n'"
				cmd = "mysqlimport #{make_mysql_cmd_params(target_config)} #{config.tmp_data_file} #{import_params}"
			else
				Log.error! "ERROR: Export config of #{config.category} was not found" unless target_config
			end
			@ssh.local_command cmd
		end

		def connect_mysql(query_file, category, stage)
			target_config = @config['deploy'][category.to_s]
			Log.error! "ERROR: Export config of #{config.category} was not found" unless target_config

			target_config = target_config[stage] if stage
			Log.error! "ERROR: Export config of #{config.category} for stage #{stage} was not found" unless target_config

			cmd = "mysql #{make_mysql_cmd_params(target_config)} < #{query_file}"
			@ssh.local_command cmd
		end

		private
		def make_redshift_cmd
			ENV['PGPASSWORD'] = @config['password']
			return "psql -h #{@config['host']} -p #{REDSHIFT_PORT} -U #{@config['username']} -d #{@config['database']}"
		end

		def make_mysql_cmd_params(db_config)
			return "-h#{db_config['host']} -u#{db_config['username']} #{db_config['password'].empty? ? '' : '-p'+db_config['password']} #{db_config['database']}"
		end

	end

	DATABASE = DataBase.new
end


