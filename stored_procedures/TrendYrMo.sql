-- Cheat Sheet
-- exec DeanCDR.[dhp\cswens].trendyrmo 'table_name', 'date_column', 
-- 'additional_counts';

-- Connect to S930-WHIOSQL1
use DeanCDR;

drop procedure if exists [ds\cswens].TrendYrMo;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 11/13/2019
-- Description:	Group by year and month
-- =============================================
CREATE PROCEDURE [ds\cswens].TrendYrMo 
	-- Add the parameters for the stored procedure here
	@table varchar(257) = '', 
	@date varchar(127) = '',
  @custom varchar(4000) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  -- Insert statements for procedure here
  if ltrim(@custom) <> '' and substring(ltrim(@custom), 1, 1) <> ',' begin
    set @custom = ', ' + @custom
  end

  declare @sel varchar(4000)
  declare @by varchar(4000)
  declare @sql varchar(4000)
  set @sel = 'year(' + @date + ') as yr, month(' + @date + ') as mo, count(*) as records'
  set @by = 'year(' + @date + '), month(' + @date + ')'
  set @sql = 'select ' + @sel + @custom + ' from ' + @table + ' group by ' + @by + ' order by ' + @by

  exec sp_sqlexec @sql;
END
GO

grant execute on object::[ds\cswens].TrendYrMo to public;


--exec [ds\cswens].trendyrmo save_clarity_wi_labs, service_date, 'count(distinct patient_id) as patients';
