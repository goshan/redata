Redata::Task.schema.config do
  # Example of declaring a global table
  table 'source_query_example'
  # This declaration means
  #   query file: query/sources/source_query_example.red.sql
  #   redshift table: source_query_example
  #   key used in command line: source_query_example

  # Example of declaring a global table with customizing options
  # table 'new_table_name', :dir => 'dir', :file => 'query_file', :as => :alias
  # This declaration means
  #   query file: query/sources/dir/query_file.red.sql
  #   redshift table: new_table_name
  #   key used in command line: alias

  # view is same to table but will still be created in append_mode
  # view 'view_name'
  # view 'new_view_name', :dir => 'dir', :file => 'query_file_oth', :as => :alias_oth

  # Example of declaring with category
  # category :test_category do
  #   table 'test_table'
  #   This declaration means
  #     query file: query/sources/test_category/test_table.red.sql
  #     redshift table: test_category_test_table
  #     key used in command line: test_category_test_table

  #   table 'test_table_oth', :dir => 'dir', :file => 'query_file_oth', :as => :alias_oth
  #   This declaration means
  #     query file: query/sources/dir/query_file_oth.red.sql
  #     redshift table: test_category_test_table
  #     key used in command line: test_category_alias_oth

  #   view is same to table without appending update type
  #   view 'test_view'
  #   view 'test_view_oth', :dir => 'dir', :file => 'query_file_oth', :as => :alias_view_oth
  # end

end
