USE PharmacyDWH;
GO

DECLARE @ScriptName NVARCHAR(300) = '04_procedures_manufacturer.sql';
DECLARE @Status NVARCHAR(50) = 'down';

BEGIN TRY
    IF OBJECT_ID('dwh.Transform_Manufacturers', 'P') IS NOT NULL
    BEGIN
        DROP PROCEDURE dwh.Transform_Manufacturers;
        PRINT 'Процедура dwh.Transform_Manufacturers удалена';
    END

    IF OBJECT_ID('stg.Parse_Manufacturers', 'P') IS NOT NULL
    BEGIN
        DROP PROCEDURE stg.Parse_Manufacturers;
        PRINT 'Процедура stg.Parse_Manufacturers удалена';
    END

    -- Очистка ссылок в реестре конфигураций
    UPDATE meta.EntityConfig 
    SET StgParserProc = NULL,
        DwhTransformProc = NULL
    WHERE EntityCode = 'manufacturer';

    -- Регистрация отката миграции
    INSERT INTO meta.MigrationLog (script_name, status) 
    VALUES (@ScriptName, @Status);

END TRY
BEGIN CATCH
    -- Логирование ошибки отката
    INSERT INTO meta.MigrationLog (script_name, status, erorr) 
    VALUES (@ScriptName, 'error_down', ERROR_MESSAGE());
    
    PRINT 'Ошибка при откате миграции: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO