IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[SP_SENDMail_RunLog]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[SP_SENDMail_RunLog]
GO
  
CREATE PROCEDURE [dbo].[SP_SENDMail_RunLog]    
as    
DECLARE @body varchar(MAX),@txt1 varchar(MAX),@txt2 varchar(MAX);    
SET @body = ''    
SET @txt1 = ''    
SET @txt2 = ''    
    
IF OBJECT_ID('tempdb..#plan') IS NOT NULL DROP TABLE #plan    
SELECT Planid INTO #plan From EdbMigration..MigrationPlan    
where getdate() > Isnull(PlanExecTime,'9999-12-31')     
and SourceStatus = 'MIGRATE.ALLOW' and TargetStatus = 'MIGRATE.ALLOW'     
and isnull(isOver,0) <> 1 AND ISNULL(isenable,0)=0    
    
IF EXISTS (SELECT Planid From #plan)    
BEGIN    
 UPDATE EdbMigration..MigrationPlan set isenable = 1     
 WHERE Planid IN (SELECT Planid From #plan)    
    
 SET @txt1 = '<table border="1"><tr>     
    <th>开始时间</th>    
    <th>源服务器</th>    
    <th>目标服务器</th>   
 </tr>'    
 SELECT @txt1 = @txt1 + '    
 <tr>    
 <td>' + CONVERT(VARCHAR(19),GETDATE(),121) + '</tb>    
 <td>' + SourceVIP + '</td>    
 <td>' + TargetVIP + '</td>    
 </tr>'    
 FROM EdbMigration..MigrationPlan    
 WHERE Planid IN (SELECT Planid From #plan)    
    
 SET @txt1 = @txt1 + '    
 </table>'    
END    
    
IF OBJECT_ID('tempdb..#log') IS NOT NULL DROP TABLE #log    
SELECT Logid INTO #log FROM EdbMigration..MigrationLog     
WHERE (PlanStatus LIKE '%.ERROR' OR ISNULL(EdbStatus,'') LIKE '%.ERROR')    
AND ISNULL(isreport,0)=0 --AND LogTime > DATEADD(HOUR,-1,GETDATE())    
    
IF EXISTS (SELECT Logid From #log)    
BEGIN    
 UPDATE EdbMigration..MigrationLog SET isreport = 1    
 WHERE logid IN (SELECT Logid from #log)    
    
 SET @txt2 = '<table border="1"><tr>    
    <th>执行时间</th>    
    <th>失败原因</th>    
    <th>执行服务器</th>    
    <th>服务器状态</th>    
    <th>执行主账号</th>    
    <th>主账户状态</th>    
 </tr>'    
 SELECT @txt2 = @txt2 + '    
 <tr>    
 <td>' + CONVERT(VARCHAR(19),LogTime,121) + '</tb>    
 <td>' + ISNULL([CommandLog],'') + '</td>    
 <td>' + ExecVIP + '</td>    
 <td>' + PlanStatus + '</td>    
 <td>' + ISNULL(ExecEdb,'NULL') + '</td>    
 <td>' + ISNULL(EdbStatus,'NULL') + '</td>    
 </tr>'    
 FROM EdbMigration..MigrationLog    
 WHERE logid IN (SELECT Logid from #log)    
     
 SET @txt2 = @txt2 + '</table>'    
END    
  
IF @txt1 <> '' OR @txt2 <> ''    
BEGIN    
SET @body = '<html><body>' + @txt1 + @txt2 + '</body></html>'    
PRINT @body     
EXEC msdb.dbo.sp_send_dbmail    
 @profile_name = 'zizhen',    
 @recipients = 'zizhen@centaur.cn;fangzheng@centaur.cn;gancao@centaur.cn;xiangyu@centaur.cn',    
 @body = @body,    
 @body_format= 'HTML',    
 @sensitivity = 'Confidential',    
 @subject = '服务器迁移日志' ;    
End