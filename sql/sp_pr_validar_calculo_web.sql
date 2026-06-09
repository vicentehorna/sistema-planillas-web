/*
    Validaciones post-cálculo de planilla (módulo Procesar planilla).

    Usado por: POST /api/procesar-planilla/validar-calculo
    y al finalizar /ejecutar_calculo_streaming.

    Basado en: sp_pr_validar_calculo (legacy).

    Parámetros:
      @cia         — compañía
      @payrolltype — tipo de planilla
      @processtype — proceso
      @period      — periodo PRPeriod (ej. 20260505)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_validar_calculo_web]
    @cia         VARCHAR(10),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    CREATE TABLE #errores (
        person      VARCHAR(20) NULL,
        name        VARCHAR(200) NULL,
        observacion VARCHAR(500) NOT NULL
    );

    CREATE TABLE #lista_rem_basica (
        person VARCHAR(20) NOT NULL PRIMARY KEY
    );

    INSERT INTO #lista_rem_basica (person)
    SELECT EC.Person
    FROM PR_EmployeeConcept EC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON EC.Concept = C.Concept
           AND C.Company = @cia
    WHERE EC.Company = @cia
      AND EC.PayRollType = @payrolltype
      AND C.FormulaCode = 'REM_BASICA'
      AND EC.FlagFrecuencyType IN ('P', 'T')
      AND (
            (EC.FlagFrecuencyType = 'P' AND EC.PRPeriodStart <= @period)
            OR (EC.FlagFrecuencyType = 'T' AND @period BETWEEN EC.PRPeriodStart AND ISNULL(EC.PRPeriodEnd, EC.PRPeriodStart))
          )
      AND (
            EC.FlagFrecuencyType = 'T'
            OR (
                EC.FlagFrecuencyType = 'P'
                AND EC.PRPeriodStart = (
                    SELECT MAX(T.PRPeriodStart)
                    FROM PR_EmployeeConcept T (NOLOCK)
                    WHERE T.Company = EC.Company
                      AND T.Person = EC.Person
                      AND T.Concept = EC.Concept
                      AND T.PayRollType = EC.PayRollType
                )
            )
          )
    GROUP BY EC.Person;

    INSERT INTO #errores (person, name, observacion)
    SELECT
        E.Person,
        LTRIM(RTRIM(
            ISNULL(P.LastName1, '') + ' ' +
            ISNULL(P.LastName2, '') + ' ' +
            ISNULL(P.Name1, '') + ' ' +
            ISNULL(P.Name2, '')
        )),
        'No registra Remuneración Básica'
    FROM PR_Employee E (NOLOCK)
        INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
    WHERE E.Company = @cia
      AND E.PayRollType = @payrolltype
      AND E.Status = 'N'
      AND NOT EXISTS (
            SELECT 1 FROM #lista_rem_basica L WHERE L.person = E.Person
      );

    ;WITH Totales AS (
        SELECT
            EPC.Person,
            SUM(CASE WHEN C.FormulaCode = 'TOTALINGRESO' THEN ISNULL(EPC.ConceptValueLo, 0) ELSE 0 END) AS total_ingresos,
            SUM(CASE WHEN C.FormulaCode = 'TOTALEGRESOS' THEN ISNULL(EPC.ConceptValueLo, 0) ELSE 0 END) AS total_egresos,
            SUM(CASE WHEN C.FormulaCode = 'NETO' THEN ISNULL(EPC.ConceptValueLo, 0) ELSE 0 END) AS neto
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK)
                ON EPC.Concept = C.Concept
               AND C.Company = @cia
        WHERE EPC.Company = @cia
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND EPC.PRPeriod = @period
        GROUP BY EPC.Person
    )
    INSERT INTO #errores (person, name, observacion)
    SELECT
        E.Person,
        LTRIM(RTRIM(
            ISNULL(P.LastName1, '') + ' ' +
            ISNULL(P.LastName2, '') + ' ' +
            ISNULL(P.Name1, '') + ' ' +
            ISNULL(P.Name2, '')
        )),
        'Neto no coincide con Ingresos - Egresos'
    FROM Totales T
        INNER JOIN PR_Employee E (NOLOCK)
            ON T.Person = E.Person
           AND E.Company = @cia
           AND E.PayRollType = @payrolltype
           AND E.Status = 'N'
        INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
    WHERE ROUND(T.total_ingresos, 2) - ROUND(T.total_egresos, 2) <> ROUND(T.neto, 2);

    INSERT INTO #errores (person, name, observacion)
    SELECT NULL, NULL, T.Description + ' no tiene código PDT'
    FROM (
        SELECT DISTINCT C.Description
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK) ON EPC.Concept = C.Concept
            INNER JOIN PR_ConceptType CT (NOLOCK)
                ON C.ConceptType = CT.ConceptType
               AND CT.ShortName = 'I'
        WHERE EPC.Company = @cia
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND EPC.PRPeriod = @period
          AND ISNULL(C.pdt, '') = ''
        UNION
        SELECT DISTINCT C.Description
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK) ON EPC.Concept = C.Concept
            INNER JOIN PR_ConceptType CT (NOLOCK)
                ON C.ConceptType = CT.ConceptType
               AND CT.ShortName = 'D'
               AND ISNULL(C.FormulaCode, '') <> 'ONP'
        WHERE EPC.Company = @cia
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND EPC.PRPeriod = @period
          AND ISNULL(C.pdt, '') = ''
    ) T;

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene régimen de pensión'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.PensionType,
            PT.PDT
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
            INNER JOIN PR_EmployeeCategory ECAT (NOLOCK)
                ON E.EmployeeCategory = ECAT.EmployeeCategory
               AND ECAT.PDT = '1'
            LEFT JOIN PR_PensionType PT (NOLOCK)
                ON E.PensionType = PT.PensionType
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.PensionType, '') = '' OR T.PDT = '99';

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene cargo'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.Position
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.Position, '') = '';

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene cuenta bancaria'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.SalaryAccount
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.SalaryAccount, '') = '';

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene banco de haberes'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.SalaryBank
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.SalaryBank, '') = '';

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene tipo cuenta de haberes'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.SalaryAccountType
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.SalaryAccountType, '') = '';

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene perfil contable'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.AccountProfile
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.AccountProfile, '') = '';

    SELECT
        LTRIM(RTRIM(ISNULL(person, ''))) AS person,
        LTRIM(RTRIM(ISNULL(name, ''))) AS name,
        LTRIM(RTRIM(observacion)) AS observacion
    FROM #errores
    ORDER BY name, observacion;
END
GO
