
drop function if exists [ds\cswens].Scan;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 3/11/2020
-- Description:	Return Nth word from string
-- =============================================
CREATE FUNCTION [ds\cswens].Scan 
(
	-- Add the parameters for the function here
	@string varchar(max),
  @count int,
  @char varchar(max)
)
RETURNS varchar(max)
AS
BEGIN

	-- Declare the return variable here
	DECLARE @Result varchar(max)

	-- Add the T-SQL statements to compute the return value here
	SELECT @Result = (
    select value from (
      select value, row_number() over (order by (select 1)) as n from string_split(@string, @char)
    ) a
    where n = @count
  );

	-- Return the result of the function
	RETURN @Result

END
GO

grant execute on object::[ds\cswens].Scan to public;

--select [ds\cswens].scan('asdf.qwer', 2, '.');
--select [ds\cswens].scan('qwer.asdf', 2, '.');
