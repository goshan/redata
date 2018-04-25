module Redata
  class Table < Relation
    def initialize(category, name, setting)
      super category, name, setting
      @type = :table
    end
  end
end
