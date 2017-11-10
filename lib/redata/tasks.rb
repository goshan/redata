module Redata
	class Task
		@@schema = Schema.new

		def self.schema
			@@schema
		end

		def self.create_datasource(key)
			self.parse_key(key, [:table, :view]).each do |config|
				config.tmp_mkdir
				Parser.gen_create_query config
				if RED.is_append
					Log.action "APPEND<#{config.type}>: data(#{RED.start_time} ~ #{RED.end_time}) into [#{config.source_name}]"
				else
					Log.action "CREATE<#{config.type}>: [#{config.source_name}]"
				end
				DATABASE.connect_redshift config
				config.tmp_rmdir
			end
		end

		def self.delete_datasource(key)
			self.parse_key(key, [:table, :view]).reverse.each do |config|
				config.tmp_mkdir
				Parser.gen_delete_query config
				Log.action "DROP<#{config.type}>: [#{config.source_name}]"
				Log.warning "WARNING: CASCADE mode will also drop other views that depend on this" if RED.is_forced
				DATABASE.connect_redshift config
				config.tmp_rmdir
			end
		end

		def self.checkout_datasource(key)
			self.parse_key(key, [:view]).each do |config|
				config.tmp_mkdir
				Parser.gen_checkout_query config
				Log.action "CHECKOUT<#{config.category}>: to bucket [#{config.bucket_file}]"
				DATABASE.connect_redshift config

				bucket = S3Bucket.new
				#bucket.move "#{config.bucket_file}000", config.bucket_file
				config.tmp_rmdir
			end
		end

		def self.deploy_datasource(key, stage)
			self.parse_key(key, [:view]).each do |config|
				config.tmp_mkdir
				bucket = S3Bucket.new
				bucket.make_public "#{config.bucket_file}000", true

				Log.action "DOWNLOAD<bucket>: from [#{config.bucket_file}]"
				system "wget #{RED.s3['host']}/#{config.bucket_file}000 -O #{config.tmp_data_file} --quiet"

				bucket.make_public "#{config.bucket_file}000", false

				Log.action "INJECT<#{config.category}>: with [#{config.name}] #{stage ? 'for stage '+stage : ''}"
				DATABASE.inject_data config, stage
				config.tmp_rmdir
			end
		end


		private
		def self.parse_key(key, types)
			key = key.to_sym if key
			configs = []

			configs = @@schema.category_configs(key, types)
			if configs.empty?
				config = @@schema.config_with key if key
				Log.error! "ERROR: Data source relation #{key} was not defined" unless config
				configs.push config
			end
			configs
		end

	end
end

