require 'rails/generators/base'

module Redata
  class ConfigGenerator < Rails::Generators::Base
    source_root File.expand_path('../../templates', __FILE__)
    desc 'Redata Config'

    def config_steps
      copy_file 'source_query_example.red.sql', 'query/sources/sources_query_example.red.sql'
      copy_file 'adjust_query_example.red.sql', 'query/adjust/adjust_query_example.red.sql'
      copy_file 'redata.yml', 'config/redata.yml'
      copy_file 'red_access.yml', 'config/red_access.yml'
      copy_file 'relations.rb', 'config/relations.rb'
    end
  end
end
