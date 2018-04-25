module Redata
  class Relation
    attr_accessor :category, :name, :key, :file, :dir, :type
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

    def source_name
      postfix = RED.identify ? "_#{RED.identify}" : ""
      @category == :main ? "#{@name}#{postfix}" : "#{@category}_#{@name}#{postfix}"
    end

    def query_file
      query_file = RED.root.join 'query', 'sources'
      query_file = query_file.join @dir if @dir
      query_file = query_file.join "#{@file}.red.sql"
      query_file
    end

    def tmp_file_dir
      RED.root.join 'tmp', "#{@category}_#{@name}"
    end

    def tmp_exec_file
      self.tmp_file_dir.join "exec.sql"
    end

    def tmp_mkdir
      Dir.mkdir self.tmp_file_dir unless self.tmp_file_dir.exist?
    end

    def tmp_rmdir
      FileUtils.rm_r self.tmp_file_dir if !RED.keep_tmp? && self.tmp_file_dir.exist?
    end
  end
end
