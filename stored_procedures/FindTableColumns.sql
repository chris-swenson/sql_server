-- Cheat Sheet
-- exec DeanCDR.[ds\cswens].findtablecolumns 'table_name';

-- Connect to S930-WHIOSQL1
use DeanCDR;

drop procedure if exists [ds\cswens].FindTableColumns;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 10/29/2019
-- Description:	Return all columns in a table
-- =============================================
CREATE PROCEDURE [ds\cswens].FindTableColumns 
	-- Add the parameters for the stored procedure here
	@table varchar(400) = '',
  @where varchar(max) = '',
  @output varchar(1) = 'T'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  -- Split TBL parameter into database name, schema name, and table name
  -- Defaults database to db_name() when not specified
  -- Defaults schema to DBO when not specified
  declare @db_name nvarchar(128);
  declare @schema_name nvarchar(128);
  declare @table_name nvarchar(128);
  drop table if exists #split;
  select value, n
  into #split
  from (
    select value, row_number() over (order by (select 1)) as n 
    from string_split(@table, '.')
  ) a
  ;
  if patindex('%.%.%', @table) > 0 begin;
    set @db_name = (select value from #split where n = 1);
    set @schema_name = (select value from #split where n = 2);
    set @table_name = (select value from #split where n = 3);
  end;
  else if patindex('%.%', @table) > 0 begin;
    set @db_name = (select db_name());
    set @schema_name = (select value from #split where n = 1);
    set @table_name = (select value from #split where n = 2);
  end;
  else begin;
    set @db_name = (select db_name());
    set @schema_name = 'dbo';
    set @table_name = @table;
  end;

  --select @db_name as db, @schema_name as sch, @table_name as tbl;

  declare @select varchar(max) = '';
  if @output = 'T' begin; 
    set @select = 'select * ';
  end;
  if @output = 'C' begin; 
    set @select = 'select column_name ';
  end;

  if @where <> '' begin; set @where = 'where ' + @where; end;

	-- Column search
  declare @sql nvarchar(max) = 
    @select + 
    'from (
      select 
          ''' + @db_name + ''' as database_name
        , s.name as schema_name
        , t.name as table_name
        , c.name as column_name
        , c.column_id
        , ts.name as sys_type
        , c.max_length
        , row_number() over(order by c.column_id) as n
      from ' + @db_name + '.sys.columns c
      left join (
        select name, object_id, schema_id
        from ' + @db_name + '.sys.tables
        union
        select name, object_id, schema_id
        from ' + @db_name + '.sys.views
      ) t
      on c.object_id = t.object_id
      left join ' + @db_name + '.sys.schemas s
      on t.schema_id = s.schema_id
      left join ' + @db_name + '.sys.types ts
      on c.system_type_id = ts.system_type_id
      where 1=1
      and s.name is not null
      and t.name is not null
      and lower(s.name) = lower(''' + @schema_name + ''')
      and lower(t.name) = lower(''' + @table_name + ''')
      and ts.name not in (''sysname'') 
    ) a ' + 
    @where + '
    order by column_id
    ;
  ';
  
  exec sp_sqlexec @sql;

END
GO

grant execute on object::[ds\cswens].FindTableColumns to public;

--exec [ds\cswens].findtablecolumns v_payercontractseligibility;
--exec [ds\cswens].findtablecolumns v_payercontractseligibility, @where = 'column_name like ''%id%'' ';
--exec [ds\cswens].findtablecolumns v_payercontractseligibility, @output = C;
--exec [ds\cswens].findtablecolumns v_payercontractseligibility, @where = 'column_name like ''%id%'' ', @output = C;
