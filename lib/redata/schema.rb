module Redata
  class Schema
    def initialize
      @category = :main
      @order = []
      @index = {}
    end

    def config(&block)
      self.instance_eval &block
    end

    def category(prefix, &block)
      @category = prefix
      self.instance_eval &block
      @category = :main
    end

    def view(view, setting={})
      register view, :view, setting
    end

    def table(table, setting={})
      register table, :table, setting
    end

    def export(target, setting={})
      register target, :export, setting
    end

    def insert(target, setting={})
      register target, :insert, setting
    end

    def config_with(key)
      config = @index[key]
      return nil unless config
      config
    end

    def category_configs(category, types=[])
      res = []
      @order.each do |global_key|
        config = @index[global_key]
        res.push config if (!category || config.category == category) && (types.empty? || types.include?(config.type))
      end
      res
    end

    private
    def register(name, type, setting={})
      cla = Redata.const_get type.capitalize
      relation = cla.new @category, name, setting

      if @index[relation.global_key]
        Log.log "in #{caller.first}"
        Log.error! "ERROR: Duplicated view alias '#{global_key}'" 
      end

      @index[relation.global_key] = relation
      @order.push relation.global_key
    end
  end
end
