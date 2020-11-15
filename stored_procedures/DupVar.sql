-- Cheat Sheet
-- exec DeanCDR.[dhp\cswens].dupvar 'table_name', 'columns, by, comma',
-- @distinct = Y or N;

-- Connect to S930-WHIOSQL1
use DeanCDR;

drop procedure if exists [ds\cswens].DupVar;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 11/5/2019
-- Description:	Identify columns involved in duplication
-- =============================================
CREATE PROCEDURE [ds\cswens].DupVar 
	-- Add the parameters for the stored procedure here
	@tbl varchar(257) = '', 
	@col varchar(127) = '',
  @distinct varchar(8) = 'Y'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  -- Insert statements for procedure here

  -- Handle the distinct parameter
  set @distinct = upper(substring(@distinct, 1, 1))
  if charindex('*' + @distinct + '*', '*Y*N*') = 0 begin
    declare @msg varchar(100) = 'W' + 'ARNING: Please specify Y or N for @distinct argument.';
    raiserror(@msg, 11, 0)
    return
  end;
  if @distinct = 'Y' begin set @distinct = 'distinct' end;
  else begin set @distinct = '' end;

  -- Split schema from table using the TBL parameter
  -- This process looks for a dot in between
  -- If no dot is found, it is skipped and a default schema is set to DBO
  declare @schema_name varchar(127) = '';
  declare @table_name varchar(127) = '';
  if patindex('%.%', @tbl) > 0 begin;
    set @schema_name = (select upper(ltrim(rtrim(substring(@tbl, 1, patindex('%.%', @tbl)-1)))));
    set @table_name = (select upper(ltrim(rtrim(substring(@tbl, patindex('%.%', @tbl)+1, len(@tbl))))));
    if substring(@schema_name, 1, 1) = '[' begin;
      set @schema_name = substring(@schema_name, 2, len(@schema_name)-2)
    end;
  end;
  else begin;
    set @schema_name = 'dbo';
    set @table_name = upper(ltrim(rtrim(@tbl)));
  end;

  -- Check for table
  declare @tblchk int = (
    select count(*)
    from sys.tables t
    left join sys.schemas s
    on t.schema_id = s.schema_id
    where 1=1
    and t.name is not null
    and lower(t.name) = lower(@table_name)
    and lower(s.name) = lower(@schema_name)
  );
  if @tblchk <> 1 begin;
    print 'W' + 'ARNING: Table ' + @schema_name + '.' + @table_name + ' not found.';
    return;
  end;

  -- Split column argument
  select ltrim(rtrim(value)) as col, row_number() over(order by charindex(value, @col)) as n into #dupvar_cols from string_split(@col, ',');
  declare @colcnt int
  set @colcnt = (select count(*) from #dupvar_cols);

  -- Set up select, group by, order by, and on (inner join) statements
  declare @cnt int = 1
  declare @grp nvarchar(max) = ''
  while @cnt <= @colcnt begin
    if @cnt = 1 begin set @grp = @grp + (select col from #dupvar_cols where n = @cnt) end;
    else begin set @grp = @grp + ', ' + (select col from #dupvar_cols where n = @cnt) end;
    set @cnt = @cnt + 1
  end;

  -- Column search
  select c.name as column_name
    , c.column_id
    , row_number() over(order by c.column_id) as n
  into #dupvar_othercols
  from sys.columns c
  -- merge tables and views
  left join (
    select name, object_id, schema_id
    from sys.tables
    union
    select name, object_id, schema_id
    from sys.views
  ) t
  on c.object_id = t.object_id
  left join sys.schemas s
  on t.schema_id = s.schema_id
  inner join (
    select *
    from sys.types
    where name not in ('sysname')
  ) ts
  on c.system_type_id = ts.system_type_id
  where 1=1
  and s.name is not null
  and t.name is not null
  and upper(s.name) = @schema_name
  and upper(t.name) = @table_name
  -- exclude any BY columns
  and charindex(upper(c.name), upper(@col)) = 0
  order by c.column_id
  ;

  -- inspect other columns and set up related lists
  declare @othercolcnt int
  set @othercolcnt = (select count(*) from #dupvar_othercols);

  declare @othercnt int = 1;
  declare @eq1 varchar(max) = '';
  declare @eq2 varchar(max) = '';
  declare @var varchar(127) = '';
  declare @comma varchar(1) = '';
  declare @otherlist varchar(max) = '';
  while @othercnt <= @othercolcnt begin
    set @var = (select column_name from #dupvar_othercols where n = @othercnt)
    if @othercnt > 1 begin set @comma = ',' end;
    set @eq1 = @eq1 + @comma + ' count(' + @distinct + ' ' + @var + ') as ' + @var
    set @eq2 = @eq2 + @comma + ' max(' + @var + ') as ' + @var
    set @otherlist = @otherlist + @comma + ' ' + @var
    set @othercnt = @othercnt + 1
  end;

  -- set up sql statements to aggregate other columns by the specified BY groups
  declare @sql1 varchar(max) = '';
  declare @sql2 varchar(max) = '';
  declare @sql3 varchar(max) = '';
  -- First query is in this form: select count(distinct COLUMN1), ... from TABLE group by BY_COLUMNS;
  set @sql1 = 'select' + @eq1 + ' from ' + @tbl + ' group by ' + @grp;
  -- Second query is in this form: select max(COLUMN1), ... from (FIRST_QUERY) a;
  set @sql2 = 'select' + @eq2 + ' from (' + @sql1 + ') a';
  -- Third query assembles prior two queries, executing a count distinct and taking the max values for each
  -- Finally it rotates the columns and selects columns that have more than one value on count distinct
  set @sql3 = 'select col as column_name, maximum from (' + @sql2 + ') m unpivot (maximum for col in (' + @otherlist + ')) as unpvt where maximum > 1 order by maximum desc;'
  exec sp_sqlexec @sql3;

END
GO

grant execute on object::[ds\cswens].DupVar to public;

--exec dupvar [ds\cswens].DupCheck_example, dataset, @distinct = Y;
/*
select *
into [dhp\cswens].mssp_tob_sample
from mssp_tob
where patient_id in (
  select top 10 patient_id from (
    select distinct patient_id
    from mssp_tob
  ) m
)
;
exec [ds\cswens].dupvar mssp_tob_sample, 'patient_id';
*/
