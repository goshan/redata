module Redata
	class Relation
		attr_accessor :category, :name, :key, :file, :dir, :type, :update_type
		def initialize(category, name, setting)
			@category = category
			@name = name
			@key = setting[:as] || @name.to_sym
			@file = setting[:file] || @name
			@dir = setting[:dir] || (@category == :main ? nil : @category.to_s)
		end

		def global_key
			@category == :main ? @key : "#{@category}_#{@key}".to_sym
		end

	end
end
