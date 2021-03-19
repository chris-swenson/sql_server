-- Review data structure
select * from alphabet; -- Types indicated in 2 numeric columns
select * from alphabet_type; -- Types indicated in 1 categorical column, 'measure' is a dummy

-- Pivot
-- Row to Column
-- COALESCE() new columns or missing values may occur
select letter, coalesce(vowel, 0) as vowel, coalesce(consonent, 0) as consonent
from alphabet_type
pivot (
  -- Aggregation required
  -- Syntax: [aggregate_function]([fact]) for [column source for new column names] in ([column name values])
  sum(measure) for type in (vowel, consonent)
) as p
;

-- Unpivot
-- Column to Row
select letter, type, measure
from alphabet
unpivot (
  -- Lack of aggregation required
  -- Syntax: [name column name for fact] for [new column name to store old column names] in ([current fact column list])
  measure for type in (vowel, consonent)
) as u
;
