USE PharmacyDWH;
GO

DECLARE @ScriptName NVARCHAR(300) = N'03_entity_manufacturer.sql';
DECLARE @Status NVARCHAR(50) = 'down';

BEGIN TRY
    -- Удаляем регистрацию из реестра конфигураций
    IF EXISTS (SELECT 1 FROM meta.EntityConfig WHERE EntityCode = 'manufacturer')
    BEGIN
        DELETE FROM meta.EntityConfig WHERE EntityCode = 'manufacturer';
        PRINT 'Запись о сущности manufacturer удалена из реестра meta.EntityConfig';
    END

    -- Удаляем индексы и таблицу из слоя dwh
    IF OBJECT_ID(N'dwh.DimManufacturers', N'U') IS NOT NULL
    BEGIN
        DROP TABLE dwh.DimManufacturers;
        PRINT 'Таблица dwh.DimManufacturers удалена';
    END

    -- удаляем таблицу из слоя stg
    IF OBJECT_ID(N'stg.Manufacturers', N'U') IS NOT NULL
    BEGIN
        DROP TABLE stg.Manufacturers;
        PRINT 'Таблица stg.Manufacturers удалена';
    END

    -- Логирование миграций
    INSERT INTO meta.MigrationLog (script_name, status) 
    VALUES (@ScriptName, @Status);

END TRY
BEGIN CATCH
    INSERT INTO meta.MigrationLog (script_name, status, erorr) 
    VALUES (@ScriptName, 'error_down', ERROR_MESSAGE());
    PRINT 'Ошибка при выполнении отката миграции: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO