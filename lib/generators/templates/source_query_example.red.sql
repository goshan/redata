-- query file in data/sources/*.red.sql

#load 'sub_query_a' --> :a  -- include a sub query as object a from _sub_query_a.red.sql in same folder
#load 'sub_query_b' --> :b


-- use can use if logic to control whether run part of a query
-- 'endif' could stop one or many continuous if logic above. (use if which is from second just like 'else if')
-- TIPS: we have not supported 'else if', 'else' syntax and nested if logic
[if var is 'value1']
SELECT a.col1, a.col2, b.col1, b.col2, b.col3
[if var is 'value1']
SELECT a.col3, b.col4
[endif]
FROM {a}  -- use object a included from sub query file '_sub_query_a.sql'
JOIN {b} ON b.col1 = a.col1
-- For [start_time] and [end_time], there are 3 options.
-- use command params when set
-- in append mode, use [append_interval][start_time] or [append_interval][end_time] (See config/redata.yml).
-- in create mode, use [create_interval][start_time] or [create_interval][end_time] (See config/redata.yml).
WHERE a.col1 >= [start_time]
AND a.col1 < [end_time]
-- some params getting from command input such as `-param_from_command param_value`
AND a.col2 = [param_from_command]
-- current time in setted timezone will be used (About timezon, also see config/redata.yml)
AND b.col2 <= [current_time]
-- x days before today, x will be a integer
AND b.col3 >= [x days ago]
