-- Connect to S930-WHIOSQL1
use DeanCDR;

drop procedure if exists [ds\cswens].ETL_QA;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 11/19/2019
-- Description:	Aggregate columns for ETL
-- =============================================
CREATE PROCEDURE [ds\cswens].ETL_QA
	-- Add the parameters for the stored procedure here
  @prc varchar(250) = '',
	@tbl varchar(257) = '',
  @col varchar(4000) = '',
  @typ varchar(50) = '',
  @date varchar(10) = ''
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  -- Examine the TYP (type) parameter
  -- Look at only the first character
  -- It should be Id, Date, Category, or Numeric
  set @typ = substring(upper(@typ), 1, 1);
  if patindex('%' + @typ + '%', 'IDCN') = 0 begin;
    print 'W' + 'ARNING: Please specify the type as ID, Date, Category, or Numeric.';
    return;
  end;
  else begin;
    if @typ = 'I' begin set @typ = 'ID' end;
    else if @typ = 'D' begin set @typ = 'Date' end;
    else if @typ = 'C' begin set @typ = 'Category' end;
    else if @typ = 'N' begin set @typ = 'Numeric' end;
  end;

  -- Evaluate the DATE parameter
  if @date = '' begin set @date = (select cast(replace(convert(nvarchar, getdate(), 106), ' ', '') as varchar(10))) end;

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

  -- Identify all relevant columns from SQL Server metadata
  -- This filters on the schema and table names generated above
  select c.name as column_name
    , c.column_id
    , ts.name as column_type
    , row_number() over(order by c.column_id) as n
  into #ETL_QA_columns
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
  and upper(c.name) in (select upper(ltrim(rtrim(value))) from string_split(@col, ','))
  order by c.column_id
  ;

  -- Set up count variable to limit processing
  -- Also check that the counts match between the original argument and returned columns
  declare @colchk int = (select count(*) from string_split(@col, ','))
  declare @colcnt int = (select count(*) from #ETL_QA_columns);
  if @colchk <> @colcnt begin;
    print 'W' + 'ARNING: Count of input columns (' + cast(@colchk as varchar) + ') does not match count of found columns (' + cast(@colcnt as varchar) + ').';
    return;
  end;

  -- Set statistics
  -- This is a driver table that includes the type of variable, type of statistic, a category flag (Y/N),
  -- and the function that will be used. The functions are split into two parts so the column name can
  -- be inserted in between.
  create table #ETL_QA_Stats (type varchar(250), statistic varchar(4000), category varchar(4000), calc_prefix varchar(4000), calc_suffix varchar(4000));
  insert into #ETL_QA_Stats values ('All', 'Count', 'N', 'count(', ')');
  insert into #ETL_QA_Stats values ('All', 'Unique Count', 'N', 'count(distinct ', ')');
  insert into #ETL_QA_Stats values ('Date', 'Date Total', 'N', 'sum(cast(datediff(dd, 0, ', ') as bigint))');
  insert into #ETL_QA_Stats values ('Date', 'Year/Month', 'Y', 'count(', ')');
  insert into #ETL_QA_Stats values ('Category', 'Frequency', 'Y', 'count(', ')');
  insert into #ETL_QA_Stats values ('Numeric', 'Min', 'N', 'min(cast(', ' as float))');
  insert into #ETL_QA_Stats values ('Numeric', 'Max', 'N', 'max(cast(', ' as float))');
  insert into #ETL_QA_Stats values ('Numeric', 'Sum', 'N', 'sum(cast(', ' as float))');
  insert into #ETL_QA_Stats values ('Numeric', 'Average', 'N', 'avg(cast(', ' as float))');
  insert into #ETL_QA_Stats values ('Numeric', 'St. Dev.', 'N', 'stdev(cast(', ' as float))');
  insert into #ETL_QA_Stats values ('Numeric', 'Variance', 'N', 'var(cast(', ' as float))');
  insert into #ETL_QA_Stats values ('Numeric', 'Median', 'N', '(select distinct mdn from (select percentile_disc(0.5) within group (order by ', ') over() as mdn from ' + @tbl + ' a) b)');
  insert into #ETL_QA_Stats values ('Numeric', 'Quartile 25', 'N', '(select distinct mdn from (select percentile_disc(0.25) within group (order by ', ') over() as mdn from ' + @tbl + ' a) b)');
  insert into #ETL_QA_Stats values ('Numeric', 'Quartile 75', 'N', '(select distinct mdn from (select percentile_disc(0.75) within group (order by ', ') over() as mdn from ' + @tbl + ' a) b)');

  -- Sort the statistics into a new temp table
  -- Also set the count of statistics for the given QA type
  drop table if exists #ETL_QA_Stats_Order;
  select *, row_number() over(order by type, statistic) as n into #ETL_QA_Stats_Order from #ETL_QA_Stats where type in ('All', @typ);
  declare @statscnt int = (select count(*) from #ETL_QA_Stats_Order);

  -- Set up iterator variables (i, s) and other variables needed for the loop
  declare @i int = 1;
  declare @s int = 1;
  declare @curcol varchar(127) = '';
  declare @curstat varchar(4000) = '';
  declare @category varchar(500) = '';
  declare @calc_prefix varchar(4000) = '';
  declare @calc_suffix varchar(4000) = '';
  declare @groupby varchar(4000) = '';

  -- Begin the loop, running each column through each statistic
  -- e.g., with col = 'pat_id, claim_id' and typ = ID
  -- Outer Loop 1) pat_id
  --  Inner Loop 1) count(pat_id)
  --  Inner Loop 2) count(distinct pat_id)
  -- Outer Loop 2) claim_id
  --  Inner Loop 1) count(claim_id)
  --  Inner Loop 2) count(distinct claim_id)

  -- Outer Loop
  while @i <= @colcnt begin;

    -- Set the iterator and the current column name
    set @s = 1;
    set @curcol = (select column_name from #ETL_QA_columns where n = @i);
    --select @curcol;

    -- Inner Loop
    while @s <= @statscnt begin;

      -- Set the current category
      set @category = (select category from #ETL_QA_Stats_Order where n = @s);
      set @groupby = '';
      -- For dates, run a year/month frequency
      if @category = 'Y' and @typ = 'Date' begin
        set @category = 'format(cast(' + @curcol + ' as date), ''yyyy-MM'')' 
        set @groupby = 'group by ' + @category
      end;
      -- Otherwise, just do a frequency on the category values
      else if @category = 'Y' begin 
        set @category = @curcol 
        set @groupby = 'group by ' + @category
      end;
      -- Delete category if the category flag is N
      else if @category = 'N' begin 
        set @category = '''''' 
        set @groupby = ''
      end;

      -- Set the current statistics and function prefix / suffix
      set @curstat = (select statistic from #ETL_QA_Stats_Order where n = @s);
      set @calc_prefix = (select calc_prefix from #ETL_QA_Stats_Order where n = @s);
      set @calc_suffix = (select calc_suffix from #ETL_QA_Stats_Order where n = @s);

      --select @curstat, @category, @groupby;

      -- Generate the SQL to run the aggregation for the column and statistic
      declare @stats_sql varchar(4000) = '
        insert into dbo.ETL_Table_QA_Detail
        select distinct
            ''' + @prc + ''' as etl_process
          , ''' + @table_name + ''' as table_name
          , ''' + @curcol + ''' as column_name
          , ''' + @typ + ''' as qa_type
          , cast(''' + @date + ''' as date) as period
          , ''' + @curstat + ''' as statistic
          , ' + @category + ' as category
          , ' + @calc_prefix + @curcol + @calc_suffix + ' as measure
        from ' + @tbl + '
        ' + @groupby
      ;
      --select ltrim(rtrim(@stats_sql));

      -- Execute the generated SQL
      begin try
        exec sp_sqlexec @stats_sql;
        print 'Inserted ' + @curstat + ' for ' + @curcol + ' on ' + @tbl
      end try
      begin catch
        delete from dbo.ETL_Table_QA_Detail where period = @date and table_name = @tbl and column_name = @curcol and statistic = @curstat;

        declare @ErrorMessage varchar(250);
        declare @ErrorSeverity varchar(250);
        declare @ErrorState varchar(250);
        set @ErrorMessage = error_message()
        set @ErrorSeverity = error_severity()
        set @ErrorState = error_state()
        raiserror(@ErrorMessage, @ErrorSeverity, @ErrorState)

        set @ErrorMessage = 'Failed to insert ' + @curstat + ' for ' + @curcol + ' on ' + @tbl;
        raiserror(@ErrorMessage, @ErrorSeverity, @ErrorState)
      end catch

      -- Increment the statistics iterator
      set @s = @s + 1;

    end;

    -- Increment the column iterator
    set @i = @i + 1;

  end;

  return 1;

END
GO

grant execute on object::[ds\cswens].ETL_QA to public;

/*
exec [ds\cswens].ETL_QA 'PROCESSNAME', TABLENAME, 'COLUMN, NAMES', 'TYPE' (ID, Category, Numeric, Date), DATE
exec [ds\cswens].ETL_QA 'Patient_ID', V_PayerContractsEligibility_NEW, 'epic_pat_id, enterprise_mrn, person_id', 'ID'
select * from dbo.ETL_Table_QA_Detail where table_name = 'V_PayerContractsEligibility_NEW';
*/

/*
drop table dbo.ETL_Table_QA_Detail
create table dbo.ETL_Table_QA_Detail (
    etl_process varchar(250)
  , table_name varchar(127)
  , column_name varchar(127)
  , qa_type varchar(50)
  , period date
  , statistic varchar(250)
  , category varchar(500)
  , measure float
);
*/
