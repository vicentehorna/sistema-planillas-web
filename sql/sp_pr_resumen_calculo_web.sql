/*
    Resumen de cálculo de planilla por concepto (agrupado).
    Usado por: POST /api/procesar-planilla/resumen-calculo

    Filtra PR_EmployeePayRollConcept por compañía, tipo planilla, proceso, periodo
    y lista de trabajadores (@personas separados por coma).

    Devuelve importes sumados por concepto con tipo (ingreso, descuento, auxiliar, etc.).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_resumen_calculo_web]
    @cia         VARCHAR(10),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(20),
    @personas    VARCHAR(MAX)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @personas = LTRIM(RTRIM(ISNULL(@personas, '')));

    IF @cia = '' OR @payrolltype = '' OR @processtype = '' OR @period = '' OR @personas = ''
        RETURN;

    CREATE TABLE #Personas (
        person VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY
    );

    INSERT INTO #Personas (person)
    SELECT DISTINCT LTRIM(RTRIM(Split.a.value('.', 'VARCHAR(20)')))
    FROM (
        SELECT CAST('<x>' + REPLACE(@personas, ',', '</x><x>') + '</x>' AS XML) AS x
    ) t
    CROSS APPLY x.nodes('/x') Split(a)
    WHERE LTRIM(RTRIM(Split.a.value('.', 'VARCHAR(20)'))) <> '';

    SELECT
        ISNULL(NULLIF(LTRIM(RTRIM(C.PrintText)), ''), C.Description) AS concepto,
        LTRIM(RTRIM(ISNULL(C.FormulaCode, ''))) AS formulacode,
        UPPER(LTRIM(RTRIM(ISNULL(CT.Description, '')))) AS tipo,
        LTRIM(RTRIM(ISNULL(CT.ShortName, ''))) AS tipo_codigo,
        COUNT(DISTINCT EC.Person) AS num_trabajadores,
        SUM(ISNULL(EC.ConceptValueLo, EC.ConceptValue)) AS importe
    FROM PR_EmployeePayRollConcept EC (NOLOCK)
        INNER JOIN #Personas SEL
            ON SEL.person = EC.Person
        INNER JOIN PR_Concept C (NOLOCK)
            ON C.Company = EC.Company
           AND C.Concept = EC.Concept
        INNER JOIN PR_ConceptType CT (NOLOCK)
            ON CT.ConceptType = C.ConceptType
    WHERE EC.Company = @cia
      AND EC.PayRollType = @payrolltype
      AND EC.ProcessType = @processtype
      AND LTRIM(RTRIM(EC.PRPeriod)) = @period
    GROUP BY
        ISNULL(NULLIF(LTRIM(RTRIM(C.PrintText)), ''), C.Description),
        C.FormulaCode,
        CT.Description,
        CT.ShortName,
        CT.ORDEN
    ORDER BY
        CT.ORDEN,
        tipo,
        concepto;
END
GO
