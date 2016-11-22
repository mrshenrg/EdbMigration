IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_Check_RunLog]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[SP_Check_RunLog]
GO
  
CREATE PROCEDURE SP_Check_RunLog(
@planid int = Null,
@LikeStr varchar(255) = Null
)
AS  
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
BEGIN
	/*
	Update dbo.MigrationLog set guid=newid() where PlanStatus like '%.Doing' and guid is null
	Update dbo.MigrationLog set guid=newid() where EdbStatus like '%.Doing' and guid is null
	
	--Drop table #MigrationLog
	Select * into #MigrationLog from dbo.MigrationLog order by PlanID,ExecVIP,edbid,execedb,planstatus,edbstatus

	update #MigrationLog Set PlanStatus = replace(PlanStatus,'.ERROR',''),EdbStatus = replace(EdbStatus,'.ERROR','')
	update #MigrationLog Set PlanStatus = replace(PlanStatus,'.DOING',''),EdbStatus = replace(EdbStatus,'.DOING','')
	update #MigrationLog Set PlanStatus = replace(PlanStatus,'.DONE',''),EdbStatus = replace(EdbStatus,'.DONE','')
	
	--Drop table #MigrationLog2
	Select auto=identity(int,1,1),convert(int,logid) as logid,guid,LogTime,PlanID,ExecVIP,edbid,execedb,planstatus,edbstatus into #MigrationLog2 
	From #MigrationLog order by PlanID,ExecVIP,edbid,execedb,planstatus,edbstatus,LogTime
	
	Select * From #MigrationLog2
	
	Select L2.logid,L2.guid,L.* 
	update L set l.guid=L2.guid
	from dbo.MigrationLog L
	inner join #MigrationLog2 L1 on L.logid=L1.logid
	inner join #MigrationLog2 L2 on L2.auto=L1.auto-1
	where L.guid is null
	
	Select * from dbo.MigrationLog --where guid is null
	
	Select guid,count(*) as a into #a from dbo.MigrationLog Group by guid having count(*)<>2
	Select * From #a
	
	Select * from dbo.MigrationLog where guid in (Select guid From #a)
	*/
	
	-- 相关计划、不指定计划时查询一天内开始执行的计划
	Select PlanID,SourceVIP,TargetVIP,SourceStatus,TargetStatus
	Into #MigrationPlan --Select *,Getdate()-1
	from dbo.MigrationPlan P
	where PlanID=isnull(@planid,PlanID)
	and PlanExecTime >= (case when @planid is Null then Getdate() else PlanExecTime end)-1 
	and PlanExecTime <= (case when @planid is Null then Getdate() else PlanExecTime end)
	--and isnull(SourceStatus,'')<>(case when @planid is Null then 'MIGRATE.OVER' else '***' end)
	--and isnull(TargetStatus,'')<>(case when @planid is Null then 'MIGRATE.OVER' else '***' end)
	--where isnull(SourceStatus,'')<>'MIGRATE.OVER' And isnull(TargetStatus,'')<>'MIGRATE.OVER'
	
	--Drop table #MigrationLog
	-- 相关计划执行日志，.DING->.DONE OR .DOING->.ERROR
	Select L.PlanID,ExecVIP,EdbID,ExecEdb,PlanStatus=Replace(PlanStatus,'.DOING',''),EdbStatus=Replace(EdbStatus,'.DOING','')
		,LogID,Convert(int,Null) as LogID2
	Into #MigrationLog 
	From dbo.MigrationLog L inner join #MigrationPlan T on L.PlanID=T.PlanID
	Where isnull(PlanStatus,'') like '%.DOING' or isnull(EdbStatus,'') like '%.DOING'
	--Group by L.PlanID,ExecVIP,EdbID,ExecEdb,PlanStatus,EdbStatus
	
	--Drop table #MigrationLog2
	Select L.PlanID,ExecVIP,EdbID,ExecEdb
		,PlanStatus=Replace(Replace(PlanStatus,'.DONE',''),'.ERROR','')
		,EdbStatus=Replace(Replace(EdbStatus,'.DONE',''),'.ERROR','')
		,LogID
	Into #MigrationLog2 
	From dbo.MigrationLog L inner join #MigrationPlan T on L.PlanID=T.PlanID
	Where isnull(PlanStatus,'') like '%.DONE' or isnull(PlanStatus,'') like '%.ERROR' 
	   or isnull(EdbStatus,'') like '%.DONE' or isnull(EdbStatus,'') like '%.ERROR'
	
	--Select * from #MigrationLog
	--select * from #MigrationLog2 
	
	Update T2 Set LogID2=
		(Select min(LogID)
		From #MigrationLog2 L2 
		Where L2.PlanID=T2.PlanID and L2.ExecVIP=T2.ExecVIP and ISNULL(L2.EdbID,0)=ISNULL(T2.EdbID,0)
		and L2.PlanStatus=T2.PlanStatus and ISNULL(L2.EdbStatus,'')=ISNULL(T2.EdbStatus,'')
		and L2.LogID>T2.LogID)
	From #MigrationLog T2
		
	--Select * From #MigrationLog
	-- #Report 按日志方式展示
	Select id=identity(int,1,1),T.PlanID,ExecVIP=T.ExecVIP+(Case When P.PLANID is Not Null then '(源)' Else '(目标)' End)
		,T.ExecEdb
		,CommandLog = Isnull(L2.CommandLog,L1.CommandLog)
		,[执行(分钟)]=datediff(mi,L1.LogTime,Isnull(L2.LogTime,getdate()))
		,[执行(秒)]=datediff(ss,L1.LogTime,Isnull(L2.LogTime,getdate()))
		,L1.LogTime as StartTime,L2.LogTime as EndTiem,SourceDBSize
		,PlanStatus=isnull(L2.PlanStatus,L1.PlanStatus),EdbStatus=ISNULL(L2.EdbStatus,L1.EdbStatus)
		,L1.LogID as StartLog,L2.LogID as EndLog
	Into #Report
	From #MigrationLog T
	left join #MigrationPlan p on p.SourceVIP=T.ExecVIP
	left join MigrationEdb E on E.EdbID=T.EdbID
	Left join MigrationLog L1 on L1.LogID=T.LogID
	Left join MigrationLog L2 on L2.LogID=T.LogID2
	Order by T.LogID DESC
	
	Select PlanID,ExecVIP,ExecEdb,id = min(id)
	into #Report2
	from #Report
	Group by PlanID,ExecVIP,ExecEdb
	
	-- #Report2_1 按计划方式展示
	Select num=1,id=convert(int,edbid),E.SourceVIP,E.TargetVIP,sourceedb
	into #Report2_1
	from MigrationEdb E 
	inner join #MigrationPlan P on E.PLANID=P.PlanID
	union all
	Select num=0,id=convert(int,planid),SourceVIP,TargetVIP,sourceedb=Null
	from #MigrationPlan
	
	Select r.id,r.SourceVIP,r.TargetVIP,sourceedb,
		SourceStatus=ISNULL(r11.EdbStatus,r11.PlanStatus),SourceLog=r11.CommandLog,
		TargetStatus=ISNULL(r21.EdbStatus,r21.PlanStatus),TargetLog=r21.CommandLog 
	from #Report2_1 r
	left join #Report2 r1 on r1.ExecVIP=r.SourceVIP+'(源)'   and isnull(r1.ExecEdb,'')=isnull(r.sourceedb,'')
	left join #Report2 r2 on r2.ExecVIP=r.TargetVIP+'(目标)' and isnull(r2.ExecEdb,'')=isnull(r.sourceedb,'')
	left join #Report r11 on r11.id=r1.id
	left join #Report r21 on r21.id=r2.id
	where isnull(r.SourceVIP,'') like '%'+isnull(@LikeStr,'')+'%'
	  Or isnull(r.TargetVIP,'') like '%'+isnull(@LikeStr,'')+'%'
	  Or isnull(sourceedb,'') like '%'+isnull(@LikeStr,'')+'%'
	order by r.num,r.id
	--Select * from #Report
	--where id in (Select id from #Report2)
	--order by PlanID,ExecEdb
	
	Select * from #Report
	where isnull(ExecVIP,'') like '%'+isnull(@LikeStr,'')+'%'
	  Or isnull(ExecEdb,'') like '%'+isnull(@LikeStr,'')+'%'
END  