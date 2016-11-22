/******************MigrationPlan structure *********************/
print 'dbo.MigrationPlan...'
if not exists (select * from sysobjects where id = object_id('dbo.MigrationPlan') and sysstat & 0xf = 3)
BEGIN --Drop table MigrationPlan
CREATE TABLE dbo.MigrationPlan
(
  PlanID int identity(1,1) Not Null,
  PlanTime datetime Not Null default(getdate()),
  PlanExecTime datetime null ,
  PlanType varchar(50) not null ,		-- * 整机迁移,部分迁移
  NetType varchar(50) null,				-- 公网(默认)/局域网
  SourceEDBA varchar(255) null,
  SourceVIP varchar(50) not null ,		-- *
  TargetVIP varchar(50) not null ,		-- *
  SourceStatus varchar(50) null ,
  TargetStatus varchar(50) null ,
  SourceVIPWeb varchar(50) null ,		-- * 源VIP Web地址
  TargetVIPWeb varchar(50) null ,		-- * 目标VIP Web地址
  SourceSerAdd varchar(50) null ,		-- * 源VIP SerAdd
  TargetSerAdd varchar(50) null ,		-- * 目标VIP SerAdd
  SourceEDBVersion varchar(50) null,	-- 源VIP版本
  TargetEDBVersion varchar(50) null,	-- 目标VIP版本
  SourceFreeDisk Decimal(30,6) null,	-- MB 单位
  TargetFreeDisk Decimal(30,6) null,	-- MB 单位
  SourceDBSizeTotal Decimal(30,6) null,	-- MB 单位 = SUM(SourceDBSize)
  PlanCheckResult varchar(255) null ,	-- 检查结果分析
  isLinked tinyint null  default(0),
  isOver tinyint null default(0),
  isEnable tinyint null default(0),
  SourceXLS int null default(0),
  isUseDiff tinyint null default(0),
  CONSTRAINT PK_MigrationPlan PRIMARY KEY  CLUSTERED
  (
    PlanID
  )
)
END

GO

/******************MigrationEDB structure *********************/
print 'dbo.MigrationEDB...'
if not exists (select * from sysobjects where id = object_id('dbo.MigrationEDB') and sysstat & 0xf = 3)
BEGIN --Drop Table MigrationEDB
CREATE TABLE dbo.MigrationEDB
(
  EdbID int identity(1,1) Not Null,
  PlanID int Not Null,					-- * 
  SourceVIP varchar(50) not null ,		-- * 冗余信息,便于查看
  TargetVIP varchar(50) not null ,		-- * 冗余信息,便于查看
  SourceEDB varchar(50) not null,		-- *
  SourceDBSize Decimal(30,6) null,		-- MB 单位
  ZIPDbSize bigint null,
  SourceStatus varchar(50) null ,
  TargetStatus varchar(50) null ,
  ZIPDiffSize bigint null,
  isBackupDiff tinyint null default(0),
  CONSTRAINT PK_MigrationEDB PRIMARY KEY  CLUSTERED
  (
    EdbID
  )
)
END

GO

/******************MigrationCommand structure *********************/
print 'dbo.MigrationCommand...'
if not exists (select * from sysobjects where id = object_id('dbo.MigrationCommand') and sysstat & 0xf = 3)
BEGIN -- Drop table MigrationCommand
CREATE TABLE dbo.MigrationCommand
(
  CommandID int identity(1,1) Not Null,
  CommandVIP varchar(50) Null,			-- * Source/Target/All
  PlanStatus varchar(50) Null,			-- * 
  EdbStatus varchar(50) Null,			-- * 
  NextStatus varchar(50) Null,			-- * Plan or Edb's Status
  CommandOrder int Not Null,			-- *
  CommandLine varchar(8000) Not Null,	-- * 
  CommandLog varchar(1000) Null,		-- * 
  CommandMemo varchar(1000) Null,		-- * 
  CONSTRAINT PK_MigrationCommand PRIMARY KEY  CLUSTERED
  (
    CommandID
  )
)
END

GO

/******************MigrationLog structure *********************/
print 'dbo.MigrationLog...'
if not exists (select * from sysobjects where id = object_id('dbo.MigrationLog') and sysstat & 0xf = 3)
BEGIN --Drop Table  MigrationLog
CREATE TABLE dbo.MigrationLog
(
  LogID int identity(1,1) Not Null,
  LogTime datetime Null default(getdate()),
  PlanID int Null,
  EdbID int Null,
  ExecVIP varchar(50) Null,
  ExecEdb varchar(50) null ,
  PlanStatus varchar(50) Null,
  EdbStatus varchar(50) Null,
  CommandLine varchar(8000) Null,
  CommandLog varchar(1000) Null,
  guid varchar(50) null,
  IsReport tinyint null,
  CONSTRAINT PK_MigrationLog PRIMARY KEY  CLUSTERED
  (
    LogID
  )
)
END

GO

/******************ServiceList structure *********************/
print 'dbo.ServiceList...'
if not exists (select * from sysobjects where id = object_id('dbo.ServiceList') and sysstat & 0xf = 3)
BEGIN --Drop Table  ServiceList
CREATE TABLE dbo.ServiceList
(
  ServiceID int identity(1,1) Not Null,
  ServiceName varchar(255) Null,
  ExecName varchar(255) null ,
  Memo varchar(255) Null,
  CONSTRAINT PK_ServiceList PRIMARY KEY  CLUSTERED
  (
    ServiceID
  )
)
END

GO