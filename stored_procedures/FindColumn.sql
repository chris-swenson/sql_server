-- Cheat Sheet
-- exec DeanCDR.[ds\cswens].findcolumn '%like_criteria%';

-- Connect to S930-WHIOSQL1
use DeanCDR;

drop procedure if exists [ds\cswens].FindColumn;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 10/29/2019
-- Description:	Search SYS for columns
-- =============================================
CREATE PROCEDURE [ds\cswens].FindColumn 
	-- Add the parameters for the stored procedure here
	@column nvarchar(250) = '',
  @db nvarchar(127) = ''
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

	-- Column search
  declare @sql nvarchar(max) = '
    select 
        ' + @dbname + ' as database_name
      , s.name as schema_name
      , t.name as table_name
      , c.name as column_name
      , c.column_id
      , ts.name as sys_type
    from ' + @db + 'sys.columns c
    -- merge tables and views
    left join (
      select name, object_id, schema_id
      from ' + @db + 'sys.tables
      union
      select name, object_id, schema_id
      from ' + @db + 'sys.views
    ) t
    on c.object_id = t.object_id
    left join ' + @db + 'sys.schemas s
    on t.schema_id = s.schema_id
    left join ' + @db + 'sys.types ts
    on c.system_type_id = ts.system_type_id
    where 1=1
    and s.name is not null
    and t.name is not null
    and lower(c.name) like lower(''' + @column + ''')
    order by t.name, c.column_id
    ;
  '

  exec sp_sqlexec @sql;

END
GO

grant execute on object::[ds\cswens].FindColumn to public;

--Exec [ds\cswens].FindColumn race;
