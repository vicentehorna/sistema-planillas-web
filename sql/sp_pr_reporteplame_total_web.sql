/*
    Resumen planilla total (PLAME) por concepto y tipo de proceso.
    Usado por: POST /reporte_resumen_total (reporte_resumen_total.html).

    Agrupa importes monetarios con flag de boleta por:
    Mensual (FIN_DE_MES), Semanal, Vacaciones, Liquidación, CTS y Gratificación.

    Parámetros:
      @cia, @payrolltype, @period — obligatorios para filtrar.
      @person — reservado (la web envía NULL).

    Ejemplo:
      EXEC sp_pr_reporteplame_total_web 'BGT', 'LIMABGT 000000000005', '20260404', NULL;
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteplame_total_web]
    @cia          VARCHAR(20),
    @payrolltype  VARCHAR(20),
    @period       VARCHAR(20),
    @person       VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE [#Temporal] (
        [Tipo]         VARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [PDT]          VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [Concepto]     VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [TipoPlanilla] VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [Mensual]      NUMERIC(19, 4),
        [Semanal]      NUMERIC(19, 4),
        [Liquida]      NUMERIC(19, 4),
        [Vacaciones]   NUMERIC(19, 4),
        [CTS]          NUMERIC(19, 4),
        [Grati]        NUMERIC(19, 4) NULL
    ) ON [PRIMARY];

    /* Catálogo de conceptos presentes en el periodo (todas las columnas en cero). */
    INSERT INTO #Temporal (Tipo, PDT, Concepto, Mensual, Semanal, Liquida, Vacaciones, CTS)
    SELECT DISTINCT
        tipo,
        pdt,
        concepto,
        0, 0, 0, 0, 0
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('FIN_DE_MES', 'SEMANAL', 'VACACIONES', 'LIQUIDACION', 'CTS')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T;

    /* FIN DE MES → Mensual */
    UPDATE #Temporal
    SET Mensual = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('FIN_DE_MES')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* SEMANAL */
    UPDATE #Temporal
    SET Semanal = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('SEMANAL')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* VACACIONES */
    UPDATE #Temporal
    SET Vacaciones = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('VACACIONES')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* LIQUIDACION */
    UPDATE #Temporal
    SET Liquida = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('LIQUIDACION')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* CTS */
    UPDATE #Temporal
    SET CTS = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('CTS')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* GRATIFICACION */
    UPDATE #Temporal
    SET Grati = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('GRATIFICACION')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    SELECT #Temporal.*
    FROM #Temporal
        INNER JOIN PR_ConceptType
            ON #Temporal.Tipo = PR_ConceptType.Description
           AND PR_ConceptType.Company = @cia
    ORDER BY PR_ConceptType.ORDEN, 3;
END
GO
