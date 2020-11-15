-- Connect to S930-WHIOSQL1
use DeanCDR;

drop procedure if exists [ds\cswens].TableFreq;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 3/30/2020
-- Description:	Aggregate columns for a table
-- =============================================
CREATE PROCEDURE [ds\cswens].TableFreq
	-- Add the parameters for the stored procedure here
	@tbl varchar(500) = '',
  @include varchar(max) = '',
  @exclude varchar(max) = ''
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
  declare @schema_name_text nvarchar(128);
  declare @table_name nvarchar(128);
  drop table if exists #split;
  select value, n
  into #split
  from (
    select value, row_number() over (order by (select 1)) as n 
    from string_split(@tbl, '.')
  ) a
  ;
  if patindex('%.%.%', @tbl) > 0 begin;
    set @db_name = (select value from #split where n = 1);
    set @schema_name = (select value from #split where n = 2);
    set @table_name = (select value from #split where n = 3);
  end;
  else if patindex('%.%', @tbl) > 0 begin;
    set @db_name = (select db_name());
    set @schema_name = (select value from #split where n = 1);
    set @table_name = (select value from #split where n = 2);
  end;
  else begin;
    set @db_name = (select db_name());
    set @schema_name = 'dbo';
    set @table_name = @tbl;
  end;
  set @schema_name_text = @schema_name;
  if substring(@schema_name, 1, 1) = '[' begin;
    set @schema_name_text = substring(@schema_name, 2, len(@schema_name)-2);
  end;
  --select @db_name as db, @schema_name as sch, @schema_name_text as sch2, @table_name as tbl;

  -- Identify all relevant columns from SQL Server metadata
  -- This filters on the schema and table names generated above
  drop table if exists #TableFreq_columns;
  create table #TableFreq_columns (column_name varchar(128), column_type varchar(50), n int);
  declare @include_sql nvarchar(250) = '';
  declare @exclude_sql nvarchar(250) = '';
  if @include <> '' begin;
    set @include_sql  = 'and c.name in (select ltrim(rtrim(value)) from string_split(''' + @include + ''', '',''))'
  end;
  if @exclude <> '' begin;
    set @exclude_sql = 'and c.name NOT in (select ltrim(rtrim(value)) from string_split(''' + @exclude + ''', '',''))'
  end;
  declare @sql_col nvarchar(max) = '
    insert into #TableFreq_columns
    select sub.*, row_number() over(order by column_type, column_name) as n
    from (
      select 
          c.name as column_name
        , case 
            when ts.name in (''text'', ''ntext'', ''varchar'', ''char'', ''nvarchar'', ''nchar'') then ''Category''
            when ts.name in (''tinyint'', ''smallint'', ''int'', ''real'', ''money'', ''float'', ''decimal'', ''numeric'', ''smallmoney'', ''bigint'') then ''Numeric''
            when ts.name in (''date'', ''time'', ''datetime2'', ''datetimeoffset'', ''smalldatetime'', ''datetime'', ''timestamp'') then ''Date''
          end as column_type
      from ' + @db_name + '.sys.columns c
      left join (
        select name, object_id, schema_id
        from ' + @db_name + '.sys.tables
        union
        select name, object_id, schema_id
        from ' + @db_name + '.sys.views
      ) t
      on c.object_id = t.object_id
      left join ' + @db_name + '.sys.types ts
      on c.system_type_id = ts.system_type_id
      left join ' + @db_name + '.sys.schemas s
      on t.schema_id = s.schema_id
      where 1=1
      and lower(s.name) = lower(''' + @schema_name_text + ''')
      and lower(t.name) = lower(''' + @table_name + ''')
      ' + @include_sql + '
      ' + @exclude_sql + '
    ) sub
  ';
  --select @sql_col;
  exec sp_executesql @sql_col;
  --select count(*) from #TableFreq_columns;
  if (select count(*) from #TableFreq_columns) = 0 begin;
    declare @msg1 varchar(100) = 'W' + 'ARNING: Input table does not exist.'; 
    raiserror(@msg1, 11, 0);
    return;
  end;

  --declare @t table (column_name varchar(128));
  --insert @t (column_name)
  --exec deancdr.[dhp\cswens].findtablecolumns @tbl, @output = C;
  --select * from @t;

  -- Set up count variable to limit processing
  -- Also check that the counts match between the original argument and returned columns
  declare @colcnt int = (select count(*) from #TableFreq_columns);
  if @include <> '' begin;
    declare @colchk int = (select count(*) from string_split(@include, ','));
    if @colchk <> @colcnt begin;
      declare @ErrMsg1 varchar(250);
      set @ErrMsg1 = 'W' + 'ARNING: Count of input columns (' + cast(@colchk as varchar) + ') does not match count of found columns (' + cast(@colcnt as varchar) + ').';
      raiserror(@ErrMsg1, 0, 0);
    end;
  end;

  -- Set statistics
  -- This is a driver table that includes the type of variable, type of statistic, a category flag (Y/N),
  -- and the function that will be used. The functions are split into two parts so the column name can
  -- be inserted in between.
  create table #TableFreq_Stats (type varchar(250), statistic varchar(4000), category varchar(4000), calc_prefix varchar(4000), calc_suffix varchar(4000));
  insert into #TableFreq_Stats values ('Date', 'Count', 'N', 'count(', ')');
  insert into #TableFreq_Stats values ('Date', 'Unique Count', 'N', 'count(distinct ', ')');
  insert into #TableFreq_Stats values ('Date', 'Missing', 'N', 'sum(case when ', ' is null then 1 else 0 end)');
  insert into #TableFreq_Stats values ('Date', 'Year/Month', 'Y', 'count(', ')');
  insert into #TableFreq_Stats values ('Category', 'Count', 'N', 'count(', ')');
  insert into #TableFreq_Stats values ('Category', 'Missing', 'N', 'sum(case when ', ' is null then 1 else 0 end)');
  insert into #TableFreq_Stats values ('Category', 'Unique Count', 'N', 'count(distinct ', ')');
  insert into #TableFreq_Stats values ('Category', 'Frequency', 'Y', 'count(', ')');
  insert into #TableFreq_Stats values ('Numeric', 'Count', 'N', 'count(', ')');
  insert into #TableFreq_Stats values ('Numeric', 'Unique Count', 'N', 'count(distinct ', ')');
  insert into #TableFreq_Stats values ('Numeric', 'Missing', 'N', 'sum(case when ', ' is null then 1 else 0 end)');
  insert into #TableFreq_Stats values ('Numeric', 'Min', 'N', 'min(cast(', ' as float))');
  insert into #TableFreq_Stats values ('Numeric', 'Max', 'N', 'max(cast(', ' as float))');
  insert into #TableFreq_Stats values ('Numeric', 'Sum', 'N', 'sum(cast(', ' as float))');
  --insert into #TableFreq_Stats values ('Date', 'Date Total', 'N', 'sum(cast(datediff(dd, 0, ', ') as bigint))');
  insert into #TableFreq_Stats values ('Numeric', 'Average', 'N', 'avg(cast(', ' as float))');
  insert into #TableFreq_Stats values ('Numeric', 'St. Dev.', 'N', 'stdev(cast(', ' as float))');
  insert into #TableFreq_Stats values ('Numeric', 'Variance', 'N', 'var(cast(', ' as float))');
  insert into #TableFreq_Stats values ('Numeric', 'Median', 'N', '(select distinct mdn from (select percentile_disc(0.5) within group (order by ', ') over() as mdn from ' + @tbl + ' a) b)');
  insert into #TableFreq_Stats values ('Numeric', 'Quartile 25', 'N', '(select distinct mdn from (select percentile_disc(0.25) within group (order by ', ') over() as mdn from ' + @tbl + ' a) b)');
  insert into #TableFreq_Stats values ('Numeric', 'Quartile 75', 'N', '(select distinct mdn from (select percentile_disc(0.75) within group (order by ', ') over() as mdn from ' + @tbl + ' a) b)');
  --select count(*) from #TableFreq_Stats;

  -- Sort the statistics into a new temp table
  -- Also set the count of statistics for the given QA type
  drop table if exists #TableFreq_Stats_Order;
  select *, row_number() over(partition by type order by statistic) as n into #TableFreq_Stats_Order from #TableFreq_Stats;

  -- Set up iterator variables (i, s) and other variables needed for the loop
  declare @i int = 1;
  declare @s int = 1;
  declare @statscnt int = 1;
  declare @curcol varchar(127) = '';
  declare @curtyp nvarchar(50) = '';
  declare @curstat varchar(4000) = '';
  declare @category_flag varchar(1) = '';
  declare @category varchar(500) = '';
  declare @calc_prefix varchar(4000) = '';
  declare @calc_suffix varchar(4000) = '';
  declare @calculation varchar(4000) = '';
  declare @groupby varchar(4000) = '';

  -- Begin the loop, running each column through each statistic
  -- e.g., with col = 'pat_id, claim_id' and typ = ID
  -- Outer Loop 1) pat_id
  --  Inner Loop 1) count(pat_id)
  --  Inner Loop 2) count(distinct pat_id)
  -- Outer Loop 2) claim_id
  --  Inner Loop 1) count(claim_id)
  --  Inner Loop 2) count(distinct claim_id)

  drop table if exists #TableFreq_results;
  create table #TableFreq_results (table_name varchar(128), column_name varchar(128), qa_type varchar(50), statistic varchar(50), category varchar(500), measure float);

  -- Outer Loop on Columns
  while @i <= @colcnt begin;

    -- Set the iterator and the current column name
    set @s = 1;
    set @curcol = (select column_name from #TableFreq_columns where n = @i);
    set @curtyp = (select column_type from #TableFreq_columns where n = @i);
    set @statscnt = (select count(*) from #TableFreq_Stats_Order where type = @curtyp);
    --select @curcol;

    -- Inner Loop on Statistics
    while @s <= @statscnt begin;

      -- Set the current category
      set @category_flag = (select category from #TableFreq_Stats_Order where n = @s and type = @curtyp);
      set @groupby = '';

      -- Set the current statistics and function prefix / suffix
      set @curstat = (select statistic from #TableFreq_Stats_Order where n = @s and type = @curtyp);
      set @calc_prefix = (select calc_prefix from #TableFreq_Stats_Order where n = @s and type = @curtyp);
      set @calc_suffix = (select calc_suffix from #TableFreq_Stats_Order where n = @s and type = @curtyp);

      -- For dates, run a year/month frequency
      if @category_flag = 'Y' and @curtyp = 'Date' begin
        set @category = 'format(cast(' + @curcol + ' as date), ''yyyy-MM'')' 
        set @groupby = 'group by ' + @category
      end;
      -- Otherwise, just do a frequency on the category values
      else if @category_flag = 'Y' begin 
        set @category = @curcol
        set @groupby = 'group by ' + @category
      end;
      -- Delete category if the category flag is N
      else if @category_flag = 'N' begin 
        set @category = '''N/A'''
        set @groupby = ''
      end;

      if @category_flag = 'Y' and @curtyp = 'Category' begin
        set @calculation = @calc_prefix + '*' + @calc_suffix;
      end;
      else begin
        set @calculation = @calc_prefix + @curcol + @calc_suffix;
      end;

      --select @curstat, @category, @groupby;
      --select @category, @calculation;

      -- Generate the SQL to run the aggregation for the column and statistic
      declare @stats_sql varchar(4000) = '
        insert into #TableFreq_results
        select distinct
            ''' + @table_name + ''' as table_name
          , ''' + @curcol + ''' as column_name
          , ''' + @curtyp + ''' as qa_type
          , ''' + @curstat + ''' as statistic
          , ' + @category + ' as category
          , ' + @calculation + ' as measure
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
        select ltrim(rtrim(@stats_sql));

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

  select *
  from #TableFreq_results
  ;

END
GO

grant execute on object::[ds\cswens].TableFreq to public;

--select * from [dhp\cswens].dupcheck_example2;
--exec [ds\cswens].tablefreq '[dhp\cswens].dupcheck_example2';

--exec [ds\cswens].tablefreq '[dhp\cswens].alphabet';
--exec [ds\cswens].tablefreq alphabet
