if OBJECT_ID('drp..AUTOMIGRATE_Jobs') is not null 
drop table drp..AUTOMIGRATE_Jobs

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'OPS_SP_AUTOMIGRATE')
EXEC msdb.dbo.sp_delete_job @job_name=N'OPS_SP_AUTOMIGRATE', @delete_unused_schedule=1

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'OPS_SP_AUTOMIGRATE_N')
EXEC msdb.dbo.sp_delete_job @job_name=N'OPS_SP_AUTOMIGRATE_N', @delete_unused_schedule=1

IF  EXISTS (SELECT job_id FROM msdb.dbo.sysjobs_view WHERE name = N'OPS_SP_AUTOMIGRATE_Y')
EXEC msdb.dbo.sp_delete_job @job_name=N'OPS_SP_AUTOMIGRATE_Y', @delete_unused_schedule=1

IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'EdbMigration')
EXEC master.dbo.sp_dropserver @server=N'EdbMigration', @droplogins='droplogins'

