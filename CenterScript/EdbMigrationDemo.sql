/*
Insert into MigrationPlan(PlanExecTime,SourceEDBA,SourceVIP,TargetVIP,SourceVIPWeb,TargetVIPWeb,SourceSerAdd,TargetSerAdd,PlanType,NetType,isUseDiff)
values('2016-10-25 14:00:20','edb_a81620','vip208.edb01.com','vip128.edb01.com','http://192.168.1.208','http://192.168.1.128','http://vip208.edb01.com','http://vip128.edb01.com','整机迁移','公网',1)
Insert into MigrationPlan(PlanExecTime,SourceEDBA,SourceVIP,TargetVIP,SourceVIPWeb,TargetVIPWeb,SourceSerAdd,TargetSerAdd,PlanType,NetType,isUseDiff)
values('2016-11-16 10:00:20','edb_a81620','vip128.edb01.com','vip208.edb01.com','http://192.168.1.128','http://192.168.1.208','http://vip128.edb01.com','http://vip208.edb01.com','整机迁移','公网',1)
*/

Truncate table MigrationCommand

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.SOURCE','MIGRATE.INIT',NULL,'MIGRATE.CONFIG',10,'源VIP整机迁移初始化',
'if Not Exists(Select Top 1 1 From @@MIGRATESEVER.[dbo].[MigrationEDB] where Planid=@@PlanID)
Begin 
	if ''@@PlanType''=''整机迁移'' or ''@@PlanType''=''升级独享''
	begin   
		Insert into @@MIGRATESEVER.[dbo].[MigrationEDB] 
		(PlanID,SourceVIP,TargetVIP,SourceEDB)
		Select PlanID,SourceVIP,TargetVIP,SourceEDB=''wfp''
		From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and DB_ID(''wfp'') is not null

		Insert into @@MIGRATESEVER.[dbo].[MigrationEDB] 
		(PlanID,SourceVIP,TargetVIP,SourceEDB)
		Select PlanID,SourceVIP,TargetVIP,SourceEDB=''alisoft''
		From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and DB_ID(''alisoft'') is not null
	end

	declare @SourceEDBA varchar(255)
	Select @SourceEDBA=SourceEDBA From @@MIGRATESEVER.[dbo].[MigrationPlan] where Planid=@@PlanID
	set @SourceEDBA=isnull(@SourceEDBA,'''')
	Insert into @@MIGRATESEVER.[dbo].[MigrationEDB] 
	(PlanID,SourceVIP,TargetVIP,SourceEDB)
	Select PlanID,SourceVIP,TargetVIP,SourceEDB=name
	From @@MIGRATESEVER.[dbo].[MigrationPlan] 
	inner join master..sysdatabases on name like ''Edb_a_____'' or name like ''edb_a______dw''
	Where PlanID=@@PlanID and (charindex(replace(name,''_dw'',''''),@SourceEDBA)>0 or @SourceEDBA='''')
	order by name
End')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.SOURCE','MIGRATE.CONFIG',NULL,'MIGRATE.CHECK',20,'源VIP环境配置初始化',
'Update @@MIGRATESEVER.[dbo].[MigrationPlan] 
Set SourceEDBVersion = (select top 1 ver from wfp..wfpversion where type <> ''Client'' order by UpdateTime desc)
Where PlanID=@@PlanID

create table #ixeddrives(drive varchar(100), MB int)
insert into #ixeddrives
Exec master.dbo.xp_fixeddrives
update @@MIGRATESEVER.[dbo].[MigrationPlan] 
set SourceFreeDisk = (select MB from #ixeddrives where drive = ''D'')
Where PlanID=@@PlanID

declare @edbid int,@sourceEDB varchar(255),@sql varchar(8000);
select @edbid=min(edbid) from @@MIGRATESEVER.[dbo].[MigrationEDB] where PlanID=@@PlanID
while isnull(@edbid ,0)>0
begin
	select @sourceEDB=sourceEDB from @@MIGRATESEVER.[dbo].[MigrationEDB] where edbid=@edbid
	set @sql = ''update @@MIGRATESEVER.[dbo].[MigrationEDB] set SourceDBSize = (SELECT sum(cast(size as decimal(10,2)) * 8192 / 1048576) FROM ''+@sourceEDB+''.sys.sysfiles) where edbid=''+convert(varchar(255),@edbid)
	print @sql
	Exec(@sql)
	
	select @edbid=min(edbid) from @@MIGRATESEVER.[dbo].[MigrationEDB] where PlanID=@@PlanID and edbid>@edbid
end
')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.TARGET','MIGRATE.INIT',NULL,'MIGRATE.CHECK',10,'目标VIP环境配置初始化',
'Update @@MIGRATESEVER.[dbo].[MigrationPlan] 
Set TargetEDBVersion = (select top 1 ver from wfp..wfpversion where type <> ''Client'' order by UpdateTime desc)
Where PlanID=@@PlanID

create table #ixeddrives(drive varchar(100), MB int)
insert into #ixeddrives
Exec master.dbo.xp_fixeddrives
update @@MIGRATESEVER.[dbo].[MigrationPlan] 
set TargetFreeDisk = (select MB from #ixeddrives where drive = ''D'')
Where PlanID=@@PlanID

declare @ServiceUrl as varchar(1000)
Declare @Object as Int
Declare @ResponseText as Varchar(8000)
set @ServiceUrl = ''@@SourceVIPWeb/robots.txt''
Exec sp_OACreate ''MSXML2.XMLHTTP'', @Object OUT;
Exec sp_OAMethod @Object, ''open'', NULL, ''get'',@ServiceUrl,''false''
Exec sp_OAMethod @Object, ''send''
Exec sp_OAMethod @Object, ''responseText'', @ResponseText OUTPUT
if isnull(@ResponseText,'''') <> ''''
update @@MIGRATESEVER.[dbo].[MigrationPlan] 
set isLinked = 1
Where PlanID=@@PlanID

')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.ALL','MIGRATE.CHECK',NULL,NULL,30,'检查整体环境是否满足迁移条件',
'if exists (Select * From @@MIGRATESEVER.[dbo].[MigrationPlan] 
Where PlanID=@@PlanID and SourceStatus like ''MIGRATE.CHECK%'' and TargetStatus like ''MIGRATE.CHECK%'')
Begin
	Update p Set PlanCheckResult = '''',SourceDBSizeTotal = (Select Sum(SourceDBSize) From @@MIGRATESEVER.[dbo].[MigrationEDB] e Where e.PlanID=p.PlanID)
	From @@MIGRATESEVER.[dbo].[MigrationPlan] p Where p.PlanID=@@PlanID
	/*
	if exists (Select * From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and isnull(SourceEDBVersion,'''')<>isnull(TargetEDBVersion,''''))
	Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set PlanCheckResult = PlanCheckResult+''E店宝版本不一致;'' Where PlanID=@@PlanID
	*/
	if exists (Select * From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and (ISNULL(SourceVIPWeb,'''')='''' or ISNULL(TargetVIPWeb,'''')=''''))
	Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set PlanCheckResult = PlanCheckResult+''WEB地址未设置;'' Where PlanID=@@PlanID

	if exists (Select * From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and (ISNULL(SourceSerAdd,'''')='''' or ISNULL(TargetSerAdd,'''')=''''))
	Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set PlanCheckResult = PlanCheckResult+''SerAdd地址未设置;'' Where PlanID=@@PlanID

	if exists (Select * From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and ISNULL(SourceFreeDisk,0) < ISNULL(SourceDBSizeTotal,0)/2 )
	Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set PlanCheckResult = PlanCheckResult+''源服务器空间不足;'' Where PlanID=@@PlanID

	if exists (Select * From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and ISNULL(TargetFreeDisk,0) < ISNULL(SourceDBSizeTotal,0)*2 )
	Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set PlanCheckResult = PlanCheckResult+''目标服务器空间不足;'' Where PlanID=@@PlanID

	if exists (Select * From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and ISNULL(isLinked,0) <> 1 )
	Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set PlanCheckResult = PlanCheckResult+''目标服务器无法连接原服务器web;'' Where PlanID=@@PlanID
	
	if (''@@PlanType''=''整机迁移'' or ''@@PlanType''=''升级独享'') and exists (select * from master.sys.databases where name like ''edb_a_____%'') 
	and exists (Select * from @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and TargetVIP=''@@ExecVIP'')
		Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set PlanCheckResult = PlanCheckResult+''目标服务器上不能有主账户;'' Where PlanID=@@PlanID
	if exists (Select * From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and Isnull(PlanCheckResult,'''')='''')
	Begin
		Print ''检查符合''
		if exists (Select top 1 1 From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID and isnull(isUseDiff,0)=1)
			Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set SourceStatus = ''MIGRATE.MOVEDB'',TargetStatus = ''MIGRATE.MOVEDB'' 
			Where PlanID=@@PlanID
		Else
			Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set SourceStatus = ''MIGRATE.ALLOW'',TargetStatus = ''MIGRATE.ALLOW'' 
			Where PlanID=@@PlanID
		
		Update @@MIGRATESEVER.[dbo].[MigrationEDB] Set SourceStatus = ''DB.BACKUP'',TargetStatus = ''DB.LOADDB'' 
		Where PlanID=@@PlanID
	End
	Else 
	Begin
		Insert Into @@MIGRATESEVER.[dbo].[MigrationLog](PlanID,EdbID,ExecVIP,ExecEdb,PlanStatus,EdbStatus,CommandLine,CommandLog,[guid])
		Select PlanID,Null,''@@ExecVIP'',Null,@@PlanStatus,Null,Null,''检查结果:''+PlanCheckResult,''@@LogGuid''
		From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID
		
		Print ''检查不符合(设置重新检查)''
		Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set SourceStatus = ''MIGRATE.CONFIG'',TargetStatus = ''MIGRATE.INIT'' 
		Where PlanID=@@PlanID
	End
End
Else
	Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set @@PlanStatus = ''MIGRATE.CHECK'' Where PlanID=@@PlanID and @@PlanStatus = ''MIGRATE.CHECK.DOING''
')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.SOURCE','MIGRATE.ALLOW',NULL,'MIGRATE.ZIPXLS',40,'启用cmdshell,禁用服务',
'EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1 
RECONFIGURE

if ''@@PlanType''<>''整机迁移'' and ''@@PlanType''<>''升级独享''
exec drp..SP_MIGRATE_User @@PlanID,1

if ''@@PlanType''=''整机迁移''
begin
declare @serviceid int,@servicename varchar(255),@execname varchar(255),@cmd varchar(8000);
select @serviceid=min(serviceid) from @@MIGRATESEVER.[dbo].[ServiceList]
while isnull(@serviceid ,0)>0
begin
	select @servicename=servicename,@execname=execname from @@MIGRATESEVER.[dbo].[ServiceList] where serviceid=@serviceid
	set @cmd = ''sc config ''+@servicename+'' start= disabled''
	Exec xp_cmdshell @cmd
	set @cmd = ''net stop ''+@servicename
	Exec xp_cmdshell @cmd
	set @cmd = ''taskkill /f /im ''+@execname
	Exec xp_cmdshell @cmd
	select @serviceid=min(serviceid) from @@MIGRATESEVER.[dbo].[ServiceList] where serviceid>@serviceid
end

if OBJECT_ID(''tempdb..#job_run_status'') is not null drop table #job_run_status
if OBJECT_ID(''tempdb..#AUTOMIGRATE_Jobs'') is not null drop table #AUTOMIGRATE_Jobs
CREATE TABLE #job_run_status
    (
      job_id UNIQUEIDENTIFIER NOT NULL ,
      last_run_date INT NOT NULL ,
      last_run_time INT NOT NULL ,
      next_run_date INT NOT NULL ,
      next_run_time INT NOT NULL ,
      next_run_schedule_id INT NOT NULL ,
      requested_to_run INT NOT NULL ,
      request_source INT NOT NULL ,
      request_source_id sysname COLLATE DATABASE_DEFAULT
                                NULL ,
      running INT NOT NULL ,
      current_step INT NOT NULL ,
      current_retry_attempt INT NOT NULL ,
      job_state INT NOT NULL
    );
insert into #job_run_status
execute master.dbo.xp_sqlagent_enum_jobs 1, ''sa''

select j.job_id,name = j.name
      ,running = s.running
      ,enabled = j.enabled
into #AUTOMIGRATE_Jobs
  from #job_run_status s
          inner join msdb.dbo.sysjobs j
    on s.job_id = j.job_id
    where name not like ''OPS_SP_AUTOMIGRATE%''
    
if OBJECT_ID(''drp..AUTOMIGRATE_Jobs'') is null
Select * into drp..AUTOMIGRATE_Jobs From #AUTOMIGRATE_Jobs
    
DECLARE @jobname varchar(255),@running int , @enabled int , @SQL_STR varchar(8000)
DECLARE cur_db CURSOR FOR
select name,running,enabled from #AUTOMIGRATE_Jobs 
OPEN cur_db 
FETCH NEXT FROM cur_db 
INTO @jobname,@running,@enabled
WHILE @@FETCH_STATUS = 0 
BEGIN
	if @running = 1
		EXEC   msdb..sp_stop_job   @job_name = @jobname
	if @enabled = 1
		EXEC msdb.dbo.sp_update_job @job_name=@jobname, @enabled=0
	FETCH NEXT FROM cur_db INTO @jobname,@running,@enabled 
END 
CLOSE cur_db 
DEALLOCATE cur_db

end
')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.TARGET','MIGRATE.ALLOW',NULL,'MIGRATE.LOADXLS',40,'启用cmdshell,开启防火墙',
'EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1 
RECONFIGURE;

exec xp_cmdshell ''netsh advfirewall firewall delete rule name="axel-out"'';
exec xp_cmdshell ''netsh advfirewall firewall add rule name="axel-out" dir=out program="D:\tool\Axel2.4\axel.exe"  action=allow'';
exec xp_cmdshell ''netsh advfirewall firewall set rule name="axel-out" dir=out new enable=yes'';

if ''@@PlanType''=''整机迁移''
begin
declare @serviceid int,@servicename varchar(255),@execname varchar(255),@cmd varchar(8000);
select @serviceid=min(serviceid) from @@MIGRATESEVER.[dbo].[ServiceList]
while isnull(@serviceid ,0)>0
begin
	select @servicename=servicename,@execname=execname from @@MIGRATESEVER.[dbo].[ServiceList] where serviceid=@serviceid
	set @cmd = ''sc config ''+@servicename+'' start= disabled''
	Exec xp_cmdshell @cmd
	set @cmd = ''net stop ''+@servicename
	Exec xp_cmdshell @cmd
	set @cmd = ''taskkill /f /im ''+@execname
	Exec xp_cmdshell @cmd
	select @serviceid=min(serviceid) from @@MIGRATESEVER.[dbo].[ServiceList] where serviceid>@serviceid
end

if OBJECT_ID(''tempdb..#job_run_status'') is not null drop table #job_run_status
if OBJECT_ID(''tempdb..#AUTOMIGRATE_Jobs'') is not null drop table #AUTOMIGRATE_Jobs
CREATE TABLE #job_run_status
    (
      job_id UNIQUEIDENTIFIER NOT NULL ,
      last_run_date INT NOT NULL ,
      last_run_time INT NOT NULL ,
      next_run_date INT NOT NULL ,
      next_run_time INT NOT NULL ,
      next_run_schedule_id INT NOT NULL ,
      requested_to_run INT NOT NULL ,
      request_source INT NOT NULL ,
      request_source_id sysname COLLATE DATABASE_DEFAULT
                                NULL ,
      running INT NOT NULL ,
      current_step INT NOT NULL ,
      current_retry_attempt INT NOT NULL ,
      job_state INT NOT NULL
    );
insert into #job_run_status
execute master.dbo.xp_sqlagent_enum_jobs 1, ''sa''

select j.job_id,name = j.name
      ,running = s.running
      ,enabled = j.enabled
into #AUTOMIGRATE_Jobs
  from #job_run_status s
          inner join msdb.dbo.sysjobs j
    on s.job_id = j.job_id
    where name not like ''OPS_SP_AUTOMIGRATE%''
    
if OBJECT_ID(''drp..AUTOMIGRATE_Jobs'') is null
Select * into drp..AUTOMIGRATE_Jobs From #AUTOMIGRATE_Jobs
    
DECLARE @jobname varchar(255),@running int , @enabled int , @SQL_STR varchar(8000)
DECLARE cur_db CURSOR FOR
select name,running,enabled from #AUTOMIGRATE_Jobs 
OPEN cur_db 
FETCH NEXT FROM cur_db 
INTO @jobname,@running,@enabled
WHILE @@FETCH_STATUS = 0 
BEGIN
	if @running = 1
		EXEC   msdb..sp_stop_job   @job_name = @jobname
	if @enabled = 1
		EXEC msdb.dbo.sp_update_job @job_name=@jobname, @enabled=0
	FETCH NEXT FROM cur_db INTO @jobname,@running,@enabled 
END 
CLOSE cur_db 
DEALLOCATE cur_db

end
')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.SOURCE','MIGRATE.ZIPXLS',NULL,'MIGRATE.MOVEDB',50,'拷贝压缩自定义模板',
'EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1 
RECONFIGURE;
exec master.dbo.xp_cmdshell ''if exist D:\copyxls (del /s /q D:\copyxls\* 1>nul) else (md D:\copyxls\ 1>nul)'';
exec master.dbo.xp_cmdshell ''if exist D:\copyxls2 (del /s /q D:\copyxls2\* 1>nul) else (md D:\copyxls2\ 1>nul)'';
exec master.dbo.xp_cmdshell ''if exist D:\webhome\saas_alisoft\backup\wfp_program\copyxls.rar del /q D:\webhome\saas_alisoft\backup\wfp_program\copyxls.rar 1>nul)'';
exec master.dbo.xp_cmdshell ''copy /y D:\webhome\saas_alisoft\backup\wfp_program\uploadfile\自定* D:\copyxls2\ 1>nul'';
select cast(null as varchar(6000)) a into #a;
insert #a exec master.dbo.xp_cmdshell ''DIR /B D:\copyxls2\*自定*'';
select * from #a;
select SourceEDB into #b From @@MIGRATESEVER.[dbo].[MigrationEDB] Where PlanID = @@PlanID;
SELECT  ''copy D:\copyxls2\''+ substring(b.a,charindex(''自定'',b.a),len(b.a)) +'' D:\copyxls\''  a into  #模板列表 
FROM WFP..WFPSYS_USER a join  #a b on  b.a  like ''%''+a.objname+''%''
WHERE DBSWITCH in (SELECT DBSWITCH FROM WFP..WFPSYS_USER WHERE OBJNAME in (Select SourceEDB From #b));
exec wfp..wfp_sys_runsql ''select ''''exec master.dbo.xp_cmdshell ''''''''''''+ a +'''''''''''''''' from #模板列表'';
update @@MIGRATESEVER.[dbo].[MigrationPlan] set SourceXLS = (Select Count(*) From #模板列表) Where PlanID = @@PlanID;
drop table  #模板列表,#a,#b;
exec master.dbo.xp_cmdshell''D:\tool\rar\rar -m2 -o+ a D:\webhome\saas_alisoft\backup\wfp_program\copyxls.rar D:\copyxls\'';')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.TARGET','MIGRATE.LOADXLS',NULL,'MIGRATE.MOVEDB',60,'下载解压自定义模板',
'EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1 
RECONFIGURE;

if ''@@PlanType''<>''整机迁移'' and ''@@PlanType''<>''升级独享''
exec drp..SP_MIGRATE_User @@PlanID,0

/*Select * From @@MIGRATESEVER.[dbo].[MigrationLog] Where PlanID=@@PlanID And PlanStatus=''MIGRATE.ZIPXLS.DONE''*/
if Exists(Select * From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID=@@PlanID And SourceStatus=''MIGRATE.MOVEDB'')
Begin
	exec master.dbo.xp_cmdshell ''if exist D:\temp\copyxls.rar del /f /q D:\temp\copyxls.rar'';
	exec master.dbo.xp_cmdshell ''del /f /q D:\copyxls\* 1>nul'';
	exec master.dbo.xp_cmdshell ''D:\tool\Axel2.4\axel.exe -n 5 -o D:\temp\ @@SourceVIPWeb/copyxls.rar'';
	exec master.dbo.xp_cmdshell ''D:\tool\rar\rar x -o+ D:\temp\copyxls.rar D:\'';
	exec master.dbo.xp_cmdshell ''copy /Y D:\copyxls\* D:\webhome\saas_alisoft\backup\wfp_program\uploadfile\'';
	exec master.dbo.xp_cmdshell ''echo y|cacls D:\webhome\saas_alisoft\backup\wfp_program\uploadfile\自定* /t /e /p everyone:f 1>nul'';
	exec master.dbo.xp_cmdshell ''del /f /q D:\temp\copyxls.rar 1>nul'';
	select cast(null as varchar(6000)) a into #a;
	insert #a exec master.dbo.xp_cmdshell ''DIR /B D:\copyxls\*'';
	if exists(Select * From @@MIGRATESEVER.[dbo].[MigrationPlan] Where PlanID = @@PlanID and isnull(SourceXLS,0) > (Select Count(*) From #a))
	Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set TargetStatus=''MIGRATE.LOADXLS'' Where PlanID = @@PlanID
	exec master.dbo.xp_cmdshell ''del /f /q D:\copyxls\* 1>nul'';
End
else
Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set TargetStatus = ''MIGRATE.LOADXLS'' 
Where PlanID=@@PlanID;')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.SOURCE','MIGRATE.MOVEDB','DB.BACKUP','DB.BACKUPED',70,'打包数据库',
'EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1 
RECONFIGURE

declare @UseDiff int,@BackupDiff int
Select @UseDiff=isnull(isUseDiff,0) From @@MIGRATESEVER.[dbo].[MigrationPlan] where PlanID = @@PlanID
Select @BackupDiff=isnull(isBackupDiff,0) From @@MIGRATESEVER.[dbo].[MigrationEDB] where edbid = @@edbid
if db_id(''@@ExecEdb'') is not null
begin
	exec master..xp_cmdshell ''if exist D:\webhome\saas_alisoft\backup\wfp_program\@@ExecEdb.rar del /q D:\webhome\saas_alisoft\backup\wfp_program\@@ExecEdb.rar''
	if @BackupDiff = 0
		backup database @@ExecEdb to disk = ''D:\webhome\saas_alisoft\backup\wfp_program\@@ExecEdb.rar''  with compression
	else
		backup database @@ExecEdb to disk = ''D:\webhome\saas_alisoft\backup\wfp_program\@@ExecEdb.rar''  with DIFFERENTIAL,compression
		
	waitfor delay ''00:00:03''
	DECLARE @filesize bigint;
	DECLARE @obj INT ,@file INT;
	EXEC sp_OACreate ''Scripting.FileSystemObject'', @obj OUTPUT;
	EXEC sp_OAMethod @obj, ''GetFile'', @file OUTPUT, ''D:\webhome\saas_alisoft\backup\wfp_program\@@ExecEdb.rar'';
	EXEC sp_OAGetProperty @file, ''Size'', @filesize OUTPUT;
		
	if @BackupDiff = 0
		Update @@MIGRATESEVER.[dbo].[MigrationEDB] Set ZIPDbSize = @filesize Where edbid = @@edbid
	Else
		Update @@MIGRATESEVER.[dbo].[MigrationEDB] Set ZIPDiffSize = @filesize Where edbid = @@edbid

	if ''@@ExecEdb''<>''wfp'' and ''@@ExecEdb''<>''alisoft'' and (@UseDiff=0 or @BackupDiff=1) 
	Begin
		ALTER DATABASE [@@ExecEdb] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
		EXEC master.dbo.sp_detach_db @dbname = N''@@ExecEdb''
	End
end')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.TARGET','MIGRATE.MOVEDB','DB.LOADDB','DB.RESTORE',80,'下载数据库',
'EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1 
RECONFIGURE

exec xp_cmdshell ''netsh advfirewall firewall delete rule name="axel-out"'';
exec xp_cmdshell ''netsh advfirewall firewall add rule name="axel-out" dir=out program="D:\tool\Axel2.4\axel.exe"  action=allow'';
exec xp_cmdshell ''netsh advfirewall firewall set rule name="axel-out" dir=out new enable=yes'';

if Exists(Select * From @@MIGRATESEVER.[dbo].[MigrationEDB] Where EdbID=@@EdbID And SourceStatus=''DB.BACKUPED'')
Begin
	exec master.dbo.xp_cmdshell ''if exist D:\webhome\saas_alisoft\usrdbs\@@ExecEdb.rar del /q D:\webhome\saas_alisoft\usrdbs\@@ExecEdb.rar''
	exec master.dbo.xp_cmdshell ''D:\tool\Axel2.4\axel.exe -n 5 -o D:\webhome\saas_alisoft\usrdbs\ @@SourceVIPWeb/@@ExecEdb.rar''
	/* exec master.dbo.xp_cmdshell ''D:\tool\wget\wget.exe -PD:\webhome\saas_alisoft\usrdbs\ @@SourceVIPWeb/@@ExecEdb.rar'' */
	waitfor delay ''00:00:03''

	/*DECLARE @filesize bigint;
	DECLARE @obj INT ,@file INT;
	EXEC sp_OACreate ''Scripting.FileSystemObject'', @obj OUTPUT;
	EXEC sp_OAMethod @obj, ''GetFile'', @file OUTPUT, ''D:\webhome\saas_alisoft\usrdbs\@@ExecEdb.rar'';
	EXEC sp_OAGetProperty @file, ''Size'', @filesize OUTPUT;
	if (select ZIPDbSize from @@MIGRATESEVER.[dbo].[MigrationEDB] where EdbID=@@EdbID) <> @filesize
	Update @@MIGRATESEVER.[dbo].[MigrationEDB] Set TargetStatus = ''DB.LOADDB'' 
	Where EdbID=@@EdbID*/
End
else
	Update @@MIGRATESEVER.[dbo].[MigrationEDB] Set TargetStatus = ''DB.LOADDB'' 
	Where EdbID=@@EdbID;')

--'DB.RESTORED'
Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.TARGET','MIGRATE.MOVEDB','DB.RESTORE','DB.RESTORED',90,'还原数据库',
'EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1 
RECONFIGURE

declare @UseDiff int,@BackupDiff int
Select @UseDiff=isnull(isUseDiff,0) From @@MIGRATESEVER.[dbo].[MigrationPlan] where PlanID = @@PlanID
Select @BackupDiff=isnull(isBackupDiff,0) From @@MIGRATESEVER.[dbo].[MigrationEDB] where edbid = @@edbid

/*还原失败的,删除失败库,差异还原失败怎么办？？*/
if db_id(''@@ExecEdb'') is not null and (select state from sys.databases where name = ''@@ExecEdb'') =1 and @BackupDiff = 0
begin
	EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N''@@ExecEdb''
	DROP DATABASE [@@ExecEdb]
end

if ''@@ExecEdb''=''wfp'' or ''@@ExecEdb''=''alisoft''
Begin
	if db_id(''@@ExecEdb'') is not null and @BackupDiff = 0
	begin
	ALTER DATABASE [@@ExecEdb] SET  SINGLE_USER WITH ROLLBACK IMMEDIATE
	EXEC master.dbo.sp_detach_db @dbname = N''@@ExecEdb''
	waitfor delay ''00:00:03''

	exec master.dbo.xp_cmdshell ''md D:\webhome\saas_alisoft\data\old''
	exec master.dbo.xp_cmdshell ''move /y D:\webhome\saas_alisoft\data\@@ExecEdb* D:\webhome\saas_alisoft\data\old''
	waitfor delay ''00:00:03''
	end
End
Else
Begin
	if ''@@ExecEdb'' like ''edb_a_____''
	begin
	exec master.dbo.xp_cmdshell ''md D:\webhome\saas_alisoft\usrdbs\@@ExecEdb''
	end
End
if object_id(''tempdb..#filelistinfo'') is not null drop table #filelistinfo
	create table #filelistinfo
	(
	LogicalName nvarchar(128) null,
	PhysicalName nvarchar(260) null,
	Type char(1) null,
	FileGroupName nvarchar(128) null,
	FileSize bigint null ,
	FileMaxSize Bigint null,
	FileId bigint,
	CreateLSN numeric(25,0),
	DropLSN numeric(25,0) NULL,
	UniqueID uniqueidentifier,
	ReadOnlyLSN numeric(25,0) NULL,
	ReadWriteLSN numeric(25,0) NULL,
	BackupSizeInBytes bigint,
	SourceBlockSize int,
	FileGroupID int,
	LogGroupGUID uniqueidentifier NULL,
	DifferentialBaseLSN numeric(25,0) NULL,
	DifferentialBaseGUID uniqueidentifier,
	IsReadOnly bit,
	IsPresent bit,
	TDEThumbprint varbinary(32)
	)
	declare @filelistSQL varchar(8000),@D_name varchar(255),@L_name varchar(255),@D_PhysicalName varchar(8000),@L_PhysicalName varchar(8000),@sql varchar(8000)
	INSERT into #filelistinfo
	exec (''RESTORE filelistonly from disk =''''D:\webhome\saas_alisoft\usrdbs\@@ExecEdb.rar'''''')
	select @D_name = LogicalName,@D_PhysicalName = PhysicalName from #filelistinfo where type =''D''
	select @L_name = LogicalName,@L_PhysicalName = PhysicalName from #filelistinfo where type =''L''

	if @BackupDiff=0
	set @sql = ''RESTORE DATABASE [@@ExecEdb] FROM  DISK = N''''D:\webhome\saas_alisoft\usrdbs\@@ExecEdb.rar'''' WITH  FILE = 1,
	MOVE N''''''+@D_name+'''''' TO N''''''+@D_PhysicalName+'''''',
	MOVE N''''''+@L_name+'''''' TO N''''''+@L_PhysicalName+'''''',  NOUNLOAD,  STATS = 10, Replace
	'' + case when @UseDiff=1 then '',NORECOVERY;'' else '';'' end
	else
	set @sql = ''RESTORE DATABASE [@@ExecEdb] FROM  DISK = N''''D:\webhome\saas_alisoft\usrdbs\@@ExecEdb.rar'''' WITH  FILE = 1, NOUNLOAD,STATS = 10,RECOVERY;''
	print @sql
	exec (@sql)

if db_id(''@@ExecEdb'') is not null
begin
exec master.dbo.xp_cmdshell ''del /f /q D:\webhome\saas_alisoft\usrdbs\@@ExecEdb.rar''

Update @@MIGRATESEVER.[dbo].[MigrationEDB] set TargetStatus=''DB.RESTORED'',isBackupDiff=isnull(isBackupDiff,0)+1 Where EdbID=@@EdbID

if @UseDiff = 1 
Begin
	declare @i1 int,@i2 int
	Select @i1=Count(*) From @@MIGRATESEVER.[dbo].[MigrationEDB] Where PlanID=@@PlanID
	Select @i2=Count(*) From @@MIGRATESEVER.[dbo].[MigrationEDB] Where PlanID=@@PlanID and ISNULL(TargetStatus,'''')=''DB.RESTORED'' and isnull(isBackupDiff,0)=1
	if @i1=@i2
	begin
		Update @@MIGRATESEVER.[dbo].[MigrationPlan] Set SourceStatus = ''MIGRATE.ALLOW'',TargetStatus = ''MIGRATE.ALLOW'' Where PlanID=@@PlanID
		Update @@MIGRATESEVER.[dbo].[MigrationEDB] Set SourceStatus = ''DB.BACKUP'',TargetStatus = ''DB.LOADDB'' Where PlanID=@@PlanID
	end
	
	Select @i2=Count(*) From @@MIGRATESEVER.[dbo].[MigrationEDB] Where PlanID=@@PlanID and ISNULL(TargetStatus,'''')=''DB.RESTORED'' and isnull(isBackupDiff,0)=2
	if  @i1=@i2
		Update @@MIGRATESEVER.[dbo].[MigrationEDB] set SourceStatus=''DB.DETACH'' Where PlanID=@@PlanID
End

if (@UseDiff = 0 and not exists (Select * From @@MIGRATESEVER.[dbo].[MigrationEDB] Where PlanID=@@PlanID And ISNULL(TargetStatus,'''')<>''DB.RESTORED''))
	Update @@MIGRATESEVER.[dbo].[MigrationEDB] set SourceStatus=''DB.DETACH'' Where PlanID=@@PlanID

end
else
Update @@MIGRATESEVER.[dbo].[MigrationEDB] set TargetStatus=''DB.RESTOR'' Where EdbID=@@EdbID
')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.SOURCE','MIGRATE.MOVEDB','DB.DETACH','DB.DETACHED',100,'分离备份源数据库,删除RAR文件',
'EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1 
RECONFIGURE
if ''@@ExecEdb''<>''wfp'' and ''@@ExecEdb''<>''alisoft''
Begin
	exec master.dbo.xp_cmdshell ''if not exist D:\webhome\saas_alisoft\usrdbs\old (md D:\webhome\saas_alisoft\usrdbs\old)''
	exec master.dbo.xp_cmdshell ''del /q D:\webhome\saas_alisoft\backup\wfp_program\@@ExecEdb.rar''
	declare @dbname varchar(255),@cmd varchar(8000)
	set @dbname = replace(''@@ExecEdb'',''_dw'','''')
	set @cmd = ''move /y D:\webhome\saas_alisoft\usrdbs\''+@dbname+'' D:\webhome\saas_alisoft\usrdbs\old\''+@dbname
	if not exists(Select * from sys.databases where name like @dbname + ''%'')
	exec master.dbo.xp_cmdshell @cmd
End
else
begin
	exec master.dbo.xp_cmdshell ''del /q D:\webhome\saas_alisoft\backup\wfp_program\@@ExecEdb.rar''
end

Update @@MIGRATESEVER.[dbo].[MigrationEDB] set SourceStatus=''DB.DETACHED'' Where EdbID=@@EdbID

if not exists (Select * From @@MIGRATESEVER.[dbo].[MigrationEDB] Where PlanID=@@PlanID And ISNULL(SourceStatus,'''')<>''DB.DETACHED'')
Update @@MIGRATESEVER.[dbo].[MigrationPlan] set SourceStatus=''MIGRATE.MOVED'',TargetStatus=''MIGRATE.MOVED'' Where PlanID=@@PlanID
')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.SOURCE','MIGRATE.MOVED',Null,'MIGRATE.OVER',110,'源迁移完成处理',
'EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1 
RECONFIGURE

exec master.dbo.xp_cmdshell ''del /q D:\webhome\saas_alisoft\backup\wfp_program\copyxls.rar'';

select SourceEDB into #b From @@MIGRATESEVER.[dbo].[MigrationEDB] Where PlanID = @@PlanID;
Update wfp..wfpsys_user set servadd =''@@TargetSerAdd'' where objname in (select SourceEDB From #b);

if ''@@PlanType''=''整机迁移''
begin
declare @serviceid int,@servicename varchar(255),@execname varchar(255),@cmd varchar(8000);
select @serviceid=min(serviceid) from @@MIGRATESEVER.[dbo].[ServiceList]
while isnull(@serviceid ,0)>0
begin
	select @servicename=servicename,@execname=execname from @@MIGRATESEVER.[dbo].[ServiceList] where serviceid=@serviceid
	set @cmd = ''sc config ''+@servicename+'' start= auto''
	Exec xp_cmdshell @cmd
	set @cmd = ''net start ''+@servicename
	Exec xp_cmdshell @cmd
	select @serviceid=min(serviceid) from @@MIGRATESEVER.[dbo].[ServiceList] where serviceid>@serviceid
end

DECLARE @jobname varchar(255),@running int , @enabled int , @SQL_STR varchar(8000)
DECLARE cur_db CURSOR FOR
select name,running,enabled from drp..AUTOMIGRATE_Jobs
OPEN cur_db 
FETCH NEXT FROM cur_db 
INTO @jobname,@running,@enabled
WHILE @@FETCH_STATUS = 0 
BEGIN
	if @enabled = 1
		EXEC msdb.dbo.sp_update_job @job_name=@jobname, @enabled=1
	FETCH NEXT FROM cur_db INTO @jobname,@running,@enabled 
END 
CLOSE cur_db 
DEALLOCATE cur_db
end
')

Insert into MigrationCommand(CommandVIP,PlanStatus,EdbStatus,NextStatus,CommandOrder,CommandLog,CommandLine)
values('VIP.TARGET','MIGRATE.MOVED',Null,'MIGRATE.OVER',120,'目标迁移完成处理',
'EXEC sp_configure ''show advanced options'', 1;
RECONFIGURE;
EXEC sp_configure ''xp_cmdshell'', 1 
RECONFIGURE

exec xp_cmdshell ''netsh advfirewall firewall set rule name="axel-out" dir=out new enable=no'';

select SourceEDB into #b From @@MIGRATESEVER.[dbo].[MigrationEDB] Where PlanID = @@PlanID;
Update wfp..wfpsys_user set servadd =''@@TargetSerAdd'' where objname in (select SourceEDB From #b);

declare @edbid int,@sourceEDB varchar(255),@sql varchar(8000);
select @edbid=min(edbid) from @@MIGRATESEVER.[dbo].[MigrationEDB] where PlanID=@@PlanID and sourceEDB like ''edb_a_____''
while isnull(@edbid ,0)>0
begin
	select @sourceEDB=sourceEDB from @@MIGRATESEVER.[dbo].[MigrationEDB] where edbid=@edbid
	set @sql = ''delete drp.dbo.DRP_Backup_CurDb where bak_type=''''full''''
				exec DRP.dbo.DRP_Backup_DB ''''full'''',''''''+@sourceEDB+''''''''
	print @sql
	Exec(@sql)
	
	select @edbid=min(edbid) from @@MIGRATESEVER.[dbo].[MigrationEDB] where PlanID=@@PlanID and edbid>@edbid and sourceEDB like ''edb_a_____''
end

if ''@@PlanType''=''整机迁移''
begin
declare @serviceid int,@servicename varchar(255),@execname varchar(255),@cmd varchar(8000);
select @serviceid=min(serviceid) from @@MIGRATESEVER.[dbo].[ServiceList]
while isnull(@serviceid ,0)>0
begin
	select @servicename=servicename,@execname=execname from @@MIGRATESEVER.[dbo].[ServiceList] where serviceid=@serviceid
	set @cmd = ''sc config ''+@servicename+'' start= auto''
	Exec xp_cmdshell @cmd
	set @cmd = ''net start ''+@servicename
	Exec xp_cmdshell @cmd
	select @serviceid=min(serviceid) from @@MIGRATESEVER.[dbo].[ServiceList] where serviceid>@serviceid
end

DECLARE @jobname varchar(255),@running int , @enabled int , @SQL_STR varchar(8000)
DECLARE cur_db CURSOR FOR
select name,running,enabled from drp..AUTOMIGRATE_Jobs
OPEN cur_db 
FETCH NEXT FROM cur_db 
INTO @jobname,@running,@enabled
WHILE @@FETCH_STATUS = 0 
BEGIN
	if @enabled = 1
		EXEC msdb.dbo.sp_update_job @job_name=@jobname, @enabled=1
	FETCH NEXT FROM cur_db INTO @jobname,@running,@enabled 
END 
CLOSE cur_db 
DEALLOCATE cur_db
end
else
begin
	exec xp_cmdshell ''taskkill /f /im EDBService.exe & net start EDBTaskService''
	exec xp_cmdshell ''taskkill /f /im EdbSdkWinService.exe & net start EdbSdkService''
end
')

/*
--update MigrationPlan set SourceStatus=Replace(SourceStatus,'.DOING',''),TargetStatus=Replace(TargetStatus,'.DOING','')
--update MigrationPlan set SourceStatus='MIGRATE.ALLOW',TargetStatus='MIGRATE.ALLOW'
Exec SP_AUTO_MIGRATE
Select * From MigrationPlan
Select * From MigrationEDB
Select * from MigrationLog
*/
Select * from MigrationCommand order by CommandOrder,CommandID


