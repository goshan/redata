# Redata

Help you to controll data process in redshift with easy query and command line


## Installation

Add this line to your application's Gemfile:

```ruby
gem 'redata'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install redata

## Usage

### Config

+ config `config/redata.yml` for general setting

```YAML
start_date: "2016-04-04"  # default data start date
timezone: "Asia/Tokyo"
s3:
  aws_access_key_id: {key_id}
  aws_secret_access_key: {key_secret}
  region: {s3_region}
  bucket:
	production: {bucket_name}
	development: {bucket_name}
ssh:  # this setting will be used in ssh mode when you access private database
  HostName: {gateway_host}
  IdentityFile: {~/.ssh/key.pem}
  User: {username}
slack_bot:  # this setting will be used for slack notice push
  token: {bot_token}
  channel: {slack_channel}
```

+ config `config/database.yml` for development and production environment in redshift database  
eg.

```YAML
development:
  host: localhost
  username: user
  password: ''
  database: dev
  export: # target platform db(mysql) which export data to
    app:  # platform name
      username: root
      password: ''
      host: localhost
      database: app
```

+ config `config/relations.rb` for data object in redshift and exporting process to mysql  
eg.

```RUBY
Redata::Task.schema.config do
  # Example of declaring a global table
  table 'table_name'
  # This declaration means
  #   query file: database/sources/table_name.sql
  #   redshift table: table_name
  #   update type: renewal, delete and re-create when update
  #   key used in command line: table_name
  
  # Example of declaring a global table with customizing options
  table 'new_table_name', :dir => 'dir', :file => 'query_file', :update => :append, :as => :alias
  # This declaration means
  #   query file: database/sources/dir/query_file.sql
  #   redshift table: new_table_name
  #   update type: append, only appending to existing table
  #   key used in command line: alias
  
  # view is same to table but the update type only has renewal mode
  table 'view_name'
  table 'new_view_name', :dir => 'dir', :file => 'query_file_oth', :as => :alias_oth
  
  # Example of declaring with category
  category :test_category do
    table 'test_table'
    # This declaration means
    #   query file: database/sources/test_category/test_table.sql
    #   redshift table: test_category_test_table
    #   update type: renewal
    #   key used in command line: test_category_test_table
    
    table 'test_table_oth', :dir => 'dir', :file => 'query_file_oth', :update => append, :as => :alias_oth
    # This declaration means
    #   query file: database/sources/dir/query_file_oth.sql
    #   redshift table: test_category_test_table
    #   update type: append
    #   key used in command line: test_category_alias_oth
    
    # view is same to table without appending update type
    view 'test_view'
    view 'test_view_oth', :dir => 'dir', :file => 'query_file_oth', :as => :alias_view_oth
    
    #Example of convertor declaration
    export 'test_export'
    # This declaration means
    #   convertor file: database/convertors/test_category/test_export.conv
    #   target mysql database name: test_category (Also see: export config in config/database.yml{:export})
    #   target mysql table: test_export
    #   update type: renewal, delete all records and insert new records
    #   key used in command line: test_category_test_export
    
    #Example of convertor declaration
    export 'test_export', :dir => 'dir', :file => 'conv_file', :update => 'append', :as => 'alias_export'
    # This declaration means
    #   convertor file: database/convertors/dir/conv_file.conv
    #   target mysql database name: test_category
    #   target mysql table: test_export
    #   update type: append, append insert new records without deleting
    #   key used in command line: test_category_alias_export
  end

end
```

### Query file

Query file was used for create table of view in redshift. It is almost like PostgreSQL file but with same new feature. And you have no need to write a create table/view query, the result after running query file will used to create a new table/view, for table, if you use append mode, the result will only be append-inserted to table.  
eg.

```SQL
-- query file in data/sources/...

#include 'sub_query_a' --> :a  -- include a sub query as object a from _sub_query_a.sql in same folder or database/shared/
#include 'sub_query_b' --> :b


