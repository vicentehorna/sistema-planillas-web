/*
    Validación PLAME: Neto a pagar (R01 SUNAT) vs Neto a recibir (planilla, FormulaCode = NETO).

    Usado por: POST /api/plame/validar/neto-r01

    Parámetros:
      @cia    — compañía
      @period — periodo tributario YYYYMM
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_validar_neto_r01_web]
    @cia VARCHAR(10),
    @period VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    DECLARE @cargaid INT;

    SELECT @cargaid = C.CargaId
    FROM PR_PlameSunatCarga C (NOLOCK)
    WHERE C.Company = @cia
      AND C.Period = @period;

    IF @cargaid IS NULL
    BEGIN
        RAISERROR('No hay carga SUNAT para la compañía y periodo indicados.', 16, 1);
        RETURN;
    END

    ;WITH SunatR01 AS (
        SELECT
            LTRIM(RTRIM(ISNULL(F.TipoDoc, ''))) AS tipodoc,
            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) AS documentnumber,
            LTRIM(RTRIM(ISNULL(F.LastName1, ''))) AS lastname1,
            LTRIM(RTRIM(ISNULL(F.LastName2, ''))) AS lastname2,
            LTRIM(RTRIM(ISNULL(F.Names, ''))) AS names,
            TRY_CAST(JSON_VALUE(F.MontosJson, '$."Neto a pagar"') AS DECIMAL(18, 2)) AS neto_sunat
        FROM PR_PlameSunatFila F (NOLOCK)
        WHERE F.CargaId = @cargaid
          AND F.Archivo = 'R01'
          AND ISNULL(LTRIM(RTRIM(F.DocumentNumber)), '') <> ''
    ),
    PlanillaNeto AS (
        SELECT
            LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) AS documentnumber,
            SUM(ISNULL(EPC.ConceptValueLo, 0)) AS neto_planilla
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK)
                ON EPC.Concept = C.Concept
               AND C.Company = @cia
            INNER JOIN SY_Person P (NOLOCK)
                ON EPC.Person = P.Person
        WHERE EPC.Company = @cia
          AND LEFT(EPC.PRPeriod, 6) = @period
          AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'NETO'
          AND ISNULL(LTRIM(RTRIM(P.DocumentNumber)), '') <> ''
        GROUP BY LTRIM(RTRIM(ISNULL(P.DocumentNumber, '')))
    )
    SELECT
        COALESCE(S.tipodoc, '') AS tipodoc,
        COALESCE(S.documentnumber, P.documentnumber) AS documentnumber,
        LTRIM(RTRIM(
            COALESCE(S.lastname1, '') + ' ' +
            COALESCE(S.lastname2, '') + ' ' +
            COALESCE(S.names, '')
        )) AS nombre,
        ISNULL(S.neto_sunat, 0) AS neto_sunat,
        ISNULL(P.neto_planilla, 0) AS neto_planilla,
        ROUND(ISNULL(S.neto_sunat, 0) - ISNULL(P.neto_planilla, 0), 2) AS diferencia,
        CASE
            WHEN S.documentnumber IS NULL THEN 'SOLO_PLANILLA'
            WHEN P.documentnumber IS NULL THEN 'SOLO_SUNAT'
            WHEN ABS(ISNULL(S.neto_sunat, 0) - ISNULL(P.neto_planilla, 0)) < 0.005 THEN 'OK'
            ELSE 'DIFERENCIA'
        END AS estado
    INTO #Comparacion
    FROM SunatR01 S
        FULL OUTER JOIN PlanillaNeto P
            ON S.documentnumber = P.documentnumber;

    SELECT
        COUNT(*) AS total_filas,
        SUM(CASE WHEN estado = 'OK' THEN 1 ELSE 0 END) AS coinciden,
        SUM(CASE WHEN estado = 'DIFERENCIA' THEN 1 ELSE 0 END) AS con_diferencia,
        SUM(CASE WHEN estado = 'SOLO_SUNAT' THEN 1 ELSE 0 END) AS solo_sunat,
        SUM(CASE WHEN estado = 'SOLO_PLANILLA' THEN 1 ELSE 0 END) AS solo_planilla,
        ROUND(SUM(neto_sunat), 2) AS total_neto_sunat,
        ROUND(SUM(neto_planilla), 2) AS total_neto_planilla,
        ROUND(SUM(neto_sunat) - SUM(neto_planilla), 2) AS total_diferencia
    FROM #Comparacion;

    SELECT
        tipodoc,
        documentnumber,
        nombre,
        neto_sunat,
        neto_planilla,
        diferencia,
        estado
    FROM #Comparacion
    ORDER BY
        CASE estado
            WHEN 'DIFERENCIA' THEN 1
            WHEN 'SOLO_SUNAT' THEN 2
            WHEN 'SOLO_PLANILLA' THEN 3
            ELSE 4
        END,
        nombre,
        documentnumber;

    DROP TABLE #Comparacion;
END
GO
