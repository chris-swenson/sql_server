-- The following generates a series of values on a sigmoid curve. 
-- This is useful for smoothly transitioning from one value to another. 
-- For example, if market share changes between period A and period B, 
-- you can use this function to gradually transition instead of jumping. 

-- https://en.wikipedia.org/wiki/Sigmoid_function


-- This one is the logistic function
-- Enter the number of sigmoid numbers to calculate, using an odd number
-- At minimum, 7 is the lowest resulting in a very slight curve
-- At maximum, numbers over 15 are not very different than prior
-- Over 15, the result has more values near 0 and 1 than in between
-- The final row count will be this + 2 to include 0 and 99 (arbitrary large number)
declare @sigmoid_numbers int = 13;
drop table if exists #sig;
select 0 as row_num, 0 as input, cast(0 as float) as sigmoid into #sig;
declare @x int = -1 * (@sigmoid_numbers - 1) / 2;
declare @n int = 1;
while @x < ((@sigmoid_numbers - 1) / 2 + 1) begin;
  insert into #sig select @n, @x, 1. / (1 + exp(-1 * @x));
  set @x = @x + 1;
  set @n = @n + 1;
end;
insert into #sig select @sigmoid_numbers + 1, 99, 1;
select * from #sig;
