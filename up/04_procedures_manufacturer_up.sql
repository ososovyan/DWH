USE PharmacyDWH;
GO


-- XML -> STG
CREATE OR ALTER PROCEDURE stg.Parse_Manufacturers 
    @XmlData XML
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogId INT, @Rows INT;

    INSERT INTO meta.ProcedureLog (ProcedureName, Status) 
    VALUES ('stg.Parse_Manufacturers', 'Started');
    SET @LogId = SCOPE_IDENTITY();

    BEGIN TRY
		--наврное не обязательно с учетом тогда, что пушим в след слой только новые данные
		-- в теории для этого настроить сборщик мусора но пока так
		TRUNCATE TABLE stg.Manufacturers;

        INSERT INTO stg.Manufacturers (ManufacturerId, Name, CreatedDateRaw, LastUpdateRaw, LoadStatus)
        SELECT 
            T.c.value('(id)[1]', 'INT'),
            T.c.value('(name)[1]', 'NVARCHAR(500)'),
            T.c.value('(created_date)[1]', 'NVARCHAR(50)'),
            T.c.value('(last_update_date)[1]', 'NVARCHAR(50)'),
            'New'
        FROM @XmlData.nodes('/root/manufacturers/manufacturer') AS T(c);

        SET @Rows = @@ROWCOUNT;

        UPDATE meta.ProcedureLog SET 
            ExecutionEnd = SYSDATETIME(), RowsAffected = @Rows, Status = 'Success' 
        WHERE ProcedureLogId = @LogId;

        RETURN @Rows;
    END TRY
    BEGIN CATCH
        UPDATE meta.ProcedureLog SET 
            ExecutionEnd = SYSDATETIME(), Status = 'Error', ErrorMessage = ERROR_MESSAGE() 
        WHERE ProcedureLogId = @LogId;
        THROW;
    END CATCH
END;
GO

-- STG -> DWH
CREATE OR ALTER PROCEDURE dwh.Transform_Manufacturers
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @LogId INT, @SuccessRows INT = 0, @ErrorRows INT = 0;
    
    -- Переменные для чтения данных из STG
    DECLARE @CurrentID INT, @CurrentName NVARCHAR(500), @DateRaw NVARCHAR(50), @UpdateRaw NVARCHAR(50);

    -- Логируем старт в общую таблицу
    INSERT INTO meta.ProcedureLog (ProcedureName, Status) 
    VALUES ('dwh.Transform_Manufacturers', 'Started');
    SET @LogId = SCOPE_IDENTITY();

    -- Объявляем курсор для новых строк
	-- Идея следующая если прошлая процедура атомарна для файла то падаем мы при любой ошибке в файле
	-- Здась же хочется выгружать только валидные строки а ошибки логировать но не прерывая выполнения
	-- Условно это будет медленне тк мы будем загружать построчно, зато чистота данных и устойчивость к мусору xml
	-- при этом относительно универсальный подход для всех сущностей
	-- Это релизация  SCD Type 1, решил уточнить точно ли я правильно понял что нужен именно такой мердж
	-- Условно если хочется храниить историю изменений, то можно релизовать SCD Type 2, но понадобится тогда
	-- везде дальше для каждой строки остсояние активности
    DECLARE cur CURSOR FOR 
    SELECT ManufacturerId, Name, CreatedDateRaw, LastUpdateRaw 
    FROM stg.Manufacturers 
	WHERE LoadStatus = 'New';

    OPEN cur;
    FETCH NEXT FROM cur INTO @CurrentID, @CurrentName, @DateRaw, @UpdateRaw;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            -- Пытаемся атомарно вставить/обновить одну строку
            -- Если тут возникнет ошибка, мы упадем в CATCH этого блока
            MERGE dwh.DimManufacturers AS target
            USING (SELECT @CurrentID AS Mid, 
				@CurrentName AS Nm, 
                CAST(@DateRaw AS DATETIME) AS CD, 
				CAST(@UpdateRaw AS DATETIME) AS UD) AS src
            ON target.ManufacturerId = src.Mid
            WHEN MATCHED THEN 
                UPDATE SET target.Name = src.Nm, target.SourceLastUpdate = src.UD, target.AppliedAt = SYSDATETIME()
            WHEN NOT MATCHED THEN
                INSERT (ManufacturerId, Name, CreatedDate, SourceLastUpdate)
                VALUES (src.Mid, src.Nm, src.CD, src.UD);

            UPDATE stg.Manufacturers SET LoadStatus = 'Processed' 
            WHERE CURRENT OF cur; -- Помечаем текущую строку в курсоре
            SET @SuccessRows = @SuccessRows + 1;

        END TRY
        BEGIN CATCH
            -- ловим ошибку именно для этой строки
            UPDATE stg.Manufacturers SET 
                LoadStatus = 'Error', 
                ErrorMessage = ERROR_MESSAGE() 
            WHERE CURRENT OF cur;
            SET @ErrorRows = @ErrorRows + 1;
        END CATCH

        FETCH NEXT FROM cur INTO @CurrentID, @CurrentName, @DateRaw, @UpdateRaw;
    END

    CLOSE cur;
    DEALLOCATE cur;

    -- Финальный лог процедуры
    UPDATE meta.ProcedureLog SET 
        ExecutionEnd = SYSDATETIME(), 
        RowsAffected = @SuccessRows,
        Status = CASE WHEN @ErrorRows > 0 THEN 'Warning' ELSE 'Success' END,
        ErrorMessage = CASE WHEN @ErrorRows > 0 THEN 'Errors found in ' + CAST(@ErrorRows AS VARCHAR) + ' rows' ELSE NULL END
    WHERE ProcedureLogId = @LogId;

    RETURN @SuccessRows;
END;
GO

DECLARE @ScriptName NVARCHAR(300) = '04_procedures_manufacturer.sql'
DECLARE @Status NVARCHAR(50) = 'up';

-- Регистрация в конфиге и логирование миграции
BEGIN TRY
    -- Обновляем конфиг сущности
    UPDATE meta.EntityConfig 
    SET StgParserProc = 'stg.Parse_Manufacturers',
        DwhTransformProc = 'dwh.Transform_Manufacturers'
    WHERE EntityCode = 'manufacturer';

    -- Записываем успех миграции
    INSERT INTO meta.MigrationLog (script_name, status) 
    VALUES (@ScriptName, @Status);

END TRY
BEGIN CATCH
    INSERT INTO meta.MigrationLog (script_name, status, erorr) 
    VALUES ('04_procedures_manufacturer.sql', 'error', ERROR_MESSAGE());
    PRINT 'Ошибка в миграции: ' + ERROR_MESSAGE();
END CATCH
GO