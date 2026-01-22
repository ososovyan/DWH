USE PharmacyDWH;
GO

-- 1. Удаляем таблицу логов, если она существует
IF OBJECT_ID(N'meta.MigrationLog', N'U') IS NOT NULL
BEGIN
    DROP TABLE meta.MigrationLog;
    PRINT 'Таблица meta.MigrationLog удалена.';
END
GO

-- 2. Удаляем схемы 

DECLARE @SchemasToDelete TABLE (SchemaName NVARCHAR(50));
INSERT INTO @SchemasToDelete (SchemaName) 
VALUES (N'meta'), (N'mart'), (N'srv'), (N'dwh'), (N'stg');

DECLARE @CurrentSchema NVARCHAR(50);
DECLARE SchemaCursor CURSOR FOR SELECT SchemaName FROM @SchemasToDelete;

OPEN SchemaCursor;
FETCH NEXT FROM SchemaCursor INTO @CurrentSchema;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC('DROP SCHEMA IF EXISTS ' + @CurrentSchema);
    PRINT 'Схема ' + @CurrentSchema + ' удалена (если была пуста).';
    
    FETCH NEXT FROM SchemaCursor INTO @CurrentSchema;
END

CLOSE SchemaCursor;
DEALLOCATE SchemaCursor;
GO