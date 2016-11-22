USE [DRP]
GO
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_MIGRATE_User]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[SP_MIGRATE_User]
GO

USE [DRP]
GO
CREATE PROCEDURE [dbo].[SP_MIGRATE_User](@PlanID int, @ISBackup int)
AS
if object_id('tempdb..#edbs') is not null drop table #edbs
SELECT '''AGT_TRAD.'','''+[SourceEDB]+'.''' as dbswitch into #edbs FROM EdbMigration.[EdbMigration].[dbo].[MigrationEDB] WHERE PlanID = @PlanID and [SourceEDB] like 'edb_a_____'
if @ISBackup = 1
begin
DELETE FROM EdbMigration.EdbMigration.dbo.wfpsys_user where PlanID = @PlanID
DELETE FROM EdbMigration.EdbMigration.dbo.WFPSYS_UserGroup where PlanID = @PlanID
DELETE FROM EdbMigration.EdbMigration.dbo.WFPSYS_Group where PlanID = @PlanID

insert into EdbMigration.EdbMigration.dbo.wfpsys_user(PlanID,Parentid,objname,objjc,objexplain,Memo,UserID,RegTime,DBSwitch,DisTime,FailTime,Lisens,Servadd,pwdn,LoginNum,LastOnTime,LastPwdTime)
select @PlanID,Parentid,objname,objjc,objexplain,Memo,UserID,RegTime,DBSwitch,DisTime,FailTime,Lisens,Servadd,pwdn,LoginNum,LastOnTime,LastPwdTime
from  wfp..wfpsys_user
where objid <> 0 and dbswitch in(select dbswitch from #edbs)


insert into EdbMigration.EdbMigration.dbo.WFPSYS_UserGroup(PlanID,UserName,GroupName,MainDuty)
select @PlanID,UserName,GroupName,MainDuty
from wfp..WFPSYS_UserGroup
where objid <> 0 and UserName in (select Objname
from wfp..WFPSYS_User
where DBSwitch in(select dbswitch from #edbs))

insert into EdbMigration.EdbMigration.dbo.WFPSYS_Group(PlanID,Parentid,Objname,Objjc,Objorder,Objexplain,Memo,DefaultWF)
select @PlanID,Parentid,Objname,Objjc,Objorder,Objexplain,Memo,DefaultWF
from wfp..WFPSYS_Group
where objid <> 0 and Objname in (select GroupName	
from wfp..WFPSYS_UserGroup
where UserName in (select Objname
from wfp..WFPSYS_User
where DBSwitch in(select dbswitch from #edbs)))
end
else
begin

delete from wfp..WFPSYS_UserGroup where UserName in (select Objname from wfp..WFPSYS_User where DBSwitch in(select dbswitch from #edbs))
delete from wfp..WFPSYS_TaskRecord where Operator in (select Objname from wfp..WFPSYS_User where DBSwitch in(select dbswitch from #edbs))
delete from wfp..WFPSYS_TaskFlow where Starter in (select Objname from wfp..WFPSYS_User where DBSwitch  in(select dbswitch from #edbs))
delete from wfp..wfpsys_user where DBSwitch in(select dbswitch from #edbs)

insert into wfp..WFPSYS_Group(Parentid,Objname,Objjc,Objorder,Objexplain,Memo,DefaultWF)
select Parentid,Objname,Objjc,Objorder,Objexplain,Memo,DefaultWF
from EdbMigration.EdbMigration.dbo.WFPSYS_Group
where PlanID = @PlanID and objname not in (select objname from wfp..WFPSYS_Group)

insert into wfp..wfpsys_user(Parentid,objname,objjc,objexplain,Memo,UserID,RegTime,DBSwitch,DisTime,FailTime,Lisens,Servadd,pwdn,LoginNum,LastOnTime,LastPwdTime)
select Parentid,objname,objjc,objexplain,Memo,UserID,RegTime,DBSwitch,DisTime,FailTime,Lisens,Servadd,pwdn,LoginNum,LastOnTime,LastPwdTime
from EdbMigration.EdbMigration.dbo.wfpsys_user
where PlanID = @PlanID

insert into wfp..WFPSYS_UserGroup(UserName,GroupName,MainDuty)
select UserName,GroupName,MainDuty
from EdbMigration.EdbMigration.dbo.WFPSYS_UserGroup
where PlanID = @PlanID

end
