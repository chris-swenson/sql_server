use DeanCDR;

drop function if exists [ds\cswens].KeepNumeric;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 11/13/2019
-- Description:	Execute character compression like SAS
-- =============================================
CREATE FUNCTION [ds\cswens].KeepNumeric 
(
	-- Add the parameters for the function here
	@source nvarchar(max)
)
RETURNS nvarchar(max) AS
BEGIN

  declare @chars nvarchar(50)
  set @chars = '[-.0-9 ]'

	-- Declare the return variable here
	DECLARE @target nvarchar(4000)
  set @target = ''

	-- Add the T-SQL statements to compute the return value here
	declare @i as int
  set @i = 1
  declare @single nvarchar(1)
  while @i <= len(@source) begin
    set @single = substring(@source, @i, 1)
    if patindex(@chars, @single) = 0 begin set @single = '' end
    set @target = @target + @single
    set @i = @i + 1
  end
  set @target = ltrim(rtrim(@target))

	-- Return the result of the function
	RETURN @target

END
GO

grant execute on object::[ds\cswens].KeepNumeric to public;

--select cast([ds\cswens].KeepNumeric('  2< asdf 1 if 5.7 ') as int)
/*
select cast(rslt as float) as result
from (
  select distinct [ds\cswens].KeepNumeric(test_result_2) as rslt
  from (
    select top 50000 test_result_2 
    from save_clarity_wi_labs
  ) a
) b
;
*/
