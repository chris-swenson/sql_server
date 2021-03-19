-- Basic script to test, should return column 'hello' with one row and a value of 1
EXEC sp_execute_external_script
    @language = N'R'
  , @script = N'OutputDataSet <- InputDataSet;'
  , @input_data_1 = N'SELECT 1 AS hello'
WITH RESULT SETS (([hello] int not null));
GO

-- R version
EXECUTE sp_execute_external_script @language = N'R', @script = N'print(R.version)';

-- Installed packages
EXEC sp_execute_external_script 
    @language = N'R'
  , @script = N'
myPackages <- rxInstalledPackages();
OutputDataSet <- as.data.frame(myPackages);
'
;

