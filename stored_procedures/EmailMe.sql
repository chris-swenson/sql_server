use DeanCDR; 

drop procedure if exists [ds\cswens].EmailMe;

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Chris Swenson
-- Create date: 3/5/2020
-- Description:	Send an email to myself
-- =============================================
CREATE PROCEDURE [ds\cswens].EmailMe @msg varchar(250) = '' AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

  if @msg <> '' begin;
    set @msg = 'SQL_NOTIFY: ' + @msg + ' (' + (select @@servername) + ')';
  end;
  else begin;
    set @msg = 'SQL_NOTIFY' + ' (' + (select @@servername) + ')';
  end;

  declare @user varchar(500) = user;
  declare @myemail varchar(500) = '';
  declare @sql nvarchar(500) = 'select @myemail = email from DeanCDR.dbo.User_Email where name = @user';
  exec sp_executesql @sql
    , N'@user varchar(500), @myemail varchar(500) output'
    , @user = @user
    , @myemail = @myemail output
  ;

  exec msdb.dbo.sp_send_dbmail
      @recipients = @myemail
    , @subject = @msg
  ;

END
GO

grant execute on object::[ds\cswens].EmailMe to public;

--exec [ds\cswens].emailme;
--exec [ds\cswens].emailme 'hey what''s up?';