select a.col1, a.col2, b.col1, b.col2, b.col3
from {a}  -- use object a included from sub query file '_sub_query_a.sql'
join {b} on b.col1 = a.col1
-- If in append mode and this table was setted appending update type, then start_time getting from command input such as `-start_time 2016-11-08` will be used here. When missing input this param, as default [2 days ago] will be used.
-- Or if not append mode, start_date will be used as default (Also see config/redata.yml).  set start_time when running command , if missing in command, default_start_date will be used 
where a.col1 >= [start_time]
-- current time in setted timezone will be used (About timezon, also see config/redata.yml)
and a.col1 <= [current_time]
-- some params getting from command input such as `-param_from_command param_value`
and a.col2 = [param_from_command]
-- x days before today, x will be a integer
and b.col3 >= [x days ago]
```

### Convertor config file

Convertor file was used to generate a select query to get data from redshift and unload to S3. But you have no need to wirte a unload query. If you are using append mode, only data 2 days ago will be select.   
eg.

```
source: redshift_source_table_or_view
columns:
	cm_id
	segment_type{'C' => 0, 'T' => 1, 'M1' => 2, 'M2' => 3, 'M3' => 4, 'F1' => 5, 'F2' => 6, 'F3' => 7}
	v
	e
	base_ai
	sample_num
	grp
```

> convertor config file in `data/convertors/...`  
> `source` means the source table in redshift  
> `columns` means the source columns in source table  

### Command

There are 3 executable file in bin/
- redata --> manage redshift table/view and export data to mysql
- adjust --> run some single sql query file in redshift or mysql
- notice --> push notice to slack etc.

#### redata

Usage: `redata [-options] [action] [object key] {platform}`
+ action
  - create   --> create a table/view or append data to table in redshift
  - delete   --> delete a table/view in redshift
  - checkout --> export data in table/view of redshift into S3
  - inject   --> import data into mysql table from S3
+ object key --> object will be create/delete/checkout/inject declared in `config/relation.rb`
+ platform   --> when injecting data into mysql, there may be several platform declared in `config/database.yml{:export}` for same database, here is setting which platform to use. *If the platform here could not be found in `database.yml` or have not set platform, the default export will be used.*
+ options
  - -dir --> project directory, both absolute path and realtive path will be okay. default is current directory.
  - -e   --> environment: `production`, `development`, etc.
  - -f   --> force mode, use `CADCASE` when removing view or table in redshift
  - -ssh --> use ssh accessing to private database with ssh config in `config/redata.yml`
  - -append_mode  --> use `append_mode`, the objects in relations.rb with appending update type will go to appending operation. 
    + delete will only delete objects with renewal update type
    + create will append-insert data after `-start_time`(set in command) or default `2 days ago` for appending update type, still create table/view for renewal type
    + checkout will only fetch data after `-start_time` or default `2 days ago` to upload to S3, renewal type will still be uploaded all data
    + inject will insert data to mysql without `--delete` option, renewal still delete all firstly
  - other options  --> some params will be used in query file when declared, such `start_time`

#### adjust

Use adjust when you just want to run a query file without declaring in `config/relations.rb`
Usage: `adjust [-options] [database] [query file] {platform}`
+ database   --> `redshift` or database declared in `config/database.yml{export}`
+ query file --> query file which will be run in `database/adjust/`, **without extends `.sql`**
+ platform   --> same to `redata`
+ options
  - -dir --> project directory, both absolute path and realtive path will be okay. default is current directory.
  - -e   --> environment: `production`, `development`, etc.
  - -ssh --> use ssh accessing to private database with ssh config in `config/redata.yml`
  - other options  --> some params will be used in query file when declared, such `start_time`

#### notice

Usage: `notice [-options] [action]`
+ action: currently, there is only `update` action which means send 'finish updating' message to slack
+ options
  - -e   --> environment: `production`, `development`, etc. **Only production could send notice**

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/goshan/redata.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

