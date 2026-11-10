/*
    Barrido de periodos vacacionales para reingresantes.

    Para cada empleado con ReEntryDate:
      1) EXEC sp_pr_actualizar_vacaciones (borra periodos < año reingreso y
         realinea fechas de provision/derecho al MD del reingreso).
      2) EXEC sp_pr_generar_periodos_vacacionales_web (crea faltantes).

    Parámetros:
      @company     — compañía; vacío = todas.
      @personlist  — lista de Person separados por coma; vacío = todos con ReEntryDate.
      @solo_desfase — Y = solo si hay periodos con MD distinto al reingreso o ControlYear < año reingreso.
      @xlastuser   — auditoría (pasa a generar_periodos).

    Ejemplo:
      EXEC sp_pr_actualizar_vacaciones_reingresantes_web @company='BGT';
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_vacaciones_reingresantes_web]
    @company      VARCHAR(4) = NULL,
    @personlist   VARCHAR(MAX) = NULL,
    @solo_desfase CHAR(1) = 'Y',
    @xlastuser    VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = NULLIF(LTRIM(RTRIM(ISNULL(@company, ''))), '');
    SET @personlist = NULLIF(LTRIM(RTRIM(ISNULL(@personlist, ''))), '');
    SET @solo_desfase = UPPER(ISNULL(@solo_desfase, 'Y'));
    IF @solo_desfase NOT IN ('Y', 'N') SET @solo_desfase = 'Y';
    SET @xlastuser = ISNULL(NULLIF(LTRIM(RTRIM(@xlastuser)), ''), 'REINGRESO');

    IF OBJECT_ID(N'tempdb..#personas_filtro') IS NOT NULL DROP TABLE #personas_filtro;
    CREATE TABLE #personas_filtro (person VARCHAR(20) NOT NULL PRIMARY KEY);

    IF @personlist IS NOT NULL
    BEGIN
        INSERT INTO #personas_filtro (person)
        SELECT DISTINCT LTRIM(RTRIM(value))
        FROM STRING_SPLIT(@personlist, ',')
        WHERE LTRIM(RTRIM(value)) <> '';
    END;

    IF OBJECT_ID(N'tempdb..#reing') IS NOT NULL DROP TABLE #reing;
    CREATE TABLE #reing (
        company VARCHAR(4) NOT NULL,
        person  VARCHAR(20) NOT NULL,
        PRIMARY KEY (company, person)
    );

    INSERT INTO #reing (company, person)
    SELECT e.Company, e.Person
    FROM PR_Employee e (NOLOCK)
    WHERE e.ReEntryDate IS NOT NULL
      AND (@company IS NULL OR e.Company = @company)
      AND (
            @personlist IS NULL
         OR EXISTS (SELECT 1 FROM #personas_filtro pf WHERE pf.person = e.Person)
      )
      AND (
            @solo_desfase = 'N'
         OR EXISTS (
                SELECT 1
                FROM PR_Vacation v (NOLOCK)
                WHERE v.Company = e.Company
                  AND v.Person = e.Person
                  AND v.status = 'A'
                  AND (
                        MONTH(v.DateBeginProvision) <> MONTH(e.ReEntryDate)
                     OR DAY(v.DateBeginProvision) <> DAY(e.ReEntryDate)
                     OR CAST(v.ControlYear AS INT) < YEAR(e.ReEntryDate)
                  )
            )
          );

    DECLARE @cia VARCHAR(4), @person VARCHAR(20);
    DECLARE @procesados INT = 0;
    DECLARE @errores INT = 0;

    DECLARE @gen_vac TABLE (
        personas_procesadas INT,
        periodos_creados INT,
        periodos_actualizados INT,
        mensaje VARCHAR(200)
    );

    DECLARE c CURSOR LOCAL FAST_FORWARD FOR
        SELECT company, person FROM #reing ORDER BY company, person;

    OPEN c;
    FETCH NEXT FROM c INTO @cia, @person;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            EXEC dbo.sp_pr_actualizar_vacaciones @cia = @cia, @person = @person;

            IF OBJECT_ID(N'dbo.sp_pr_generar_periodos_vacacionales_web', N'P') IS NOT NULL
            BEGIN
                DELETE FROM @gen_vac;

                INSERT INTO @gen_vac
                EXEC dbo.sp_pr_generar_periodos_vacacionales_web
                    @company = @cia,
                    @payrolltype = '0',
                    @personlist = @person,
                    @solo_activos = 'N',
                    @xlastuser = @xlastuser;
            END

            SET @procesados = @procesados + 1;
        END TRY
        BEGIN CATCH
            SET @errores = @errores + 1;
        END CATCH;

        FETCH NEXT FROM c INTO @cia, @person;
    END
    CLOSE c;
    DEALLOCATE c;

    SELECT
        (SELECT COUNT(*) FROM #reing) AS candidatos,
        @procesados AS procesados,
        @errores AS errores,
        CASE
            WHEN @errores = 0 THEN 'Barrido de reingresantes concluido.'
            ELSE 'Barrido concluido con errores parciales.'
        END AS mensaje;
END
GO
