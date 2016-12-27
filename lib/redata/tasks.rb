module Redata
	class Task
		@@schema = Schema.new

		def self.schema
			@@schema
		end

		def self.create_datasource(key)
			self.parse_key(key, [:table, :view]).each do |config|
				if RED.is_append && config.update_type == :append
					start_time = RED.locals[:start_time] || RED.default_append_date
					Parser.gen_redshift_query config, start_time
					Log.action "QUERY: Append data after #{start_time} into [#{config.source_name}]"
					DATABASE.connect_with_file config.tmp_script_file
				else
					Parser.gen_redshift_query config
					Log.action "QUERY: Create #{config.type} [#{config.source_name}]"
					DATABASE.connect_with_file config.tmp_script_file
				end
			end
		end

		def self.delete_datasource(key)
			self.parse_key(key, [:table, :view]).reverse.each do |config|
				unless RED.is_append && config.update_type == :append
					Log.action "QUERY: Drop #{config.type} [#{config.source_name}]"
					Log.warning "WARNING: CASCADE mode will also drop other sources that depend on this #{config.type}" if RED.is_forced
					DATABASE.connect_with_query "DROP #{config.type} #{config.source_name} #{RED.is_forced ? 'CASCADE' : 'RESTRICT'}"
				end
			end
		end

		def self.checkout_datasource(key)
			self.parse_key(key, [:export]).each do |config|
				if RED.is_append && config.update_type == :append
					start_time = RED.locals[:start_time] || RED.default_append_date
					Parser.gen_export_query config, start_time
					Log.action "QUERY: Checkout data after #{start_time} to bucket [#{config.bucket_file}]"
				else
					Parser.gen_export_query config
					Log.action "QUERY: Checkout data to bucket [#{config.bucket_file}]"
				end
				DATABASE.connect_with_file config.tmp_script_file
				bucket = S3Bucket.new
				bucket.move "#{config.bucket_file}000", config.bucket_file
			end
		end

		def self.inject(key, platform=nil)
			self.parse_key(key, [:export]).each do |config|
				Log.action "BUCKET: Make [#{config.bucket_file}] public"
				bucket = S3Bucket.new
				bucket.make_public config.bucket_file, true

				Log.action "DOWNLOAD: Downlaod [#{config.bucket_file}] from bucket"
				system "wget #{RED.s3['host']}/#{config.bucket_file} -O #{config.tmp_data_file} --quiet"

				Log.action "BUCKET: Make [#{config.bucket_file}] private"
				bucket.make_public config.bucket_file, false

				Log.action "QUERY: Inject data to [#{config.name}] of #{config.category}"
				DATABASE.inject_to_mysql config, platform
			end
		end


		private
		def self.parse_key(key, types)
			key = key.to_sym if key
			configs = []

			configs = @@schema.category_configs(key, types)
			if configs.empty?
				config = @@schema.config_with key if key
				Log.error! "ERROR: Data source relation #{key} was not defined in config/relations.rb" unless config
				configs.push config
			end
			configs
		end

	end
end

