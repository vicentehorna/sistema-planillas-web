/*
    PLAME Archivo 14 — Validaciones de incidencias (trabajadores y horas trabajadas).

    Usado por: POST /api/plame/archivo-14/listado

    Reglas:
      - Cantidad de trabajadores del Archivo 14 = planilla del periodo (fin / semana).
      - Todo trabajador de planilla debe tener horas trabajadas (conceptos PLAME 14 type WH).

    Parámetros: mismos que sp_pr_listado_plame14_web.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_validar_archivo14_web]
    @cia    VARCHAR(4),
    @period VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    CREATE TABLE #Trab (
        person          VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY,
        documentnumber  VARCHAR(30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        name            VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        workinghours    NUMERIC(19, 4) NOT NULL,
        extrahours      NUMERIC(19, 4) NOT NULL
    );

    CREATE TABLE #msg (
        person  VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        mensaje VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
    );

    /* --- Misma población y cálculo que sp_pr_listado_plame14_web --- */
    INSERT INTO #Trab (person, documentnumber, name, workinghours, extrahours)
    SELECT
        T.person,
        MAX(T.documentnumber) AS documentnumber,
        MAX(T.name) AS name,
        MAX(T.workinghours) AS workinghours,
        MAX(T.extrahours) AS extrahours
    FROM (
        SELECT
            pr_employee.person AS person,
            sy_person.documentnumber AS documentnumber,
            LTRIM(RTRIM(
                ISNULL(sy_person.lastname1, '') + ' ' +
                ISNULL(sy_person.lastname2, '') + ' ' +
                ISNULL(sy_person.name1, '') + ' ' +
                ISNULL(sy_person.name2, '')
            )) AS name,
            ISNULL((
                SELECT SUM(ISNULL(E.ConceptValueLo, E.ConceptValue) * CASE WHEN P.applysum = 'P' THEN 1 ELSE -1 END)
                FROM PR_EmployeePayRollConcept E
                    INNER JOIN PR_Mapping M ON (E.Company = M.Company AND M.Company = @cia)
                    INNER JOIN PR_CompanyPlame P ON (
                        E.Concept = P.concept
                        AND E.Company = @cia
                        AND E.Person = pr_employeepayroll.Person
                        AND E.PRPeriod = pr_employeepayroll.PRPeriod
                        AND E.PayRollType = pr_employeepayroll.PayRollType
                        AND E.ProcessType IN (M.PlanillaProcess, M.PlanillaSemProcess)
                        AND P.plame = '14'
                        AND P.type = 'WH'
                    )
            ), 0) AS workinghours,
            ISNULL((
                SELECT SUM(ISNULL(E.ConceptValueLo, E.ConceptValue) * CASE WHEN P.applysum = 'P' THEN 1 ELSE -1 END)
                FROM PR_EmployeePayRollConcept E
                    INNER JOIN PR_Mapping M ON (E.Company = M.Company AND M.Company = @cia)
                    INNER JOIN PR_CompanyPlame P ON (
                        E.Concept = P.concept
                        AND E.Company = @cia
                        AND E.Person = pr_employeepayroll.Person
                        AND E.PRPeriod = pr_employeepayroll.PRPeriod
                        AND E.PayRollType = pr_employeepayroll.PayRollType
                        AND E.ProcessType IN (M.PlanillaProcess, M.PlanillaSemProcess)
                        AND P.plame = '14'
                        AND P.type = 'HE'
                    )
            ), 0) AS extrahours
        FROM pr_employee (NOLOCK)
            INNER JOIN SY_Company ON (PR_Employee.Company = SY_Company.Company AND pr_employee.company = @cia)
            INNER JOIN sy_person (NOLOCK) ON (sy_person.person = pr_employee.person)
            LEFT JOIN sy_persondocumenttype (NOLOCK) ON (sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype)
            INNER JOIN pr_employeecategory (NOLOCK) ON (pr_employee.employeecategory = pr_employeecategory.employeecategory)
            INNER JOIN pr_mapping (NOLOCK) ON (PR_Employee.Company = PR_Mapping.Company AND pr_mapping.company = @cia)
            INNER JOIN pr_employeepayroll (NOLOCK) ON (
                pr_employeepayroll.PayRollType = pr_employee.PayRollType
                AND pr_employeepayroll.Person = pr_employee.Person
                AND pr_employeepayroll.company = pr_employee.company
                AND pr_employeepayroll.ProcessType IN (pr_mapping.PlanillaProcess, pr_mapping.PlanillaSemProcess)
            )
        WHERE pr_employeecategory.PDT IN ('1')
          AND SUBSTRING(pr_employeepayroll.PRPeriod, 1, 6) = @period
    ) T
    GROUP BY T.person;

    /* --- Horas trabajadas en cero --- */
    INSERT INTO #msg (person, mensaje)
    SELECT
        person,
        'Trabajador sin horas trabajadas: '
        + LTRIM(RTRIM(ISNULL(name, '')))
        + ' (DNI '
        + LTRIM(RTRIM(ISNULL(documentnumber, '')))
        + ')'
    FROM #Trab
    WHERE ISNULL(workinghours, 0) <= 0;

    /* --- Cantidad de trabajadores: Archivo 14 exportable vs planilla --- */
    DECLARE @cnt_planilla INT;
    DECLARE @cnt_archivo14 INT;

    SELECT @cnt_planilla = COUNT(*) FROM #Trab;

    SELECT @cnt_archivo14 = COUNT(*)
    FROM #Trab
    WHERE ISNULL(workinghours, 0) > 0;

    IF @cnt_archivo14 <> @cnt_planilla
    BEGIN
        INSERT INTO #msg (person, mensaje)
        VALUES (
            NULL,
            'Cantidad de trabajadores no coincide: Archivo 14 tiene '
            + CAST(@cnt_archivo14 AS VARCHAR(10))
            + ', planilla tiene '
            + CAST(@cnt_planilla AS VARCHAR(10)) + '.'
        );
    END;

    SELECT person, mensaje
    FROM #msg
    ORDER BY CASE WHEN person IS NULL THEN 0 ELSE 1 END, mensaje;

    DROP TABLE #msg;
    DROP TABLE #Trab;
END
GO
