drop function if exists [ds\cswens].ConvertFromUtc

-- ================================================
-- Template generated from Template Explorer using:
-- Create Scalar Function (New Menu).SQL
--
-- Use the Specify Values for Template Parameters 
-- command (Ctrl-Shift-M) to fill in the parameter 
-- values below.
--
-- This block of comments will not be included in
-- the definition of the function.
-- ================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 
-- Description:	
-- =============================================
CREATE FUNCTION [ds\cswens].ConvertFromUtc (@i_dUtcTime datetime)
RETURNS datetime
AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result datetime

	-- Add the T-SQL statements to compute the return value here
  DECLARE @dLocalTime DATETIME;
  DECLARE @iOffset INTEGER;
  DECLARE @iCount INTEGER; 
  DECLARE @iErrorHandler INTEGER;

  IF (@i_dUtcTime IS NULL OR @i_dUtcTime  = '')
  BEGIN
    RETURN NULL;
  END

  SET @iOffset = (SELECT TIME_GAP FROM [CLARITY_DST_SWITCH_DATES] WHERE @i_dUtcTime  >= [INTERVAL_START_DATE] AND @i_dUtcTime  < [INTERVAL_END_DATE]);

  IF (@iOffset IS NULL)
  BEGIN
    SET @iCount = (SELECT COUNT(*) FROM [CLARITY_DST_SWITCH_DATES]);
    IF @iCount = 0
      SET @iErrorHandler = 'The DST_SWITCH_DATES table must be populated before using this function.';
    ELSE
      SET @iErrorHandler = 'The supplied UTC time, ' + cast(@i_dUtcTime as varchar) + ', is out of the available range of times in the table DST_SWITCH_DATES';
    RETURN 1/0;
  END
  ELSE
  BEGIN
    SET @dLocalTime = DATEADD(HOUR, @iOffset, @i_dUtcTime);
  END
  
	-- Return the result of the function
	RETURN @Result

END
GO

grant execute on object::[ds\cswens].ConvertFromUtc to public;
