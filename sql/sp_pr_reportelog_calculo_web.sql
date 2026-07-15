/*
    Log de cálculo de planillas — detalle por persona y concepto.
    Usado por: POST /reporte_log_calculo (reporte_log_calculo.html).

    Basado en sp_pr_reportelog_calculo legacy (PowerBuilder).

    Parámetros (mismo criterio que planilla vertical):
      @cia         — compañía
      @payrolltype — tipo de planilla
      @process     — tipo de proceso
      @period      — periodo (YYYYMMDD)
      @person      — código persona; '0' = todos

    Ejemplo:
      EXEC sp_pr_reportelog_calculo_web
           @cia = 'BGT',
           @payrolltype = 'LIMABGT 000000000005',
           @process = 'BGT 000000000011',
           @period = '20260404',
           @person = '0';
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportelog_calculo_web]
    @cia         CHAR(4),
    @payrolltype VARCHAR(20),
    @process     VARCHAR(20),
    @period      VARCHAR(8),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @person = LTRIM(RTRIM(ISNULL(@person, '0')));
    IF @person = '' SET @person = '0';

    ;WITH periodbegin_map AS (
        SELECT
            epc.Person,
            c.FormulaCode,
            MIN(epc.PeriodBegin) AS periodbegin
        FROM PR_EmployeePayRollConcept epc
        INNER JOIN PR_Concept c
            ON c.Company = epc.Company
           AND c.Concept = epc.Concept
        WHERE epc.Company = @cia
          AND epc.PayRollType = @payrolltype
          AND epc.ProcessType = @process
          AND epc.PRPeriod = @period
        GROUP BY epc.Person, c.FormulaCode
    )
    SELECT
        SY_Person.Person AS person,
        SY_Person.Name AS name,
        PR_LOG_CALCULO_PLANILLAS.fecha AS fecha,
        PR_Concept.Description AS concepto,
        PR_Concept.FormulaCode AS formulacode,
        PR_LOG_CALCULO_PLANILLAS.importe AS importe,
        PR_ConceptType.Description AS tipoconcepto,
        CASE
            WHEN PR_LOG_CALCULO_PLANILLAS.tipo = 'F' THEN 'Formula'
            ELSE 'De Asignación'
        END AS tipocalculo,
        ISNULL(PR_Concept.flaginsertar, 'N') AS flaginsertar,
        ISNULL(PR_Concept.flagafecto5ta, 'N') AS flagafecto5ta,
        ISNULL(PR_Concept.flagafectoAFP, 'N') AS flagafectoafp,
        pb.periodbegin AS periodbegin
    FROM PR_LOG_CALCULO_PLANILLAS
    LEFT JOIN PR_Concept
        ON PR_LOG_CALCULO_PLANILLAS.concepto = PR_Concept.FormulaCode
       AND PR_Concept.Company = @cia
    LEFT JOIN PR_ConceptType
        ON PR_Concept.ConceptType = PR_ConceptType.ConceptType
    INNER JOIN SY_Person
        ON PR_LOG_CALCULO_PLANILLAS.person = SY_Person.Person
    LEFT JOIN periodbegin_map pb
        ON pb.Person = PR_LOG_CALCULO_PLANILLAS.person
       AND pb.FormulaCode = PR_LOG_CALCULO_PLANILLAS.concepto
    WHERE PR_LOG_CALCULO_PLANILLAS.Company = @cia
      AND PR_LOG_CALCULO_PLANILLAS.payrolltype = @payrolltype
      AND PR_LOG_CALCULO_PLANILLAS.process = @process
      AND PR_LOG_CALCULO_PLANILLAS.period = @period
      AND (@person = '0' OR PR_LOG_CALCULO_PLANILLAS.person = @person)
    ORDER BY
        PR_ConceptType.Description,
        SY_Person.Name,
        PR_LOG_CALCULO_PLANILLAS.fecha;
END
GO
