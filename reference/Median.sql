-- Medians are not "group by" aggregations
-- As a result, the output can be very confusing if you do not write it correctly
-- Additionally, if you have a "group by" on the statement, it will ask that you 
-- group by with the median too.
-- It appears to be best to run the median separately, then join with the rest
-- of the data.

-- Simple median
select distinct variable
  , cast(percentile_cont(0.5) within group (order by column_id) over(
      partition by variable
    ) as decimal(10,2)) as mdn
from dupcheck_example
;

-- Merging with average
select coalesce(a.variable, b.variable) as variable, avg_column_id, mdn_column_id
from (
  select variable, avg(column_id) as avg_column_id
  from dupcheck_example
  group by variable
) a
full join (
  select distinct variable
    , cast(percentile_cont(0.5) within group (order by column_id) over(
        partition by variable
      ) as decimal(10,2)) as mdn_column_id
  from dupcheck_example
) b
on a.variable = b.variable
;
