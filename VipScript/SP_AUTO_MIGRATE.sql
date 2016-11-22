IF EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'EdbMigration')
EXEC master.dbo.sp_dropserver @server=N'EdbMigration', @droplogins='droplogins'
IF  NOT EXISTS (SELECT srv.name FROM sys.servers srv WHERE srv.server_id != 0 AND srv.name = N'EdbMigration')
BEGIN
exec sp_addlinkedserver EdbMigration, '', 'SQLOLEDB','{Server Ip,Port}'
exec sp_addlinkedsrvlogin EdbMigration,'false',null,'{User}','{PassWord}'
exec sp_serveroption EdbMigration,'rpc out','true'
END
GO

if OBJECT_ID('drp..AUTOMIGRATE_Jobs') is not null drop table drp..AUTOMIGRATE_Jobs
GO

USE [DRP]
GO

/****** Object:  StoredProcedure [dbo].[SP_AUTO_MIGRATE]    Script Date: 10/19/2016 16:51:42 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_AUTO_MIGRATE]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[SP_AUTO_MIGRATE]
GO

USE [DRP]
GO

/****** Object:  StoredProcedure [dbo].[SP_AUTO_MIGRATE]    Script Date: 10/19/2016 16:51:42 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[SP_AUTO_MIGRATE](@OnlyRestore varchar(20)) --@OnlyRestore = Yes/No
AS
BEGIN
	Declare @MIGRATESEVER NVARCHAR(255);
	Set @MIGRATESEVER = 'EdbMigration.[EdbMigration]'
	
	Declare @LOCALVIP varchar(255)  
	Select @LOCALVIP=[srvname] from master..sysservers where srvid=0
	
	/*只是在EDB中心服务器上执行*/
	if @LOCALVIP = 'B20130326'
	begin
		Select PlanID=Convert(varchar(255),P.PlanID),P.SourceVIP,P.TargetVIP,E.SourceEDB,P.SourceSerAdd,P.TargetSerAdd
		Into #Temp_MigrationPlan_Over
		From EdbMigration.[EdbMigration].[dbo].[MigrationPlan] P
		inner join EdbMigration.[EdbMigration].[dbo].[MigrationEDB] E
			on P.PlanID = E.PlanID
		Where E.SourceEDB like 'edb_a_____' and Isnull(P.isover,0)<>1
		  And Isnull(P.SourceStatus,'MIGRATE.INIT')='MIGRATE.OVER'
		  And Isnull(P.TargetStatus,'MIGRATE.INIT')='MIGRATE.OVER'
		  
		update u set servadd = O.TargetSerAdd
		From wfp..wfpsys_user u
		inner join #Temp_MigrationPlan_Over O on u.objname=O.SourceEDB
		
		Update EdbMigration.[EdbMigration].[dbo].[MigrationPlan] Set isover=1
		where PlanID in (Select PlanID from #Temp_MigrationPlan_Over)

		return
	end
	
	Declare @ExecSQL VARCHAR(Max),@ExecSQL2 VARCHAR(Max),@ExecSQL3 VARCHAR(Max);
Set @ExecSQL = '
Declare @PlanID int,@PlanType varchar(255),@ExecVIP varchar(255),@PlanStatus varchar(255),@isenable int;
Declare @SourceVIPWeb varchar(255),@TargetVIPWeb varchar(255),@SourceSerAdd varchar(255),@TargetSerAdd varchar(255)
Select @PlanID=PlanID,@PlanType=PlanType,@ExecVIP=#ExecVIP#,@PlanStatus=ISNULL(#PlanStatus#,''MIGRATE.INIT''),@isenable=isnull(isenable,0)
	,@SourceVIPWeb=SourceVIPWeb,@TargetVIPWeb=TargetVIPWeb,@SourceSerAdd=SourceSerAdd,@TargetSerAdd=TargetSerAdd
From '+@MIGRATESEVER+'.[dbo].[MigrationPlan] Where PlanID = #PlanID#;

if @PlanStatus<>''#VipStatus#''
	return
if @PlanStatus not in (''MIGRATE.INIT'',''MIGRATE.CONFIG'',''MIGRATE.CHECK'',''MIGRATE.MOVEDB'') and @isenable <> 1
	return

Select identity(int,1,1) as AutoID,CommandID=Convert(int,CommandID),CommandLine,CommandLog,EdbStatus,NextStatus
into #Command
From '+@MIGRATESEVER+'.[dbo].[MigrationCommand] 
Where ISNULL(CommandVIP,''VIP.ALL'') IN (''VIP.ALL'',''#CommandVIP#'') and PlanStatus=@PlanStatus'
+ (case when @OnlyRestore='Yes' then ' and (PlanStatus = ''MIGRATE.MOVEDB'' and EdbStatus = ''DB.RESTORE'') ' 
  else ' and Not (PlanStatus = ''MIGRATE.MOVEDB'' and EdbStatus = ''DB.RESTORE'') ' end) +
'Order by CommandOrder;

Declare @ROW int,@EDBROW int,@EffROWS int;
Declare @cmdid int,@cmdsql varchar(Max),@cmdsql2 varchar(Max),@cmdlog varchar(Max),@EdbStatus varchar(255),@NextStatus varchar(255);
Declare @EdbID int,@ExecEdb varchar(255);

Set @ROW = 1'
Set @ExecSQL2 = '
While Exists(Select top 1 1 from #Command where AutoID = @ROW)
Begin
	Select @cmdid=CommandID,@cmdsql=CommandLine,@cmdlog=CommandLog,@EdbStatus=EdbStatus,@NextStatus=NextStatus
	from #Command Where AutoID=@ROW;
	--Print ''Select * From '+@MIGRATESEVER+'.[dbo].[MigrationCommand] Where CommandID = '' + Convert(Varchar(10),@cmdid)

	If ISNULL(@EdbStatus,'''')=''''
	Begin
		Update '+@MIGRATESEVER+'.[dbo].[MigrationPlan] Set #PlanStatus# = @PlanStatus+''.DOING''
		Where PlanID=@PlanID And ISNULL(#PlanStatus#,''MIGRATE.INIT'') = @PlanStatus
		Set @EffROWS=@@ROWCOUNT

		If @EffROWS>0
		Begin
			--Print @cmdsql
			Set @cmdsql = Replace(@cmdsql,''@@MIGRATESEVER'','''+@MIGRATESEVER+''')
			Set @cmdsql = Replace(@cmdsql,''@@PlanID'',@PlanID)
			Set @cmdsql = Replace(@cmdsql,''@@ExecVIP'',@ExecVIP)
			Set @cmdsql = Replace(@cmdsql,''@@PlanType'',@PlanType)
			Set @cmdsql = Replace(@cmdsql,''@@PlanStatus'',''#PlanStatus#'')
			Set @cmdsql = Replace(@cmdsql,''@@EdbStatus'',''#EdbStatus#'')
			Set @cmdsql = Replace(@cmdsql,''@@LogGuid'',''#LogGuid#'')
			Set @cmdsql = Replace(@cmdsql,''@@SourceVIPWeb'',Isnull(@SourceVIPWeb,''''))
			Set @cmdsql = Replace(@cmdsql,''@@TargetSerAdd'',Isnull(@TargetSerAdd,''''))

			Insert Into '+@MIGRATESEVER+'.[dbo].[MigrationLog](PlanID,EdbID,ExecVIP,ExecEdb,PlanStatus,EdbStatus,CommandLine,CommandLog,[guid])
			Values (@PlanID,Null,'''+@LOCALVIP+''',Null,@PlanStatus+''.DOING'',Null,@cmdsql,''正在执行:''+@cmdlog+''...'',''#LogGuid#'')

			Print @cmdsql
			EXEC(@cmdsql);

			Insert Into '+@MIGRATESEVER+'.[dbo].[MigrationLog](PlanID,EdbID,ExecVIP,ExecEdb,PlanStatus,EdbStatus,CommandLine,CommandLog,[guid])
			Values (@PlanID,Null,'''+@LOCALVIP+''',Null,@PlanStatus+''.DONE'',Null,@cmdsql,''执行结束:''+@cmdlog,''#LogGuid#'')

			if Isnull(@NextStatus,'''')<>''''
			Update '+@MIGRATESEVER+'.[dbo].[MigrationPlan] Set #PlanStatus# = @NextStatus 
			Where PlanID=@PlanID And #PlanStatus# = @PlanStatus+''.DOING''
		End
	End
'
Set @ExecSQL3 = '	Else
	Begin
		if object_id(''tempdb..#ExecEdb'') is not null drop table #ExecEdb
		
		Select identity(int,1,1) as AutoID,EdbID=Convert(int,EdbID),SourceEDB,#EdbStatus#
		into #ExecEdb
		From '+@MIGRATESEVER+'.[dbo].[MigrationEDB] 
		Where PlanID=@PlanID And ISNULL(#EdbStatus#,''MIGRATE.INIT'')=@EdbStatus
		order by EdbID
		
		print @EdbStatus
		Select * from #ExecEdb

		Set @EDBROW = 1
		
		While Exists(Select top 1 1 from #ExecEdb where AutoID = @EDBROW)
		Begin
			Select @EdbID=EdbID,@ExecEdb=SourceEDB
			from #ExecEdb where AutoID = @EDBROW
					
	
			Update '+@MIGRATESEVER+'.[dbo].[MigrationEDB] Set #EdbStatus# = @EdbStatus+''.DOING''
			Where EdbID=@EdbID And ISNULL(#EdbStatus#,''DB.INIT'') = @EdbStatus
			Set @EffROWS=@@ROWCOUNT

			If @EffROWS>0
			Begin
				--Print @cmdsql
				Set @cmdsql2 = Replace(@cmdsql,''@@MIGRATESEVER'','''+@MIGRATESEVER+''')
				Set @cmdsql2 = Replace(@cmdsql2,''@@PlanID'',@PlanID)
				Set @cmdsql2 = Replace(@cmdsql2,''@@ExecVIP'',@ExecVIP)
				Set @cmdsql2 = Replace(@cmdsql2,''@@PlanType'',@PlanType)
				Set @cmdsql2 = Replace(@cmdsql2,''@@PlanStatus'',''#PlanStatus#'')
				Set @cmdsql2 = Replace(@cmdsql2,''@@EdbStatus'',''#EdbStatus#'')
				Set @cmdsql2 = Replace(@cmdsql2,''@@LogGuid'',''#LogGuid#'')
				Set @cmdsql2 = Replace(@cmdsql2,''@@SourceVIPWeb'',Isnull(@SourceVIPWeb,''''))
				Set @cmdsql2 = Replace(@cmdsql2,''@@TargetSerAdd'',Isnull(@TargetSerAdd,''''))
			
				Set @cmdsql2 = Replace(@cmdsql2,''@@EdbID'',@EdbID)
				Set @cmdsql2 = Replace(@cmdsql2,''@@ExecEdb'',@ExecEdb)

				Insert Into '+@MIGRATESEVER+'.[dbo].[MigrationLog](PlanID,EdbID,ExecVIP,ExecEdb,PlanStatus,EdbStatus,CommandLine,CommandLog,[guid])
				Values (@PlanID,@EdbID,'''+@LOCALVIP+''',@ExecEdb,@PlanStatus,@EdbStatus+''.DOING'',@cmdsql2,''正在执行:''+@cmdlog+''...'',''#LogGuid#'')

				Print @cmdsql2
				EXEC(@cmdsql2);

				Insert Into '+@MIGRATESEVER+'.[dbo].[MigrationLog](PlanID,EdbID,ExecVIP,ExecEdb,PlanStatus,EdbStatus,CommandLine,CommandLog,[guid])
				Values (@PlanID,@EdbID,'''+@LOCALVIP+''',@ExecEdb,@PlanStatus,@EdbStatus+''.DONE'',@cmdsql2,''执行结束:''+@cmdlog,''#LogGuid#'')

				if Isnull(@NextStatus,'''')<>''''
				Update '+@MIGRATESEVER+'.[dbo].[MigrationEDB] Set #EdbStatus# = @NextStatus 
				Where EdbID=@EdbID And #EdbStatus# = @EdbStatus+''.DOING''
			End
			Set @EDBROW = @EDBROW + 1
		End
	End
	Set @ROW=@ROW + 1
End'
	
	Declare @AutoID int,@sql varchar(max),@sql2 varchar(max),@sql3 varchar(max),@guid varchar(50),@isenable int;
	Declare @PlanID varchar(255),@SourceVIP varchar(255),@TargetVIP varchar(255),@SourceStatus varchar(255),@TargetStatus varchar(255),@ExecTime datetime;
	begin try
		Select identity(int,1,1) as AutoID,PlanID=Convert(varchar(255),PlanID),SourceVIP,TargetVIP,SourceStatus,TargetStatus,PlanExecTime,isenable
		Into #Temp_MigrationPlan
		From EdbMigration.[EdbMigration].[dbo].[MigrationPlan] 
		Where (SourceVIP=@LOCALVIP And Isnull(SourceStatus,'MIGRATE.INIT')<>'MIGRATE.OVER')
		   or (TargetVIP=@LOCALVIP And Isnull(TargetStatus,'MIGRATE.INIT')<>'MIGRATE.OVER')
		
		Set @AutoID = 1
		While Exists(Select top 1 1 from #Temp_MigrationPlan where AutoID = @AutoID)
		Begin
			Set @guid = newid();

			Select @PlanID=PlanID,@SourceVIP=SourceVIP,@TargetVIP=TargetVIP
				,@SourceStatus=Isnull(SourceStatus,'MIGRATE.INIT'),@TargetStatus=Isnull(TargetStatus,'MIGRATE.INIT')
				,@ExecTime=Isnull(PlanExecTime,'9999-12-31'),@isenable=isnull(isenable,0)
			From #Temp_MigrationPlan where AutoID = @AutoID
			
			IF @SourceVIP=@LOCALVIP
			Begin
				Set @sql=Replace(@ExecSQL,'#PlanID#',@PlanID)
				Set @sql=Replace(@sql,'#ExecVIP#','SourceVIP')
				Set @sql=Replace(@sql,'#PlanStatus#','SourceStatus')
				Set @sql=Replace(@sql,'#EdbStatus#','SourceStatus')
				Set @sql=Replace(@sql,'#CommandVIP#','VIP.SOURCE')
				Set @sql=Replace(@sql,'#LogGuid#',@guid)
				Set @sql=Replace(@sql,'#VipStatus#',@SourceStatus)
				
				Set @sql2=Replace(@ExecSQL2,'#PlanID#',@PlanID)
				Set @sql2=Replace(@sql2,'#ExecVIP#','SourceVIP')
				Set @sql2=Replace(@sql2,'#PlanStatus#','SourceStatus')
				Set @sql2=Replace(@sql2,'#EdbStatus#','SourceStatus')
				Set @sql2=Replace(@sql2,'#CommandVIP#','VIP.SOURCE')
				Set @sql2=Replace(@sql2,'#LogGuid#',@guid)
				Set @sql2=Replace(@sql2,'#VipStatus#',@SourceStatus)
				
				Set @sql3=Replace(@ExecSQL3,'#PlanID#',@PlanID)
				Set @sql3=Replace(@sql3,'#ExecVIP#','SourceVIP')
				Set @sql3=Replace(@sql3,'#PlanStatus#','SourceStatus')
				Set @sql3=Replace(@sql3,'#EdbStatus#','SourceStatus')
				Set @sql3=Replace(@sql3,'#CommandVIP#','VIP.SOURCE')
				Set @sql3=Replace(@sql3,'#LogGuid#',@guid)
				Set @sql3=Replace(@sql3,'#VipStatus#',@SourceStatus)
				
				Set @SourceStatus=Replace(@SourceStatus,'.DOING','')
				Set @SourceStatus=Replace(@SourceStatus,'.ERROR','')
				if @SourceStatus in ('MIGRATE.INIT','MIGRATE.CONFIG','MIGRATE.CHECK','MIGRATE.MOVEDB')
				or (@SourceStatus not in ('MIGRATE.INIT','MIGRATE.CONFIG','MIGRATE.CHECK','MIGRATE.MOVEDB') and getdate()>@ExecTime and @isenable = 1)
				begin
					Print '源VIP'
					/*Print @sql+@sql2+@sql3*/
					Exec (@sql+@sql2+@sql3)
				end
			End
			
			IF @TargetVIP=@LOCALVIP
			Begin
				Set @sql=Replace(@ExecSQL,'#PlanID#',@PlanID)
				Set @sql=Replace(@sql,'#ExecVIP#','TargetVIP')
				Set @sql=Replace(@sql,'#PlanStatus#','TargetStatus')
				Set @sql=Replace(@sql,'#EdbStatus#','TargetStatus')
				Set @sql=Replace(@sql,'#CommandVIP#','VIP.TARGET')
				Set @sql=Replace(@sql,'#LogGuid#',@guid)
				Set @sql=Replace(@sql,'#VipStatus#',@TargetStatus)
				
				Set @sql2=Replace(@ExecSQL2,'#PlanID#',@PlanID)
				Set @sql2=Replace(@sql2,'#ExecVIP#','TargetVIP')
				Set @sql2=Replace(@sql2,'#PlanStatus#','TargetStatus')
				Set @sql2=Replace(@sql2,'#EdbStatus#','TargetStatus')
				Set @sql2=Replace(@sql2,'#CommandVIP#','VIP.TARGET')
				Set @sql2=Replace(@sql2,'#LogGuid#',@guid)
				Set @sql2=Replace(@sql2,'#VipStatus#',@TargetStatus)
				
				Set @sql3=Replace(@ExecSQL3,'#PlanID#',@PlanID)
				Set @sql3=Replace(@sql3,'#ExecVIP#','TargetVIP')
				Set @sql3=Replace(@sql3,'#PlanStatus#','TargetStatus')
				Set @sql3=Replace(@sql3,'#EdbStatus#','TargetStatus')
				Set @sql3=Replace(@sql3,'#CommandVIP#','VIP.TARGET')
				Set @sql3=Replace(@sql3,'#LogGuid#',@guid)
				Set @sql3=Replace(@sql3,'#VipStatus#',@TargetStatus)

				Set @TargetStatus=Replace(@TargetStatus,'.DOING','')
				Set @TargetStatus=Replace(@TargetStatus,'.ERROR','')
				if @TargetStatus in ('MIGRATE.INIT','MIGRATE.CONFIG','MIGRATE.CHECK','MIGRATE.MOVEDB')
				or (@TargetStatus not in ('MIGRATE.INIT','MIGRATE.CONFIG','MIGRATE.CHECK','MIGRATE.MOVEDB') and getdate()>@ExecTime and @isenable = 1)
				begin
					Print '目标VIP'
					/*Print @sql+@sql2+@sql3*/
					Exec (@sql+@sql2+@sql3)
				end
			End
			
			Set @AutoID = @AutoID + 1
		End
	end try
	begin catch
		declare @logs varchar(max)
		set @logs = ERROR_MESSAGE() 
		Print @logs
		Print @sql+@sql2+@sql3

		set @logs = Replace(@logs,'''','''''') 
		set @sql = Replace(@sql,'''','''''') 
		set @sql2 = Replace(@sql2,'''','''''') 
		set @sql3 = Replace(@sql3,'''','''''') 
		
		declare @logid int,@edbid int,@EdbStatus varchar(255);
		Select @logid = max(logid)
		From EdbMigration.[EdbMigration].[dbo].[MigrationLog] 
		where PlanID = @PlanID and ExecVIP=@LOCALVIP and [guid]=@guid
		
		Select @edbid=edbid,@EdbStatus=EdbStatus 
		From EdbMigration.[EdbMigration].[dbo].[MigrationLog] 
		Where logid=@logid
		
		/*还原失败，需要重新下载rar文件*/
		if isnull(@EdbStatus,'')='DB.RESTORE.DOING'
		Update EdbMigration.[EdbMigration].[dbo].[MigrationEdb] set TargetStatus = 'DB.LOADDB' where EdbID=@edbid
		
		update P Set SourceStatus = Replace(SourceStatus,'.DOING','.ERROR')
		From EdbMigration.[EdbMigration].[dbo].[MigrationPlan] P
		Inner join EdbMigration.[EdbMigration].[dbo].[MigrationLog] L on P.PlanID=L.PlanID
		where L.logid = @logid and L.ExecVIP = P.SourceVIP and L.EdbID is Null 
		
		update P Set TargetStatus = Replace(TargetStatus,'.DOING','.ERROR')
		From EdbMigration.[EdbMigration].[dbo].[MigrationPlan] P
		Inner join EdbMigration.[EdbMigration].[dbo].[MigrationLog] L on P.PlanID=L.PlanID
		where L.logid = @logid and L.ExecVIP = P.TargetVIP and L.EdbID is Null
		
		update E Set SourceStatus = Replace(SourceStatus,'.DOING','.ERROR')
		From EdbMigration.[EdbMigration].[dbo].[MigrationEDB] E
		Inner join EdbMigration.[EdbMigration].[dbo].[MigrationLog] L on E.EdbID=L.EdbID
		where L.logid = @logid and L.ExecVIP = E.SourceVIP
		
		update E Set TargetStatus = Replace(TargetStatus,'.DOING','.ERROR')
		From EdbMigration.[EdbMigration].[dbo].[MigrationEDB] E
		Inner join EdbMigration.[EdbMigration].[dbo].[MigrationLog] L on E.EdbID=L.EdbID
		where L.logid = @logid and L.ExecVIP = E.TargetVIP
		
		Insert Into EdbMigration.[EdbMigration].[dbo].[MigrationLog](PlanID,EdbID,ExecVIP,ExecEdb,PlanStatus,EdbStatus,CommandLine,CommandLog,[guid])
		Select PlanID,EdbID,ExecVIP,ExecEdb,Replace(PlanStatus,'.DOING','.ERROR'),Replace(EdbStatus,'.DOING','.ERROR'),CommandLine,'执行失败!'+@logs,@guid
		From EdbMigration.[EdbMigration].[dbo].[MigrationLog] where logid=@logid
	End catch
END


GO

