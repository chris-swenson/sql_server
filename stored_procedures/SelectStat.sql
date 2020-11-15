-- Cheat Sheet
-- exec DeanCDR.[ds\cswens].selectstat 'table_name', 'columns, by, comma',
-- @var = 'variable_to_select_from', @stat = 'MIN' or 'MAX', @out = 'output';

-- Connect to S930-WHIOSQL1
use DeanCDR;

drop procedure if exists [ds\cswens].SelectStat;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Chris Swenson
-- Create date: 1/17/2020
-- Description:	Select rows based on a statistic
-- =============================================
CREATE PROCEDURE [ds\cswens].SelectStat 
  -- Add the parameters for the stored procedure here
  @ds varchar(257) = '', 
  @by varchar(4000) = '',
  @var varchar(127) = '',
  @stat varchar(15) = '',
  @out varchar(127) = '',
  @test varchar(1) = 'N'
AS BEGIN
  -- SET NOCOUNT ON added to prevent extra result sets from
  -- interfering with SELECT statements.
  SET NOCOUNT ON;

  /* Check arguments */
  if @ds ='' begin;
    print 'W' + 'ARNING: Please specify the table to use (@ds=).';
    return;
  end;
  if @by = '' begin;
    print 'W' + 'ARNING: Please specify the BY columns to use (@by=).';
    return;
  end;
  if @var = '' begin;
    print 'W' + 'ARNING: Please specify the column to use in selection (@var=).';
    return;
  end;
  set @stat = upper(@stat);
  if NOT(@stat = 'MIN' or @stat = 'MAX') begin;
    print 'W' + 'ARNING: Please specify the statistic to use (@stat=MIN or MAX).';
    return;
  end;

  /* Set statistic name */
  declare @statname varchar(25);
  if @stat = 'MIN' begin; set @statname = 'minimum'; end;
  else if @stat = 'MAX' begin; set @statname = 'maximum'; end;

  /* Set SQL ON statement */
  declare @on nvarchar(4000) = '';
  select 'a.' + ltrim(rtrim(value)) + ' = b.' + ltrim(rtrim(value)) as on_state
    , row_number() over (order by value) as n
  into #temp from string_split(@by, ',')
  ;
  declare @i int = 1; 
  declare @on_total int = (select count(*) from #temp);
  while @i <= @on_total begin;
    if @i = 1 begin; set @on = (select on_state from #temp where n = @i); end;
    else begin; set @on = @on + ' and ' + (select on_state from #temp where n = @i); end;
    set @i = @i + 1;
  end;
  if @test = 'Y' begin; print(@on); end;

  /* Set SQL statements */
  declare @sql1 nvarchar(4000) = '
      select distinct ' + @by + ', ' + @stat + '(' + @var + ') as ' + @stat + '
      from ' + @ds + '
      group by ' + @by
  ;
  declare @sql2 nvarchar(4000) = '
    select distinct a.*
    into ' + @out + '
    from ' + @ds + ' a
    inner join (' + @sql1 + '
    ) b
    on ' + @on + '
    and a.' + @var + ' = b.' + @stat + '
  ';
  if @test = 'Y' begin;
    print('@sql1 = ' + @sql1);
    print('@sql2 = ' + @sql2);
  end;

  -- Execute SQL and capture affected rows
  declare @rows int = 0;
  if @test = 'N' begin;
    exec sp_executesql @sql2;
    set @rows = @@ROWCOUNT;
  end;
  print('');
  print('(' + convert(varchar, @rows) + ' records were selected, based on ' + @stat + ' of ' + @var + ', output to ' + @out + ')');
  print('(' + convert(varchar, @rows) + ' rows affected)');

END
GO

grant execute on object::[ds\cswens].SelectStat to public;


/*
-- SelectStat @ds, @by, @var, @stat, @out;
drop table if exists ##selectstat_test, ##selectstat2;
exec [ds\cswens].selectstat '[dhp\cswens].DupCheck_example', schema_name, column_id, @out = ##selectstat_test, @stat = Min;
select * from ##selectstat_test;
*/
