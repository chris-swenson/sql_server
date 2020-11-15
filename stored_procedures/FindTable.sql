-- Cheat Sheet
-- exec DeanCDR.[ds\cswens].findtable '%like_criteria%';

-- Connect to S930-WHIOSQL1
use DeanCDR;

drop procedure if exists [ds\cswens].FindTable;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 10/29/2019
-- Description:	Query SYS for tables
-- =============================================
CREATE PROCEDURE [ds\cswens].FindTable 
	-- Add the parameters for the stored procedure here
	@table nvarchar(257) = '',
  @db nvarchar(128) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  -- Set DB and DBNAME vars
  declare @dbname varchar(127) = '';
  if @db <> '' begin;
    set @dbname = '''' + @db + '''';
    set @db = @db + '.';
  end;
  else begin;
    set @dbname = '''' + db_name() + '''';
  end;

  declare @sql nvarchar(max) = '
    select 
        ' + @dbname + ' as database_name
      , s.name as schema_name
      , t.name as table_name
      , t.table_type
    from (
      select name, schema_id, ''Table'' as table_type from ' + @db + 'sys.tables
      union
      select name, schema_id, ''View'' as table_type from ' + @db + 'sys.views
    ) t
    left join ' + @db + 'sys.schemas s
    on t.schema_id = s.schema_id
    where 1=1
    and t.name is not null
    -- search for tables here
    and lower(t.name) like lower(''' + @table + ''')
    order by t.name
    ;
  ';

  exec sp_sqlexec @sql;

END
GO

grant execute on object::[ds\cswens].FindTable to public;

--exec [ds\cswens].findtable '%v_payer%';
--exec [ds\cswens].findtable '%vw_claim%', @db = ssm_milliman;
