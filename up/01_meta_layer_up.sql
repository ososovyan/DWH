USE PharmacyDWH;
GO

--  для логирования миграции
DECLARE @ScriptName NVARCHAR(300) = N'01_meta_layer.sql.sql';
DECLARE @Status NVARCHAR(50) = 'up';


BEGIN TRY
    -- Таблица логирования процедур

    IF OBJECT_ID(N'meta.ProcedureLog', N'U') IS NULL
    BEGIN
        CREATE TABLE meta.ProcedureLog (
            ProcedureLogId INT IDENTITY(1,1) PRIMARY KEY,
            ProcedureName  NVARCHAR(255) NOT NULL,
            Parameters     NVARCHAR(MAX) NULL, 
            ExecutionStart DATETIME DEFAULT SYSDATETIME(),
            ExecutionEnd   DATETIME NULL,
            RowsAffected   INT NULL,
            Status         NVARCHAR(50) DEFAULT 'Started', 
            ErrorMessage   NVARCHAR(MAX) NULL
        );
        PRINT 'Таблица meta.ProcedureLog создана';
    END

    -- Таблица логирования импорта файлов 
    IF OBJECT_ID(N'meta.FileImportLog', N'U') IS NULL
    BEGIN
        CREATE TABLE meta.FileImportLog (
            FileImportId   INT IDENTITY(1,1) PRIMARY KEY,
            FileName       NVARCHAR(512) NOT NULL,
            FilePath       NVARCHAR(MAX) NOT NULL,
            ImportStart    DATETIME DEFAULT SYSDATETIME(),
            ImportEnd      DATETIME NULL,
            Status         NVARCHAR(50) DEFAULT 'Started', 
            ErrorMessage   NVARCHAR(MAX) NULL
        );
        PRINT 'Таблица meta.FileImportLog создана';
    END

    -- 
    INSERT INTO meta.MigrationLog (script_name, status)
    VALUES (@ScriptName, @Status);

END TRY
BEGIN CATCH
    -- При успехе пишем в таблицу миграций up
    INSERT INTO meta.MigrationLog (script_name, status, erorr)
    VALUES (@ScriptName, 'error', ERROR_MESSAGE());
    
    PRINT 'Ошибка при выполнении миграции: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO