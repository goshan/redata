module Redata
	class Export < Relation
		def initialize(category, name, setting)
			super category, name, setting
			@type = :export
			@update_type = setting[:update] || :renewal
		end

		def conv_file
			conv_file = RED.root.join 'database', 'convertors'
			conv_file = conv_file.join @dir if @dir
			conv_file = conv_file.join "#{@file}.conv"
			conv_file
		end

		def tmp_script_file
			RED.root.join 'tmp', "queries", "red#{@type}_#{@category}_#{@name}.sql"
		end

		def tmp_data_file
			RED.root.join 'tmp', "data", "#{@name}.tsv"
		end

		def bucket_file
			bucket_dir = RED.default_append_date
			bucket_dir = RED.locals[:start_time] if RED.is_append && @update_type == :append && RED.locals[:start_time]
			"#{bucket_dir}/#{@category}/#{@name}.tsv"
		end
	end
end
