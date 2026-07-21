/*
    Resumen planilla total (PLAME) por concepto y tipo de proceso.
    Usado por: POST /reporte_resumen_total (reporte_resumen_total.html).

    Agrupa importes monetarios con flag de boleta por:
    Mensual (FIN_DE_MES), Semanal, Vacaciones, Liquidación, CTS,
    Gratificación y Utilidades.

    Consolida TODAS las planillas de la compañía en cada columna de proceso.

    Filtro de periodo:
      - Todas las columnas: año-mes LEFT(prperiod, 6) = LEFT(@period, 6)
        (consolida todas las planillas; el día del periodo puede variar).
      - Semanal: además incluye ProcessType = PR_Mapping.PlanillaSemProcess.

    Parámetros:
      @cia, @period — obligatorios.
      @payrolltype  — reservado (compatibilidad; la web ya no lo envía / puede ir NULL o vacío).
      @person       — reservado (la web envía NULL).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteplame_total_web]
    @cia          VARCHAR(20),
    @payrolltype  VARCHAR(20) = NULL,
    @period       VARCHAR(20),
    @person       VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

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
        [Grati]        NUMERIC(19, 4) NULL,
        [Utilidades]   NUMERIC(19, 4) NULL
    ) ON [PRIMARY];

    /* Catálogo de conceptos presentes en el periodo (todas las columnas en cero). */
    INSERT INTO #Temporal (
        Tipo, PDT, Concepto, Mensual, Semanal, Liquida,
        Vacaciones, CTS, Grati, Utilidades
    )
    SELECT DISTINCT
        tipo,
        pdt,
        concepto,
        0, 0, 0, 0, 0, 0, 0
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
          AND (
                ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
             OR (
                    LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'UTILIDADES'
                AND LTRIM(RTRIM(ISNULL(PR_Concept.FormulaCode, ''))) = 'PART_NETA'
                )
          )
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND (
                        pt.ShortName IN ('FIN_DE_MES', 'SEMANAL', 'VACACIONES', 'LIQUIDACION', 'CTS', 'GRATIFICACION')
                     OR (
                            pt.ShortName = 'UTILIDADES'
                        AND LTRIM(RTRIM(ISNULL(PR_Concept.FormulaCode, ''))) = 'PART_NETA'
                     )
                  )
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
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(LTRIM(RTRIM(PR_EmployeePayRollConcept.PRPeriod)), 6) = LEFT(@period, 6)
          AND (
                ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
             OR (
                    LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'UTILIDADES'
                AND LTRIM(RTRIM(ISNULL(PR_Concept.FormulaCode, ''))) = 'PART_NETA'
                )
          )
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'FIN_DE_MES'
        GROUP BY
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* SEMANAL (todas las planillas) */
    UPDATE #Temporal
    SET Semanal = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(LTRIM(RTRIM(PR_EmployeePayRollConcept.PRPeriod)), 6) = LEFT(@period, 6)
          AND (
                ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
             OR (
                    LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'UTILIDADES'
                AND LTRIM(RTRIM(ISNULL(PR_Concept.FormulaCode, ''))) = 'PART_NETA'
                )
          )
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND (
                PR_EmployeePayRollConcept.ProcessType = PR_Mapping.PlanillaSemProcess
             OR LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'SEMANAL'
          )
        GROUP BY
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText
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
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
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
          AND (
                ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
             OR (
                    LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'UTILIDADES'
                AND LTRIM(RTRIM(ISNULL(PR_Concept.FormulaCode, ''))) = 'PART_NETA'
                )
          )
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'VACACIONES'
        GROUP BY
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText
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
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
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
          AND (
                ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
             OR (
                    LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'UTILIDADES'
                AND LTRIM(RTRIM(ISNULL(PR_Concept.FormulaCode, ''))) = 'PART_NETA'
                )
          )
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'LIQUIDACION'
        GROUP BY
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText
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
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
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
          AND (
                ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
             OR (
                    LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'UTILIDADES'
                AND LTRIM(RTRIM(ISNULL(PR_Concept.FormulaCode, ''))) = 'PART_NETA'
                )
          )
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'CTS'
        GROUP BY
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText
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
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
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
          AND (
                ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
             OR (
                    LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'UTILIDADES'
                AND LTRIM(RTRIM(ISNULL(PR_Concept.FormulaCode, ''))) = 'PART_NETA'
                )
          )
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'GRATIFICACION'
        GROUP BY
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* UTILIDADES: únicamente el concepto PART_NETA. */
    UPDATE #Temporal
    SET Utilidades = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
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
          AND (
                ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
             OR (
                    LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'UTILIDADES'
                AND LTRIM(RTRIM(ISNULL(PR_Concept.FormulaCode, ''))) = 'PART_NETA'
                )
          )
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND LTRIM(RTRIM(PR_ProcessType.ShortName)) = 'UTILIDADES'
          AND LTRIM(RTRIM(ISNULL(PR_Concept.FormulaCode, ''))) = 'PART_NETA'
        GROUP BY
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    SELECT #Temporal.*
    FROM #Temporal
        INNER JOIN PR_ConceptType
            ON UPPER(LTRIM(RTRIM(#Temporal.Tipo))) = UPPER(LTRIM(RTRIM(PR_ConceptType.Description)))
           AND PR_ConceptType.Company = @cia
    ORDER BY
        CASE LTRIM(RTRIM(PR_ConceptType.ShortName))
            WHEN 'I' THEN 1
            WHEN 'D' THEN 2
            WHEN 'T' THEN 3
            WHEN 'A' THEN 4
            WHEN 'G' THEN 5
            WHEN 'X' THEN 6
            ELSE 9
        END,
        ISNULL(PR_ConceptType.ORDEN, 99),
        #Temporal.Concepto;
END
GO
