-- Cheat Sheet
-- [ds\cswens].RemoveChars(STRING, 'chars to remove', 'options: a = alphabet, d = digits, s = space/tab/etc, p = punctuation')
/*
Argument 1: input string, either a column name or a literal string in quotes
Argument 2: list of characters to remove, e.g., '5;_' will remove'5', ';', and '_'
Argument 3: list of options, including: 
  a = remove alphabet, 
  d = remove digits (0-9), 
  s = remove spaces/tabs/etc, 
  p = remove punctuation (including spaces, commas, etc.)
*/

-- Connect to S930-WHIOSQL1
use DeanCDR;

drop function if exists [ds\cswens].RemoveChars;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 2/11/2020
-- Description:	Replace characters in string, returns string
-- =============================================
CREATE FUNCTION [ds\cswens].RemoveChars 
(
	-- Add the parameters for the function here
	@string nvarchar(max),
  @chars nvarchar(max),
  @options nvarchar(50)
)
RETURNS nvarchar(max) AS
BEGIN
	-- Declare the return variable here
	DECLARE @Result nvarchar(max)

  -- Set up character lists 
  declare @alpha nvarchar(26) = 'abcdefghijklmnopqrstuvwxyz';
  declare @digit nvarchar(10) = '0123456789';
  declare @space nvarchar(100) = ' ' + char(9) + char(10) + char(13);
  declare @punct nvarchar(100) = ',<.>/?;:''"[{]}\|`~!@#$%^&*()-_=+';
  declare @names nvarchar(100) = '<.>/?;:"[{]}\|`~!@#$%^&*()_=+';

  -- Set final list based on input arguments
  declare @charlist nvarchar(max) = @chars;
  if lower(@options) like '%a%' set @charlist = @charlist + @alpha;
  if lower(@options) like '%d%' set @charlist = @charlist + @digit;
  if lower(@options) like '%s%' set @charlist = @charlist + @space;
  if lower(@options) like '%p%' set @charlist = @charlist + @punct;
  if lower(@options) like '%n%' set @charlist = @charlist + @names;
  declare @length int = len(@charlist);

  -- Insert statements for procedure here
  declare @i int = 1;
  declare @sql nvarchar(max) = '';
  declare @char nvarchar(1) = (select substring(@charlist, 1, 1));
  declare @newstring nvarchar(max) = @string;
  while @i <= @length begin
    set @newstring = (select replace(@newstring, @char, ''));
    set @i = @i + 1;
    set @char = (select substring(@charlist, @i, 1));
  end;

	-- Add the T-SQL statements to compute the return value here
	SELECT @Result = @newstring

	-- Return the result of the function
	RETURN @Result

END
GO

grant execute on object::[ds\cswens].RemoveChars to public;

/*
select [ds\cswens].RemoveChars('as,df_  +12;34', ';', '') as no_semi;  -- Returns: 'as,df_  +1234'
select [ds\cswens].RemoveChars('as,df_  +12;34', '_', 'a') as no_letters;  -- Returns: ',  +12;34'
select [ds\cswens].RemoveChars('as,df_  +12;34', '_', 'd') as no_numbers; -- Returns: 'as,df  +;'
select [ds\cswens].RemoveChars('as,df_  +12;34', 'f', 'p') as no_punct_or_f; -- Returns: 'asd1234'
select [ds\cswens].RemoveChars('as,df_  +12;34', '_', 's') as no_spaces; -- Returns: 'as,df+12;34'
select [ds\cswens].RemoveChars('as,df_  +12;34', '_', 'ad') as no_alphanum; -- Returns: ',  +;'
select [ds\cswens].RemoveChars('as,df_  +12;34', '_', 'adsp') as nothing; -- Returns: ''
*/

/*
select 'as,df_ +12;34' as txt into #temp; 
select [ds\cswens].RemoveChars(txt, '_', 'a') as no_letters from #temp;
select [ds\cswens].RemoveChars(txt, '_', 'd') as no_numbers from #temp;
select [ds\cswens].RemoveChars(txt, 'f', 'p') as no_punct_or_f from #temp;
select [ds\cswens].RemoveChars(txt, '_', 's') as no_spaces from #temp;
select [ds\cswens].RemoveChars(txt, '_', 'ad') as no_alphanum;
*/
