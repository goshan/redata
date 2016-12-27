module Redata
	class DataBase
		REDSHIFT_PORT = 5439

		def initialize
			@config = YAML.load(ERB.new(File.read(RED.root.join 'config', 'database.yml')).result(binding))[RED.env]
			Log.error! "ERROR: Database of #{RED.env} was not declared in config/database.yml" unless @config

			@ssh = Ssh.new
		end

		def connect_with_file(file)
			cmd = make_redshift_cmd
			if @ssh.run_with_ssh?
				@ssh.upload_file file
				@ssh.run_command "export PGPASSWORD='#{ENV['PGPASSWORD']}';#{cmd} -f ~/tmp/#{file.basename}"
			else
				system "#{cmd} -f #{file}"
			end
		end

		def connect_with_query(query)
			cmd = make_redshift_cmd
			if @ssh.run_with_ssh?
				@ssh.run_command "export PGPASSWORD='#{ENV['PGPASSWORD']}';#{cmd} -c '#{query}'"
			else
				system "#{cmd} -c '#{query}'"
			end
		end

		def inject_to_mysql(config, platform)
			if @ssh.run_with_ssh?
				@ssh.upload_file config.tmp_data_file, config.name
				data_file = "~/tmp/#{config.name}"
			else
				data_file = config.tmp_data_file
			end

			is_append = RED.is_append && config.update_type == :append
			cmd = "mysqlimport #{make_mysql_cmd_config(config.category.to_s, platform)} #{data_file} --local #{is_append ? '' : '--delete'} --fields-terminated-by='\\t' --fields-enclosed-by='\\\"' --lines-terminated-by='\\n'"

			if @ssh.run_with_ssh?
				@ssh.run_command cmd
			else
				system "#{cmd}"
			end

		end

		def connect_mysql_with_file(query_file, category, platform)
			if @ssh.run_with_ssh?
				@ssh.upload_file query_file, query_file.basename
				data_file = "~/tmp/#{query_file.basename}"
			else
				data_file = query_file
			end

			cmd = "mysql #{make_mysql_cmd_config(category, platform)} < #{data_file}"

			if @ssh.run_with_ssh?
				@ssh.run_command cmd
			else
				system cmd
			end
		end

		private
		def make_redshift_cmd
			ENV['PGPASSWORD'] = @config['password']
			return "psql -h #{@config['host']} -p #{REDSHIFT_PORT} -U #{@config['username']} -d #{@config['database']}"
		end

		def make_mysql_cmd_config(category, platform)
			export_db_config = @config['export'][category]
			Log.error! "ERROR: Export config of #{category} was not found in config/database.yml" unless export_db_config
			if platform
				if export_db_config[platform]
					export_db_config = export_db_config[platform]
				else
					Log.warning "WARNING: Platform #{platform} was not declared in config/database.yml, ignore platform setting"
				end
			end

			return "-h#{export_db_config['host']} -u#{export_db_config['username']} #{export_db_config['password'].empty? ? '' : '-p'+export_db_config['password']} #{export_db_config['database']}"
		end

	end

	DATABASE = DataBase.new
end


