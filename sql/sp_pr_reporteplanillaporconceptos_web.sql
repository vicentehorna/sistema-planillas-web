/*
    Reporte Planilla por Conceptos — conceptos de ingreso calculados en planillas.
    Usado por: POST /api/reportes/planilla-por-conceptos

    Solo conceptos de ingreso (PR_ConceptType.ShortName = 'I') en el rango de periodos
    tributarios (@periodo_desde .. @periodo_hasta, formato YYYYMM, mismo criterio que PLAME).

    Filtros de afecto (@filtro_* = 'T' todos, 'Y' solo afectos):
      @filtro_afecto5ta, @filtro_afectoafp, @filtro_afectoutilidad
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteplanillaporconceptos_web]
    @company              VARCHAR(4),
    @periodo_desde        VARCHAR(6),
    @periodo_hasta        VARCHAR(6),
    @filtro_afecto5ta     CHAR(1) = 'T',
    @filtro_afectoafp     CHAR(1) = 'T',
    @filtro_afectoutilidad CHAR(1) = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @periodo_desde = LTRIM(RTRIM(ISNULL(@periodo_desde, '')));
    SET @periodo_hasta = LTRIM(RTRIM(ISNULL(@periodo_hasta, '')));
    SET @filtro_afecto5ta = UPPER(LTRIM(RTRIM(ISNULL(@filtro_afecto5ta, 'T'))));
    SET @filtro_afectoafp = UPPER(LTRIM(RTRIM(ISNULL(@filtro_afectoafp, 'T'))));
    SET @filtro_afectoutilidad = UPPER(LTRIM(RTRIM(ISNULL(@filtro_afectoutilidad, 'T'))));

    IF @filtro_afecto5ta NOT IN ('T', 'Y') SET @filtro_afecto5ta = 'T';
    IF @filtro_afectoafp NOT IN ('T', 'Y') SET @filtro_afectoafp = 'T';
    IF @filtro_afectoutilidad NOT IN ('T', 'Y') SET @filtro_afectoutilidad = 'T';

    SELECT
        ISNULL(SP.DocumentNumber, '') AS dni,
        LTRIM(RTRIM(
            ISNULL(SP.LastName1, '') + ' '
            + ISNULL(SP.LastName2, '') + ' '
            + ISNULL(SP.Name1, '') + ' '
            + ISNULL(SP.Name2, '')
        )) AS nombre,
        ISNULL(PT.Description, '') AS proceso,
        ISNULL(PR.Description, '') AS planilla,
        LTRIM(RTRIM(EC.PRPeriod)) AS periodo,
        ISNULL(NULLIF(LTRIM(RTRIM(C.PrintText)), ''), C.Description) AS concepto,
        ISNULL(EC.ConceptValueLo, EC.ConceptValue) AS importe
    FROM PR_EmployeePayRollConcept EC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Company = EC.Company
           AND C.Concept = EC.Concept
        INNER JOIN PR_ConceptType CT (NOLOCK)
            ON CT.ConceptType = C.ConceptType
           AND CT.ShortName = 'I'
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PT.ProcessType = EC.ProcessType
           AND PT.Company = EC.Company
        INNER JOIN PR_PayRollType PR (NOLOCK)
            ON PR.PayRollType = EC.PayRollType
        INNER JOIN SY_Person SP (NOLOCK)
            ON SP.Person = EC.Person
    WHERE EC.Company = @company
      AND LEN(@periodo_desde) = 6
      AND LEN(@periodo_hasta) = 6
      AND LEFT(LTRIM(RTRIM(EC.PRPeriod)), 6) >= @periodo_desde
      AND LEFT(LTRIM(RTRIM(EC.PRPeriod)), 6) <= @periodo_hasta
      AND (@filtro_afecto5ta <> 'Y' OR ISNULL(C.flagafecto5ta, 'N') = 'Y')
      AND (@filtro_afectoafp <> 'Y' OR ISNULL(C.flagafectoAFP, 'N') = 'Y')
      AND (@filtro_afectoutilidad <> 'Y' OR ISNULL(C.flagafectoUtilidad, 'N') = 'Y')
    ORDER BY
        SP.LastName1,
        SP.LastName2,
        SP.Name1,
        SP.Name2,
        PR.Description,
        PT.Description,
        EC.PRPeriod,
        C.PrintText,
        C.Description;
END
GO
