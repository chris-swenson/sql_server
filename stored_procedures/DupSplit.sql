-- Cheat Sheet
-- exec DeanCDR.[dhp\cswens].dupsplit 'table_name', 'columns, by, comma',
-- @type = D or S, @out = 'output', @sort = Y or N;

-- Connect to S930-WHIOSQL1
use DeanCDR;

drop procedure if exists [ds\cswens].DupSplit;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 10/29/2019
-- Description:	Split either singles or duplicates
-- =============================================
CREATE PROCEDURE [ds\cswens].DupSplit 
	-- Add the parameters for the stored procedure here
  @tbl varchar(257) = '',
	@col varchar(max) = '',
  @type varchar(50) = '',
  @out varchar(127) = '',
  @sort varchar(1) = 'N',
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

  /*
  if @out = '' begin;
    declare @msg3 varchar(100) = 'W' + 'ARNING: Please specify an output table (@out=, argument 4).'; 
    raiserror(@msg3, 11, 0);
    return;
  end;
  */

  -- Simplify type variable, set operator
  set @type = upper(substring(@type, 1, 1))
  declare @operator varchar(1);
  if @type = 'D' begin set @operator = '>' end;
  else if @type = 'S' begin set @operator = '=' end;
  else begin
    declare @msg4 varchar(100) = 'W' + 'ARNING: Please specify D or S for @type argument.';
    raiserror(@msg4, 11, 0);
    return;
  end;

  -- Split column argument
  drop table if exists #DupSplit_cols;
  select ltrim(rtrim(value)) as col, row_number() over(order by charindex(value, @col)) as n into #DupSplit_cols from string_split(@col, ',');
  declare @colcnt tinyint
  set @colcnt = (select count(*) from #DupSplit_cols);
  if @test = 'Y' begin print(@colcnt) end;

  -- Set up select, group by, order by, and on (inner join) statements
  declare @cnt tinyint = 1
  declare @sel nvarchar(max) = ''
  declare @grp nvarchar(max) = ''
  declare @ord nvarchar(max) = ''
  declare @on nvarchar(max) = ''
  declare @onvar nvarchar(max) = ''
  while @cnt <= @colcnt begin
    set @onvar = (select col from #DupSplit_cols where n = @cnt)
    if @cnt = 1 begin
      set @sel = @sel + (select col from #DupSplit_cols where n = @cnt)
      set @grp = @grp + (select col from #DupSplit_cols where n = @cnt)
      set @ord = @ord + 'a.' + (select col from #DupSplit_cols where n = @cnt)
      set @on = @on + 'a.' + @onvar + ' = ' + 'b.' + @onvar
    end;
    else begin
      set @sel = @sel + ', ' + (select col from #DupSplit_cols where n = @cnt)
      set @grp = @grp + ', ' + (select col from #DupSplit_cols where n = @cnt)
      set @ord = @ord + ', a.' + (select col from #DupSplit_cols where n = @cnt)      
      set @on = @on + ' and a.' + @onvar + ' = b.' + @onvar
    end;
    set @cnt = @cnt + 1
  end;
  if @sort = 'N' begin set @ord = '' end;
  else begin set @ord = ' order by ' + @ord end;
  if @test = 'Y' begin
    print(@sel)
    print(@grp)
    print(@ord)
    print(@on)
  end;

  -- Set up SQL to check for duplicates
  declare @sql nvarchar(max) = ''
  declare @sub nvarchar(max) = 'select ' + @sel + ' from ' + @tbl + ' group by ' + @grp + ' having count(*) ' + @operator + ' 1';
  if @out <> '' begin;
    set @sql = 'select a.* into ' + @out + ' from ' + @tbl + ' a inner join (' + @sub + ') b on ' + @on + @ord;
  end;
  else begin;
    set @sql = 'select a.* from ' + @tbl + ' a inner join (' + @sub + ') b on ' + @on + @ord;
  end;
  if @test = 'Y' begin print(@sql) end;

  -- Execute SQL and capture affected rows
  declare @rows int = 0;
  exec sp_executesql @sql
  set @rows = @@ROWCOUNT;
  print('')
  print('(' + convert(varchar, @rows) + ' rows affected)')

END
GO

grant execute on object::[ds\cswens].DupSplit to public;

/*
drop table if exists ##duplicates;
exec [ds\cswens].DupSplit save_vbca_pat_mem_ids, 'member_id,ssm_patient_mrn,wi_patient_mrn', @type = D, @out = ##duplicates, @sort = Y;
select * from ##duplicates;

drop table if exists ##singles;
exec [ds\cswens].DupSplit save_vbca_pat_mem_ids, 'member_id,ssm_patient_mrn,wi_patient_mrn', @type = S, @out = ##singles, @sort = N;
select top 10 * from ##singles;
*/
