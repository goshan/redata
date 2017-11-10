module Redata
	class View < Relation
		def initialize(category, name, setting)
			super category, name, setting
			@type = :view
		end

		def bucket_file
			"#{RED.today}/#{@category}/#{@name}.tsv000"
		end

		def tmp_data_file
			self.tmp_file_dir.join "#{@name}.tsv"
		end
	end
end
