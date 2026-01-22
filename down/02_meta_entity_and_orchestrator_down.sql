USE PharmacyDWH;
GO

DECLARE @ScriptName NVARCHAR(300) = N'02_meta_entity_and_orchestrator.sql';
DECLARE @Status NVARCHAR(50) = 'down';

BEGIN TRY
    -- удаляем процедуру-оркестратор
    IF OBJECT_ID(N'srv.ETLOrchestrator', N'P') IS NOT NULL
    BEGIN
        DROP PROCEDURE srv.ETLOrchestrator;
        PRINT 'Процедура srv.ETLOrchestrator удалена';
    END

    -- таблицу конфигурации сущностей.
    IF OBJECT_ID(N'meta.EntityConfig', N'U') IS NOT NULL
    BEGIN
        DROP TABLE meta.EntityConfig;
        PRINT 'Таблица meta.EntityConfig удалена';
    END

    -- логируем откат миграции
    INSERT INTO meta.MigrationLog (script_name, status) 
    VALUES (@ScriptName, @Status);

    PRINT 'Обратная миграция выполнена успешно';

END TRY
BEGIN CATCH
    PRINT 'Ошибка при выполнении обратной миграции: ' + ERROR_MESSAGE();
    THROW; 
END CATCH