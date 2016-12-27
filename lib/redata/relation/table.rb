module Redata
	class Table < Relation
		def initialize(category, name, setting)
			super category, name, setting
			@type = :table
			@update_type = setting[:update] || :renewal
		end

		def source_name
			@category == :main ? @name : "#{@category}_#{@name}"
		end

		def query_file
			query_file = RED.root.join 'database', 'sources'
			query_file = query_file.join @dir if @dir
			query_file = query_file.join "#{@file}.sql"
			query_file
		end

		def tmp_script_file
			RED.root.join 'tmp', "queries", "red#{@type}_#{@category}_#{@name}.sql"
		end
	end
end
