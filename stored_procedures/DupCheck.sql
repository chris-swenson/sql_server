-- Cheat Sheet
-- exec DeanCDR.[dhp\cswens].dupcheck 'table_name', 'columns, by, comma', 
-- @where = 'value = 1';

-- Connect to S930-WHIOSQL1
use DeanCDR;

drop procedure if exists [ds\cswens].DupCheck;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 10/29/2019
-- Description:	Check for duplicates
-- =============================================
CREATE PROCEDURE [ds\cswens].DupCheck 
	-- Add the parameters for the stored procedure here
  @tbl varchar(257) = '',
	@col varchar(max) = '',
  @where varchar(max) = '',
  @test varchar(1) = 'N'
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  -- Insert statements for procedure here

  -- Check arguments
  if @tbl = '' begin;
    declare @msg1 varchar(100) = 'W' + 'ARNING: Please specify an input table (@tbl=, argument 1).'; 
    raiserror(@msg1, 11, 0);
    return;
  end;

  if @col = '' begin;
    declare @msg2 varchar(100) = 'W' + 'ARNING: Please specify column (@col=, argument 2). May be list: @col=''col1, col2''';
    raiserror(@msg2, 11, 0);
    return;
  end;

  declare @where_msg varchar(250) = '';
  if @where <> '' begin;
    set @where_msg = ', where ' + @where + ',';
    set @where = ' and ' + @where;
  end;
  if @test = 'Y' begin print(@where_msg) end;

  -- Split column argument
  drop table if exists #dupcheck_cols;
  select ltrim(rtrim(value)) as col, row_number() over(order by charindex(value, @col)) as n into #dupcheck_cols from string_split(@col, ',');
  declare @colcnt tinyint
  set @colcnt = (select count(*) from #dupcheck_cols);
  if @test = 'Y' begin print(@colcnt) end;

  -- Set up select, group by, order by, and on (inner join) statements
  declare @cnt tinyint = 1
  declare @sel nvarchar(max) = ''
  declare @grp nvarchar(max) = ''
  declare @ord nvarchar(max) = ''
  declare @on nvarchar(max) = ''
  declare @onvar nvarchar(max) = ''
  while @cnt <= @colcnt begin
    set @onvar = (select col from #dupcheck_cols where n = @cnt)
    if @cnt = 1 begin
      set @sel = @sel + (select col from #dupcheck_cols where n = @cnt)
      set @grp = @grp + (select col from #dupcheck_cols where n = @cnt)
      set @ord = @ord + 'a.' + (select col from #dupcheck_cols where n = @cnt)
      set @on = @on + 'a.' + @onvar + ' = ' + 'b.' + @onvar
    end;
    else begin
      set @sel = @sel + ', ' + (select col from #dupcheck_cols where n = @cnt)
      set @grp = @grp + ', ' + (select col from #dupcheck_cols where n = @cnt)
      set @ord = @ord + ', a.' + (select col from #dupcheck_cols where n = @cnt)      
      set @on = @on + ' and a.' + @onvar + ' = b.' + @onvar
    end;
    set @cnt = @cnt + 1
  end;
  if @test = 'Y' begin
    print(@sel)
    print(@grp)
    print(@ord)
    print(@on)
  end;

  -- Set up SQL to count total
  create table #dupcheck_ttl (ttl int);
  declare @ttlsub nvarchar(max);
  declare @ttlsql nvarchar(max);
  set @ttlsql = 'insert #dupcheck_ttl select count(*) from ' + @tbl + ' where 1=1 ' + @where + ' '
  --set @sql = 'select a.* from ' + @tbl + ' a inner join (' + @sub + ') b on ' + @on
  if @test = 'Y' begin; print(@ttlsql); end;
  exec sp_sqlexec @ttlsql;
  if @test = 'Y' begin; select ttl as [Total] from #dupcheck_ttl; end;

  -- Set up SQL to check for duplicates
  create table #dupcheck_dups (dups int);
  declare @sub nvarchar(max);
  declare @sql nvarchar(max);
  set @sub = 'select ' + @sel + ' from ' + @tbl + ' where 1=1 ' + @where + ' group by ' + @grp + ' having count(*) > 1'
  set @sql = 'insert #dupcheck_dups select count(*) as dups from ' + @tbl + ' a inner join (' + @sub + ') b on ' + @on
  --set @sql = 'select a.* from ' + @tbl + ' a inner join (' + @sub + ') b on ' + @on
  if @test = 'Y' begin; print(@sql); end;
  exec sp_sqlexec @sql;
  if @test = 'Y' begin; select dups as duplicates from #dupcheck_dups; end;

  -- Set up output message
  declare @ttls varchar(max);
  declare @dups varchar(max);
  declare @rate varchar(max);
  declare @msg varchar(max) = 'found in ' + @tbl + @where_msg + ' by: ' + @sel + '.';
  set @ttls = (select ltrim(rtrim(format(cast(ttl as int), 'N0'))) from #dupcheck_ttl);  
  set @dups = (select ltrim(rtrim(format(cast(dups as int), 'N0'))) from #dupcheck_dups);
  set @rate = (ltrim(rtrim(cast(round(
    ((select cast(dups as float) from #dupcheck_dups)
     / (select cast(ttl as float) from #dupcheck_ttl))
    * 100
  , 2) as varchar(25) ))));
  --print(@msg)
  print('');
  if @dups = '0' begin
    set @msg = 'NOTE: No duplicates ' + @msg;
    print(@msg)
  end;
  else begin
    set @msg = 'W' + 'ARNING: ' + @dups + ' duplicates (' + @rate + '%% of ' + @ttls + ' records) ' + @msg;
    raiserror(@msg, 11, 0)
  end;

  drop table if exists #dupcheck_cols;
  drop table if exists #dupcheck_dups;

END
GO

grant execute on object::[ds\cswens].DupCheck to public;

/*
EXEC [ds\cswens].DupCheck save_vbca_pat_mem_ids, 'member_id,ssm_patient_mrn,wi_patient_mrn';
EXEC [ds\cswens].DupCheck save_vbca_pat_mem_ids, 'member_id,ssm_patient_mrn,wi_patient_mrn', @where = 'payer_contract = ''DHP Commercial''';
*/
