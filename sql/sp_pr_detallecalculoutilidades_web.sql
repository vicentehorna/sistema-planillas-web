/*
    Detalle de cálculo — constancia de utilidades.
    Usado por: POST /get_detalle_calculo_formato_utilidades

    Lista conceptos con flagafectoUtilidad = 'Y' del año de ejercicio indicado.
    El ejercicio es el año calendario anterior al periodo de utilidades:
      utilidad calculada en marzo 2026 → @ejercicio = '2025'
      (planillas con PRPeriod que inicia en 2025: 20250101, 20251212, etc.)

    Parámetros:
      @cia, @payrolltype, @ejercicio (4 dígitos), @person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_detallecalculoutilidades_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @ejercicio   VARCHAR(4),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @ejercicio = LTRIM(RTRIM(ISNULL(@ejercicio, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    SELECT
        ISNULL(PT.ShortName, '') AS proceso,
        ISNULL(PT.Description, '') AS proceso_descripcion,
        LTRIM(RTRIM(EC.PRPeriod)) AS periodo,
        ISNULL(NULLIF(LTRIM(RTRIM(C.PrintText)), ''), C.Description) AS concepto,
        C.FormulaCode AS formulacode,
        ISNULL(EC.ConceptValueLo, EC.ConceptValue) AS importe
    FROM PR_EmployeePayRollConcept EC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Company = EC.Company
           AND C.Concept = EC.Concept
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PT.ProcessType = EC.ProcessType
           AND PT.Company = EC.Company
    WHERE EC.Company = @cia
      AND EC.Person = @person
      AND EC.PayRollType = @payrolltype
      AND @ejercicio <> ''
      AND LEFT(LTRIM(RTRIM(EC.PRPeriod)), 4) = @ejercicio
      AND ISNULL(C.flagafectoUtilidad, 'N') = 'Y'
    ORDER BY
        PT.ShortName,
        EC.PRPeriod,
        concepto;
END
GO
