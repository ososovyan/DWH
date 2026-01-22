USE master;
GO
-- Создаем БД
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'PharmacyDWH')
BEGIN
    CREATE DATABASE PharmacyDWH;
    PRINT 'База данных PharmacyDWH создана';
END
GO

USE PharmacyDWH;
GO

-- Создаем слои

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'stg')
BEGIN
	EXEC('CREATE SCHEMA stg');
	PRINT 'Схема stg успешно создана';
END

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'dwh')
BEGIN
	EXEC('CREATE SCHEMA dwh');
	PRINT 'Схема dwh успешно создана';
END

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'srv')
BEGIN
	EXEC('CREATE SCHEMA srv');
	PRINT 'Схема srv успешно создана';
END

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'mart')
BEGIN
	EXEC('CREATE SCHEMA mart');
	PRINT 'Схема mart успешно создана';
END

IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'meta')
BEGIN
	EXEC('CREATE SCHEMA meta');
	PRINT 'Схема meta успешно создана';
END
GO

-- Создаем таблицу логирования миграций

IF OBJECT_ID(N'meta.MigrationLog', N'U') IS NULL
BEGIN
	CREATE TABLE meta.MigrationLog (
		[migration_id] INT IDENTITY(1,1) PRIMARY KEY,
		[script_name] NVARCHAR(300) NOT NULL,
		[applied_at] DATETIME DEFAULT SYSDATETIME(),
		[status] NVARCHAR(50) NOT NULL, -- up/down
		[erorr] NVARCHAR(MAX) NULL
    );
	PRINT 'Таблица meta.MigrationLog создана.';
END
GO
