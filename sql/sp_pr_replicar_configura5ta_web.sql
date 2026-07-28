/*
    Replica la configuración 5ta de @cia_origen a todas las demás empresas activas.

    Mapeo por compañía destino:
      ProcessType → mismo ShortName en PR_ProcessType
      Concept     → mismo FormulaCode en PR_Concept

    Omite filas sin mapeo (no aborta). Reemplaza la config destino completa
    solo si al menos una fila pudo mapearse; si ninguna mapea, deja destino intacto
    y lo reporta.

    Usado por: POST /api/configura5ta/replicar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_replicar_configura5ta_web]
    @cia_origen VARCHAR(4),
    @userid     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia_origen = LTRIM(RTRIM(ISNULL(@cia_origen, '')));
    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));

    IF @cia_origen = ''
    BEGIN
        RAISERROR('Indique la compañía origen.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (SELECT 1 FROM PR_Configura5ta (NOLOCK) WHERE Company = @cia_origen)
    BEGIN
        RAISERROR('La compañía origen no tiene configuración 5ta para replicar.', 16, 1);
        RETURN;
    END

    DECLARE @cias TABLE (Company VARCHAR(4) PRIMARY KEY);
    INSERT INTO @cias (Company)
    SELECT LTRIM(RTRIM(SC.Company))
    FROM SY_Company SC (NOLOCK)
    WHERE UPPER(LTRIM(RTRIM(ISNULL(SC.[status], '')))) = 'A'
      AND LTRIM(RTRIM(SC.Company)) <> @cia_origen;

    DECLARE @cia_dest VARCHAR(4);
    DECLARE @ok INT = 0;
    DECLARE @skip INT = 0;
    DECLARE @warn INT = 0;

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT Company FROM @cias ORDER BY Company;
    OPEN cur;
    FETCH NEXT FROM cur INTO @cia_dest;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;

            IF OBJECT_ID('tempdb..#cfg5ta_map') IS NOT NULL DROP TABLE #cfg5ta_map;
            CREATE TABLE #cfg5ta_map (
                Type        VARCHAR(2)  NOT NULL,
                line        INT         NOT NULL,
                ProcessType VARCHAR(20) NOT NULL,
                Concept     VARCHAR(20) NOT NULL,
                ApplySum    VARCHAR(1)  NOT NULL
            );

            INSERT INTO #cfg5ta_map (Type, line, ProcessType, Concept, ApplySum)
            SELECT
                S.Type,
                S.line,
                PDT.ProcessType,
                CDT.Concept,
                ISNULL(S.ApplySum, 'P')
            FROM PR_Configura5ta S (NOLOCK)
                INNER JOIN PR_ProcessType PSO (NOLOCK)
                    ON PSO.Company = S.Company
                   AND PSO.ProcessType = S.ProcessType
                INNER JOIN PR_Concept CSO (NOLOCK)
                    ON CSO.Company = S.Company
                   AND CSO.Concept = S.Concept
                INNER JOIN PR_ProcessType PDT (NOLOCK)
                    ON PDT.Company = @cia_dest
                   AND PDT.ShortName = PSO.ShortName
                INNER JOIN PR_Concept CDT (NOLOCK)
                    ON CDT.Company = @cia_dest
                   AND CDT.FormulaCode = CSO.FormulaCode
            WHERE S.Company = @cia_origen;

            IF EXISTS (SELECT 1 FROM #cfg5ta_map)
            BEGIN
                DELETE FROM PR_Configura5ta WHERE Company = @cia_dest;

                INSERT INTO PR_Configura5ta (
                    Company, line, Plame, ProcessType, Concept, Type, ApplySum, XLastUser, XLastDate
                )
                SELECT
                    @cia_dest,
                    M.line,
                    '14',
                    M.ProcessType,
                    M.Concept,
                    M.Type,
                    CASE WHEN M.ApplySum = 'P' THEN 'P' ELSE 'M' END,
                    NULLIF(@userid, ''),
                    GETDATE()
                FROM #cfg5ta_map M;

                SET @ok = @ok + 1;
            END
            ELSE
            BEGIN
                SET @warn = @warn + 1;
            END

            COMMIT TRANSACTION;
        END TRY
        BEGIN CATCH
            IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
            SET @skip = @skip + 1;
        END CATCH

        IF OBJECT_ID('tempdb..#cfg5ta_map') IS NOT NULL DROP TABLE #cfg5ta_map;

        FETCH NEXT FROM cur INTO @cia_dest;
    END
    CLOSE cur;
    DEALLOCATE cur;

    SELECT
        @cia_origen AS company_origen,
        @ok AS cias_ok,
        @warn AS cias_sin_mapeo,
        @skip AS cias_error,
        'Replicacion de configuracion 5ta finalizada.' AS mensaje;
END
GO
