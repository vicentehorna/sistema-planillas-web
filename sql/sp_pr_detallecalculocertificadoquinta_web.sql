/*
    Detalle de cálculo — sueldos/asignaciones y utilidades (certificado quinta).
    Usado por: POST /get_detalle_calculo_certificado_quinta

    Lista conceptos con flagafecto5ta = 'Y' de todos los procesos del año,
    incluyendo UTILIDADES (excluido del importe de sueldos pero visible en detalle).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_detallecalculocertificadoquinta_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @anio        VARCHAR(4),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @anio = LTRIM(RTRIM(ISNULL(@anio, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    SELECT
        ISNULL(PT.ShortName, '') AS proceso,
        ISNULL(PT.Description, '') AS proceso_descripcion,
        LTRIM(RTRIM(EC.PRPeriod)) AS periodo,
        ISNULL(NULLIF(LTRIM(RTRIM(C.PrintText)), ''), C.Description) AS concepto,
        C.FormulaCode AS formulacode,
        ISNULL(EC.ConceptValueLo, 0) AS importe,
        CASE
            WHEN ISNULL(PT.ShortName, '') = 'UTILIDADES' THEN 'UTILIDADES'
            ELSE 'SUELDOS'
        END AS tipo_linea
    FROM PR_EmployeePayRollConcept EC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Company = EC.Company AND C.Concept = EC.Concept
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PT.ProcessType = EC.ProcessType
    WHERE EC.Company = @cia
      AND EC.Person = @person
      AND EC.PayRollType = @payrolltype
      AND LEFT(LTRIM(RTRIM(EC.PRPeriod)), 4) = @anio
      AND ISNULL(C.flagafecto5ta, 'N') = 'Y'
    ORDER BY
        CASE WHEN ISNULL(PT.ShortName, '') = 'UTILIDADES' THEN 2 ELSE 1 END,
        PT.ShortName,
        EC.PRPeriod,
        concepto;
END
GO
