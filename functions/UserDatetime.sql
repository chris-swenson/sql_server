drop function if exists [ds\cswens].UserDatetime;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 3/11/2020
-- Description:	Return concatenated user name and datetime as string for table names
-- =============================================
CREATE FUNCTION [ds\cswens].UserDatetime(
  @prefix varchar(90) = '',
  @suffix varchar(90) = ''
)
RETURNS varchar(128)
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result varchar(128);

  if @prefix <> '' begin; set @prefix = concat(@prefix, '_'); end;
  if @suffix <> '' begin; set @suffix = concat('_', @suffix); end;

	-- Add the T-SQL statements to compute the return value here
  -- Return username, current time, and random number
	SELECT @Result = (
    concat(
        @prefix
      , replace(system_user, '\', '_')
      , '_'
      , (replace(replace(replace(replace(
            convert(varchar(24), current_timestamp, 126)
          , '-', '')
          , ':', '')
          , '.', '')
          , 'T', '_')
        )
      , @suffix
    )
  )

	-- Return the result of the function
	RETURN @Result

END
GO

grant execute on object::[ds\cswens].UserDatetime to public;

--select [ds\cswens].UserDatetime('', '');
--select [ds\cswens].UserDatetime('a', 'b');
--select [ds\cswens].UserDatetime('##sp_CollectClaims', cast(rand()*power(10,6) as varchar(6)));
