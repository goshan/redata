module Redata
	class Parser
		INCLUDE_REGEX = /#include (.*)-->(.*)/
		REF_REGEX = /{([^{}]+)}/
		REF_SPLIT_REGEX = /\s*{[^{}]+}\s*/
		START_TIME_REGEX = /\[start_time\]/
		TIME_OFFSET_REGEX = /\[(\d+) days ago\]/
		CURRENT_TIME_REGEX = /\[current_time\]/
		LOCALS_REGEX = /\[([^\[\]]+)\]/

		CONV_TABLE_REGEX = /source:(.*)/
		CONV_COLUMN_REGEX = /columns:\s*/
		CONV_SWITCHDEF_REGEX = /(.+){(.*)}/
		CONV_SWITCH_REGEX = /([^,]+)=>([^,]+)/
		CONV_TIMESTAMP_REGEX = /\[time_stamp\]/

		def self.gen_redshift_query(config, start_time=nil)
			Log.error! "ERROR: Query file '#{config.query_file.relative_path_from RED.root}' not exists" unless config.query_file.exist?

			File.open config.tmp_script_file, 'w' do |f|
				if start_time && config.type == :table
					f.puts "INSERT INTO #{config.source_name} ("
				else
					start_time = RED.default_start_date
					f.puts "CREATE #{config.type} #{config.source_name} AS ("
				end
				self.parse_redshift_file config.query_file, f, start_time
				f.puts ");"
			end
		end

		def self.gen_export_query(config, start_time=nil)
			Log.error! "ERROR: Convertor config '#{config.conv_file.relative_path_from RED.root}' not exists" unless config.conv_file.exist?

			File.open config.tmp_script_file, 'w' do |f|
				f.puts "UNLOAD ('"
				f.puts self.parse_convertor_file config.conv_file
				f.puts "where date >= \\'#{start_time}\\'" if start_time
				f.puts "') to 's3://#{RED.s3['bucket']}/#{config.bucket_file}'"
				f.puts "CREDENTIALS 'aws_access_key_id=#{RED.s3['aws_access_key_id']};aws_secret_access_key=#{RED.s3['aws_secret_access_key']}'"
				f.puts "ESCAPE ALLOWOVERWRITE PARALLEL OFF DELIMITER AS '\\t';"
			end
		end

		def self.gen_adjust_file(query_file, tmp_script_file)
			Log.error! "ERROR: Query file '#{query_file.relative_path_from RED.root}' not exists" unless query_file.exist?

			File.open tmp_script_file, 'w' do |f|
				self.parse_redshift_file query_file, f, RED.default_start_date
			end
		end


		private
		def self.parse_redshift_file(in_file, out, start_time)
			links = {}
			File.open(in_file).each.with_index do |line, index|
				if line =~ INCLUDE_REGEX
					# parse include syntax
					res = line.scan(INCLUDE_REGEX).first
					sub = res[0].gsub /[\s|\'|\"]+/, ''
					link = res[1].gsub /[\s|:]+/, ''
					Log.error! "QUERY ERROR: #{in_file.relative_path_from RED.root}:#{index+1}: include query is missing file or alias" if sub.empty? || link.empty?
					
					sub_file = in_file.parent.join "_#{sub}.sql"
					sub_file = RED.root.join 'database', 'shared', "_#{sub}.sql" unless sub_file.exist?
					Log.error! "QUERY ERROR: #{in_file.relative_path_from RED.root}:#{index+1}: included file _#{sub}.sql could not be found in ./ or {root}/database/shared/" unless sub_file.exist?

					Log.error! "QUERY ERROR: #{in_file.relative_path_from RED.root}:#{index+1}: alias #{link} was declared multiple times" if links[link]

					links[link] = sub_file
				elsif line =~ REF_REGEX
					# parse {ref} syntax
					res = line.scan REF_REGEX
					refs = res.map{|r| r.first.gsub /\s+/, ''}
					origins = line.split REF_SPLIT_REGEX

					out.puts origins[0].gsub(';', '')
					refs.each_with_index do |ref, i|
						Log.error! "QUERY ERROR: #{in_file}:#{index+1}:\nsub query #{ref} not found." unless links[ref]
						out.puts "("
						self.parse_redshift_file links[ref], out, start_time
						out.puts ") as #{ref}"
						out.puts origins[i+1].gsub(';', '') if origins[i+1]
					end
				elsif line =~ START_TIME_REGEX
					# parse [start_time] syntax
					out.puts line.gsub(START_TIME_REGEX, "'#{start_time}'").gsub(';', '')
				elsif line =~ TIME_OFFSET_REGEX
					# parse [3 days ago]
					res = line.scan(TIME_OFFSET_REGEX).each do |res|
						line = line.gsub "[#{res[0]} days ago]", "#{RED.date_days_ago(res[0].to_i)}"
					end
					out.puts line
				elsif line =~ CURRENT_TIME_REGEX
					line = line.gsub "[current_time]", "#{RED.current_time}"
					out.puts line
				elsif line =~ LOCALS_REGEX
					# parse [locals] syntax
					line.scan(LOCALS_REGEX).each do |res|
						key = res.first
						Log.error! "QUERY ERROR: Local params #{key} was missing." unless RED.locals[key.to_sym]
						line = line.gsub "[#{key}]", "'#{RED.locals[key.to_sym]}'"
					end
					out.puts line.gsub ';', ''
				else
					# other, print absolutely
					out.puts line.gsub ';', ''
				end
			end
		end

		def self.parse_convertor_file(in_file)
			is_parsing_column = false
			columns = []
			source = ""
			File.open(in_file).each.with_index do |line, index|
				if line =~ CONV_TABLE_REGEX
					# parse table declare
					res = line.scan(CONV_TABLE_REGEX).first
					source = res[0].gsub /\s+/, ''
					is_parsing_column = false
				elsif line =~ CONV_COLUMN_REGEX
					is_parsing_column = true
				elsif is_parsing_column
					line.gsub! /\s+/, ''
					if line =~ CONV_SWITCHDEF_REGEX
						res = line.scan(CONV_SWITCHDEF_REGEX).first
						res[1].gsub!("'", "\\\\'")
						switches = res[1].scan CONV_SWITCH_REGEX
						switches.map! do |m|
							"when #{m[0]} then #{m[1]}"
						end
						columns.push "case #{res[0]} #{switches.join ' '} end as #{res[0]}"
					elsif line =~ CONV_TIMESTAMP_REGEX
						columns.push "\\'#{(Time.now+9*3600).strftime("%Y-%m-%d %H:%M:%S")}\\'"
						columns.push "\\'#{(Time.now+9*3600).strftime("%Y-%m-%d %H:%M:%S")}\\'"
					else
						columns.push line.gsub("'", "\\\\'").gsub('NULL', "\\\\'NULL\\\\'") unless line.empty?
					end
				end
			end
			"select #{columns.join ','} from #{source}"
		end

	end
end
