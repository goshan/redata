module Redata
	class Config
		attr_accessor :root, :env, :is_forced, :is_ssh, :is_append, :params, :locals

		def initialize(argv=nil)
			# params
			@argv = parse_params argv
			if !@argv[:dir]
				@root = Pathname.new(Dir.pwd)
			elsif Pathname.new(@argv[:dir]).absolute?
				@root = Pathname.new(@argv[:dir])
			else
				@root = Pathname.new(Dir.pwd).join @argv[:dir]
			end
			@env = @argv[:env] || 'development'
			@is_forced = @argv[:force]
			@is_ssh = @argv[:ssh]
			@is_append = @argv[:append_mode]
			@locals = @argv[:locals]
			@params = @argv[:params]

			# config file
			@config = YAML.load(ERB.new(File.read(@root.join 'config', 'redata.yml')).result(binding))
			@s3_config = @config['s3']
			@s3_config['bucket'] += "-dev" unless @env == 'production'
			@s3_config['region'] = 'ap-northeast-1'
			@s3_config['host'] = "https://s3-#{@s3_config['region']}.amazonaws.com/#{@s3_config['bucket']}"
			Aws.config.update({
				region: @s3_config['region'],
				credentials: Aws::Credentials.new(@s3_config['aws_access_key_id'], @s3_config['aws_secret_access_key'])
			})
			@tz_local = Timezone[@config['timezone']]
			@slack_token = @config['slack_bot']
			@keep_tmp = @config['keep_tmp']
		end

		def development?
			@env == 'development'
		end

		def production?
			@env == 'production'
		end

		def keep_tmp?
			@keep_tmp
		end

		def log_file
			@root.join 'log', "#{@env}_redata.log"
		end

		def start_time
			return @locals[:start_time] if @locals[:start_time]
			if @is_append
				@tz_local.utc_to_local(Time.now.utc-@config['append_interval']['start_time']*24*3600).strftime('%Y-%m-%d')
			else
				@config['create_interval']['start_time']
			end
		end

		def end_time
			return @locals[:end_time] if @locals[:end_time]
			if @is_append
				@tz_local.utc_to_local(Time.now.utc-@config['append_interval']['end_time']*24*3600).strftime('%Y-%m-%d')
			else
				@tz_local.utc_to_local(Time.now.utc-@config['create_interval']['end_time']*24*3600).strftime('%Y-%m-%d')
			end
		end

		def ssh
			@config['ssh']
		end

		def s3
			@s3_config
		end

		def slack
			@slack_token
		end

		def current_time
			@tz_local.utc_to_local(Time.now.utc).strftime('%Y-%m-%d %H:%M:%S')
		end

		def date_days_ago(days)
			@tz_local.utc_to_local(Time.now.utc-days*24*3600).strftime('%Y-%m-%d')
		end

		private
		def parse_params(argv)
			new_argv = {:params => [], :locals => {}}
			return new_argv unless argv
			i = 0
			while i < argv.count
				case argv[i]
				when '-e'
					i += 1
					new_argv[:env] = argv[i]
				when '-f'
					new_argv[:force] = true
				when '-ssh'
					new_argv[:ssh] = true
				when '-append'
					new_argv[:append_mode] = true
				else
					if argv[i] =~ /\A-(.+)/
						key = argv[i].match(/\A-(.+)/)[1]
						i += 1
						new_argv[:locals][key.to_sym] = argv[i]
					else
						new_argv[:params].push argv[i]
					end
				end
				i += 1
			end
			new_argv
		end
	end

	RED = Config.new ARGV
end

