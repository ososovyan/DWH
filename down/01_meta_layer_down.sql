USE PharmacyDWH;
GO

DECLARE @ScriptName NVARCHAR(300) = N'01_meta_layer.sql';
DECLARE @Status NVARCHAR(50) = 'down';

BEGIN TRY
    -- удаление таблицы логирования процедур
    IF OBJECT_ID(N'meta.ProcedureLog', N'U') IS NOT NULL
    BEGIN
        DROP TABLE meta.ProcedureLog;
        PRINT 'Таблица meta.ProcedureLog удалена';
    END

    --Удаление таблицы логирования импорта файлов
    IF OBJECT_ID(N'meta.FileImportLog', N'U') IS NOT NULL
    BEGIN
        DROP TABLE meta.FileImportLog;
        PRINT 'Таблица meta.FileImportLog удалена';
    END

    -- Регистрация отката в журнале
    INSERT INTO meta.MigrationLog (script_name, status)
    VALUES (@ScriptName, @Status);

END TRY
BEGIN CATCH
    -- Регистрация ошибки в журнале
    INSERT INTO meta.MigrationLog (script_name, status, erorr)
    VALUES (@ScriptName, 'error_down', ERROR_MESSAGE());
    
    PRINT 'Ошибка при откате: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO