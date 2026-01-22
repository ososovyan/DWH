USE PharmacyDWH;
GO

DECLARE @ScriptName NVARCHAR(300) = N'03_entity_manufacturer.sql';
DECLARE @Status NVARCHAR(50) = 'up';

BEGIN TRY
    -- слой stg 
    IF OBJECT_ID(N'stg.Manufacturers', N'U') IS NULL
    BEGIN
        CREATE TABLE stg.Manufacturers (
            ManufacturerId INT,                   
            Name NVARCHAR(500),         
            CreatedDateRaw NVARCHAR(50),         
            LastUpdateRaw NVARCHAR(50),          
            -- Технические поля для контроля качества
            LoadStatus NVARCHAR(20) DEFAULT 'New', -- New, Processed, Error
            ErrorMessage NVARCHAR(MAX) NULL,
            LoadedAt DATETIME DEFAULT SYSDATETIME()
        );
        PRINT 'Таблица stg.Manufacturers создана';
    END

    -- слой dwh 
    IF OBJECT_ID(N'dwh.DimManufacturers', N'U') IS NULL
    BEGIN
        CREATE TABLE dwh.DimManufacturers (
		    ManufacturerKey INT IDENTITY(1,1) PRIMARY KEY, -- Cурогатный для агрегации, чтобы не ломаться при чении данных других источников
		    ManufacturerId INT NOT NULL UNIQUE,
		    Name NVARCHAR(500) NOT NULL,
		    CreatedDate DATETIME NULL,       -- Перенос из <created_date>
		    SourceLastUpdate DATETIME NULL,       -- Перенос из <last_update_date>
		    AppliedAt DATETIME DEFAULT SYSDATETIME() -- Наша техническая метка
		);
        
        -- Индекс на имя так как по нему планируются фильтрации
        CREATE INDEX IX_DimManufacturers_Name ON dwh.DimManufacturers(Name);
        PRINT 'Таблица dwh.DimManufacturers и индексы созданы';
    END


    IF NOT EXISTS (SELECT 1 FROM meta.EntityConfig WHERE XmlType = 'manufacturer')
    BEGIN
        INSERT INTO meta.EntityConfig (EntityCode, XmlType, StgParserProc, DwhTransformProc)
        VALUES ('manufacturer', 'manufacturer', NULL, NULL);
        PRINT 'Сущность manufacturer зарегистрирована в реестре';
    END

    -- Фиксация миграции
    INSERT INTO meta.MigrationLog (script_name, status) 
	VALUES (@ScriptName, @Status);

END TRY
BEGIN CATCH
    INSERT INTO meta.MigrationLog (script_name, status, erorr) 
    VALUES (@ScriptName, 'error', ERROR_MESSAGE());
    PRINT 'Ошибка при выполнении миграции: ' + ERROR_MESSAGE();
    THROW;
END CATCH
GO