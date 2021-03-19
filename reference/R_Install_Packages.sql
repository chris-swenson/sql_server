declare @package nvarchar(250) = 'EpiEstim';

-- Install package 
declare @package_install nvarchar(500) = N'install.packages("' + @package + '")';
execute sp_execute_external_script @language = N'R', @script = @package_install;

-- Test packages
declare @package_test nvarchar(500) = N'library(' + @package + ')';
execute sp_execute_external_script @language = N'R', @script = @package_test;
