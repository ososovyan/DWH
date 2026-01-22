USE PharmacyDWH;
GO

DECLARE @ScriptName NVARCHAR(300) = N'02_meta_entity_and_orchestrator.sql';
DECLARE @Status NVARCHAR(50) = 'up';

BEGIN TRY
    -- Таблица в которой храниться связь сущности/ей пармера и трансформатора
    -- Идея оркестратор, который понимает по полученному .xml а именно по <type>
    -- какую сущность мы извлекаем
    IF OBJECT_ID(N'meta.EntityConfig', N'U') IS NULL
    BEGIN
        CREATE TABLE meta.EntityConfig (
            EntityCode NVARCHAR(100) PRIMARY KEY, -- Код 
            XmlType NVARCHAR(100) NOT NULL,       -- Что ищем в <type>
            StgParserProc NVARCHAR(100), -- Процедура для слоя stg (было StgProc)
            DwhTransformProc NVARCHAR(100)  -- Процедура для слоя dwh (было DwhProc)
        );
        PRINT 'Таблица meta.EntityConfig создана';
    END

    EXEC('
    CREATE OR ALTER PROCEDURE srv.ETLOrchestrator
        @FilePath NVARCHAR(MAX)
    AS
    BEGIN
        SET NOCOUNT ON;
        DECLARE @Xml XML, @Type NVARCHAR(100), @Stg NVARCHAR(100), @Dwh NVARCHAR(100);
        DECLARE @FID INT;
        DECLARE @FileName NVARCHAR(512) = REVERSE(LEFT(REVERSE(@FilePath), CHARINDEX(''\'', REVERSE(@FilePath)) - 1));

        -- Логируем в файл (просто и понятно)
        -- Перенесли в начало, чтобы зафиксировать даже ошибку загрузки файла
        INSERT INTO meta.FileImportLog (FileName, FilePath, Status) 
        VALUES (@FileName, @FilePath, ''Started'');
        
        SET @FID = SCOPE_IDENTITY();

        BEGIN TRY
            -- Загружаем файл
            DECLARE @SQL NVARCHAR(MAX) = N''SELECT @x = BulkColumn FROM OPENROWSET(BULK '''''' + @FilePath + '''''', SINGLE_BLOB) AS x'';
            EXEC sp_executesql @SQL, N''@x XML OUTPUT'', @x = @Xml OUTPUT;

            -- Читаем ТИП из файла
            SET @Type = @Xml.value(''(/root/type)[1]'', ''NVARCHAR(100)'');

            -- ВИщем в таблице (исправлены имена колонок на те, что в CREATE TABLE)
            SELECT @Stg = StgParserProc, @Dwh = DwhTransformProc 
            FROM meta.EntityConfig 
            WHERE XmlType = @Type;

            -- Проверка на наличие процедур в конфиге
            IF @Stg IS NULL OR @Dwh IS NULL
            BEGIN 
                -- Объявляем @msg внутри блока, чтобы THROW ее видел
                DECLARE @msg NVARCHAR(2048) = N''Не знаю как парсить тип: '' + ISNULL(@Type, ''NULL''); 
                THROW 50001, @msg, 1; 
            END

            -- Загрузка в STG
            EXEC @Stg @XmlData = @Xml;
            
            -- Если есть процедура для DWH - запускаем и её
            EXEC @Dwh;

            -- Если дошли сюда - успех
            UPDATE meta.FileImportLog 
            SET Status = ''Success'', 
                ImportEnd = SYSDATETIME() 
            WHERE FileImportId = @FID;

        END TRY
        BEGIN CATCH
            -- Обновляем лог при любой ошибке (включая наш THROW и системные ошибки)
            UPDATE meta.FileImportLog 
            SET Status = ''Error'', 
                ErrorMessage = ERROR_MESSAGE(),
                ImportEnd = SYSDATETIME()
            WHERE FileImportId = @FID;

            PRINT ''Ошибка залогирована: '' + ERROR_MESSAGE();
            -- Пробрасываем ошибку дальше
            THROW; 
        END CATCH
    END');

    -- Логирование самой миграции
    INSERT INTO meta.MigrationLog (script_name, status) VALUES (@ScriptName, @Status);
END TRY
BEGIN CATCH
    INSERT INTO meta.MigrationLog (script_name, status, erorr)
    VALUES (@ScriptName, 'error', ERROR_MESSAGE());
    
    PRINT 'Ошибка при выполнении миграции: ' + ERROR_MESSAGE();
    THROW;
END CATCH