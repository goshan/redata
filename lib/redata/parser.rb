module Redata
	class Parser
		COMMENT_REGEX = /-{2}.*/
		LOAD_REGEX = /#load (.*)->(.*)/
		IF_REGEX = /\[\s*if ([^\s]*) is ([^\]]*)\]/
		IFNUL_REGEX = /\[\s*if ([^\s]*) is null\s*\]/
		ENDIF_REGEX = /\[\s*endif\s*\]/
		START_TIME_REGEX = /\[start_time\]/
		END_TIME_REGEX = /\[end_time\]/
		TIME_OFFSET_REGEX = /\[(\d+) days ago\]/
		CURRENT_TIME_REGEX = /\[current_time\]/
		LOCALS_REGEX = /\[([^\[\]<>\s]+)\]/
		LOCALS_LIST_REGEX = /\[<([^\[\]<>\s]+)>\]/

		def self.gen_create_query(config)
			if config.type == :table
				self.gen_table_query config
			elsif config.type == :view
				self.gen_view_query config
			end
		end

		def self.gen_delete_query(config)
			File.open config.tmp_exec_file, 'w' do |f|
				f.puts "DROP #{config.type} #{config.source_name} #{RED.is_forced ? 'CASCADE' : 'RESTRICT'};"
			end
		end

		def self.gen_checkout_query(config)
			Log.error! "ERROR: Only could checkout data from view" unless config.type == :view

			File.open config.tmp_exec_file, 'w' do |f|
				f.puts "UNLOAD ('"
				f.puts "SELECT * FROM #{config.source_name}"
				f.puts "') to 's3://#{RED.s3['bucket']}/#{config.bucket_file}'"
				f.puts "CREDENTIALS 'aws_access_key_id=#{RED.s3['aws_access_key_id']};aws_secret_access_key=#{RED.s3['aws_secret_access_key']}'"
				f.puts "ESCAPE ALLOWOVERWRITE PARALLEL OFF DELIMITER AS '\\t';"
			end
		end

		def self.gen_adjust_query(config)
			self.parse config.query_file, config.tmp_exec_file, ''
		end


		private
		def self.gen_table_query(config)
			Log.error! "ERROR: Relation error" unless config.type == :table

			tmp_file = config.tmp_file_dir.join "#{config.source_name}.resql"
			temp_tables = self.parse config.query_file, tmp_file

			File.open config.tmp_exec_file, 'w' do |f|
				# print temp tables
				temp_tables.each do |name|
					f.puts "CREATE TEMP TABLE #{name} AS ("
					f.puts File.read(config.tmp_file_dir.join "#{name}.resql")
					f.puts ");"
				end

				# print create or insert query
				if RED.is_append
					f.puts "INSERT INTO #{config.source_name} ("
				elsif
					f.puts "CREATE #{config.type} #{config.source_name} AS ("
				end
				f.puts File.read tmp_file
				f.puts ");"
			end
		end

		def self.gen_view_query(config)
			Log.error! "ERROR: Relation error" unless config.type == :view

			tmp_file = config.tmp_file_dir.join "#{config.source_name}.resql"
			temp_tables = self.parse config.query_file, tmp_file

			File.open config.tmp_exec_file, 'w' do |f|
				f.puts "CREATE #{config.type} #{config.source_name} AS ("
				temp_tables.each_with_index do |name, index|
					f.puts "#{index == 0 ? 'WITH' : ','} #{name} AS ("
					f.puts File.read(config.tmp_file_dir.join "#{name}.resql")
					f.puts ")"
				end

				# print create query
				main = File.read tmp_file
				unless temp_tables.empty?
					main.gsub! 'WITH', ','
					main.gsub! 'with', ','
				end
				f.puts main
				f.puts ");"
			end
		end

		def self.parse(in_file, out_file, skip_char=';')
			Log.error! "ERROR: Query file '#{in_file.relative_path_from RED.root}' not exists" unless in_file.exist?

			temp_tables = []
			parse_enable = true
			File.open out_file, 'w' do |out|
				File.open(in_file).each do |line|
					# remove comments
					line.gsub!(COMMENT_REGEX, '')
					# remove skip_char
					line.gsub!(skip_char, '')
					# remove empty line
					next if !line || line.empty? || line =~ /^\s*$/

					# check if else condition
					if line =~ IFNUL_REGEX
						res = line.scan(IFNUL_REGEX).first
						var = res[0]
						parse_enable = RED.locals[var.to_sym].nil?
						next
					elsif line =~ IF_REGEX
						res = line.scan(IF_REGEX).first
						var = res[0]
						val = res[1].gsub /[\s|\'|\"]+/, ''
						parse_enable = (RED.locals[var.to_sym] == val)
						next
					elsif line =~ ENDIF_REGEX
						parse_enable = true
						next
					end
					next unless parse_enable

					# compile sub file
					if line =~ LOAD_REGEX
						# parse load syntax
						res = line.scan(LOAD_REGEX).first
						sub = res[0].gsub /[\s|\'|\"]+/, ''
						name = res[1].gsub /[\s|:]+/, ''
						Log.error! "QUERY ERROR: syntax error for load query: #{line}" if sub.empty? || name.empty?
						
						sub_file = in_file.parent.join "_#{sub}.red.sql"
						sub_file = RED.root.join 'red_query', 'shared', "_#{sub}.rea.sql" unless sub_file.exist?
						sub_temp_tables = self.parse sub_file, out_file.dirname.join("#{name}.resql")
						sub_temp_tables.each do |n|
							temp_tables.push n unless temp_tables.include? n
						end
						temp_tables.push name unless temp_tables.include? name
						next  # load query line can not contain other content
					end

					# parse [start_time] syntax
					line.gsub! START_TIME_REGEX, "'#{RED.start_time}'" 
					# parse [end_time] syntax
					line.gsub! END_TIME_REGEX, "'#{RED.end_time}'"
					# parse [current_time] syntax
					line.gsub! CURRENT_TIME_REGEX, "'#{RED.current_time}'"

					# parse [3 days ago]
					res = line.scan(TIME_OFFSET_REGEX).each do |res|
						line.gsub! "[#{res[0]} days ago]", "'#{RED.date_days_ago(res[0].to_i)}'"
					end
					# parse [locals] syntax
					line.scan(LOCALS_REGEX).each do |res|
						key = res.first
						Log.error! "QUERY ERROR: Local params #{key} was missing." unless RED.locals[key.to_sym]
						line.gsub! "[#{key}]", "'#{RED.locals[key.to_sym]}'"
					end
					# parse [<local_list>] syntax
					line.scan(LOCALS_LIST_REGEX).each do |res|
						key = res.first
						Log.error! "QUERY ERROR: Local params #{key} was missing." unless RED.locals[key.to_sym]
						line = line.gsub "[<#{key}>]", "(#{RED.locals[key.to_sym].split(',').map{|e| "'#{e}'"}.join(',')})"
					end

					out.puts line.gsub skip_char, ''
				end
			end
			temp_tables
		end

	end
end
