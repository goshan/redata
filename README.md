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
create_interval:  # default date for create mode
  start_time: "2016-04-04"
  end_time: 2  # days ago
append_interval:  # date fetching interval for append mode
  start: 3  # days ago
  end: 2  # days ago
timezone: "Asia/Tokyo"
keep_tmp: true    # or false. whether keep temp query file in ./tmp after finished query
s3:
  bucket: bucket_name
  aws_access_key_id: key_id
  aws_secret_access_key: key_secret
ssh:  # this setting will be used in ssh mode when you access private database
  HostName: gateway_host
  IdentityFile: ~/.ssh/key.pem
  User: username
slack_bot:  # this setting will be used for slack notice push
  token: bot_token
  channel: slack_channel
```

+ config `config/red_access.yml` for development and production environment in redshift database  
eg.

```YAML
development:
  host: localhost
  username: user
  password: ''
  database: dev
  deploy: # target platform db(mysql) which export data to
    app:  # category name, using database
	  pro:  # stage name(you can still declare under category absolutely)
        username: root
        password: ''
        host: localhost
        database: app
    file:  # another category, using local file
	  local_dir: '~/data'
```

+ config `config/relations.rb` for data object in redshift and exporting process to mysql  
eg.

```RUBY
Redata::Task.schema.config do
  # Example of declaring a global table
  table 'table_name'
  # This declaration means
  #   query file: red_query/sources/table_name.red.sql
  #   redshift table: table_name
  #   key used in command line: table_name

  # Example of declaring a global table with customizing options
  table 'new_table_name', :dir => 'dir', :file => 'query_file', :as => :alias
  # This declaration means
  #   query file: red_query/sources/dir/query_file.red.sql
  #   redshift table: new_table_name
  #   key used in command line: alias

  # view is same to table but will still be created in append_mode
  view 'view_name'
  view 'new_view_name', :dir => 'dir', :file => 'query_file_oth', :as => :alias_oth

  # Example of declaring with category
  category :test_category do
    table 'test_table'
    # This declaration means
    #   query file: red_query/sources/test_category/test_table.red.sql
    #   redshift table: test_category_test_table
    #   key used in command line: test_category_test_table

    table 'test_table_oth', :dir => 'dir', :file => 'query_file_oth', :as => :alias_oth
    # This declaration means
    #   query file: red_query/sources/dir/query_file_oth.red.sql
    #   redshift table: test_category_test_table
    #   key used in command line: test_category_alias_oth

    # view is same to table without appending update type
    view 'test_view'
    view 'test_view_oth', :dir => 'dir', :file => 'query_file_oth', :as => :alias_view_oth
  end

end
```

### Query file

Query file was used for create table or view in redshift. It is almost like PostgreSQL file but with some new feature. And you have no need to write a create table/view query, the result after running query file will used to create a new table/view. For table, if you use append mode, the result will only be append-inserted to table.  
eg.

```SQL
-- query file in data/sources/*.red.sql

#load 'sub_query_a' --> :a  -- include a sub query as object a from _sub_query_a.red.sql in same folder
#load 'sub_query_b' --> :b


-- use can use if logic to control whether run part of a query
-- 'endif' could stop one or many continuous if logic above. (use if which is from second just like 'else if')
-- TIPS: we have not supported 'else if', 'else' syntax and nested if logic
[if var is 'value1']
select a.col1, a.col2, b.col1, b.col2, b.col3
[if var is 'value1']
select a.col3, b.col4
[endif]
from {a}  -- use object a included from sub query file '_sub_query_a.sql'
join {b} on b.col1 = a.col1
-- For [start_time] and [end_time], there are 3 options.
-- use command params when set
-- in append mode, use [append_interval][start_time] or [append_interval][end_time] (See config/redata.yml).
-- in create mode, use [create_interval][start_time] or [create_interval][end_time] (See config/redata.yml).
where a.col1 >= [start_time]
and a.col1 < [end_time]
-- some params getting from command input such as `-param_from_command param_value`
and a.col2 = [param_from_command]
-- current time in setted timezone will be used (About timezon, also see config/redata.yml)
and b.col2 <= [current_time]
-- x days before today, x will be a integer
and b.col3 >= [x days ago]
```


### Command

There are 3 executable file in bin/
- redata --> manage redshift table/view and export data to mysql
- adjust --> run some single sql query file in redshift or mysql
- notice --> push notice to slack etc.

#### redata

Usage: `redata [-options] [action] [object key] {stage}`
+ action
  - create   --> create a table/view or append data to table in redshift
  - delete   --> delete a table/view in redshift
  - checkout --> export data in table/view of redshift into S3
  - deploy --> deploy data from S3 to local db or file
+ object key --> object declared in `config/relation.rb` will be create/delete/checkout/deploy
+ stage --> when injecting data into mysql, there may be several stage declared in `config/red_access.yml{:deploy}` for same database, this could choose which stage to use.
+ options
  - -dir --> project directory, both absolute path and realtive path will be okay. default is current directory.
  - -e   --> environment: `production`, `development`, etc.
  - -f   --> force mode, use `CADCASE` when removing view or table in redshift
  - -ssh --> use ssh accessing to private database with ssh config in `config/redata.yml`
  - -append  --> use `append_mode`, append new data into existing table for redshift or inject into local db without deleting. view has no append mode.
  - other options  --> some params will be used in query file when declared, such `start_time`

#### adjust

Use adjust when you just want to run a query file without declaring in `config/relations.rb`  
Usage: `adjust [-options] [database] [query file] {platform}`
+ database   --> `redshift` or database declared in `config/red_access.yml{:deploy}`
+ query file --> query file which will be run in `red_query/adjust/`, **without extends `.red.sql`**
+ platform   --> same to `redata`
+ options
  - -dir --> project directory, both absolute path and realtive path will be okay. default is current directory.
  - -e   --> environment: `production`, `development`, etc.
  - -ssh --> use ssh accessing to private database with ssh config in `config/redata.yml`
  - other options  --> some params will be used in query file when declared, such `start_time`

#### notice

Usage: `notice [-options] [action]`
+ action
  - log      --> send a message to slack with a log file
  - mention  --> send a message to slack with mention someone

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/goshan/redata.


## License

Copyright 2013, Han Qiu(goshan), All rights reserved.

MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

