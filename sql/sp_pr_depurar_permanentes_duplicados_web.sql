/*
    Depura asignaciones permanentes duplicadas en PR_EmployeeConcept.

    Regla:
      - Por Company + Person + PayRollType + Concept con más de un FlagFrecuencyType='P':
      - Queda PERMANENTE el de mayor PRPeriodStart (empate: mayor CostCenter).
      - Los anteriores pasan a TEMPORAL (FlagFrecuencyType='T') con
        PRPeriodEnd = periodo inmediato anterior al inicio del siguiente registro
        (vía PR_Period.PeriodOrder-1; si no hay periodo, fallback YYYYMMDD mes-1).

    Ejemplo (VIDA LEY):
      20210101 P + 20211010 P
      → 20211010 permanece P
      → 20210101 pasa a T con PRPeriodEnd = 20210909

    Uso (NO aplica cambios si @ejecutar = 'N'):
      -- Preview hm_divisa / BGT / planilla empleados:
      EXEC sp_pr_depurar_permanentes_duplicados_web
           @cia='BGT', @payrolltype='BGT 000000000004', @ejecutar='N';

      -- Aplicar:
      EXEC sp_pr_depurar_permanentes_duplicados_web
           @cia='BGT', @payrolltype='BGT 000000000004', @ejecutar='Y';

      -- Toda la compañía (todas las planillas):
      EXEC sp_pr_depurar_permanentes_duplicados_web @cia='BGT', @payrolltype=NULL, @ejecutar='N';

    Resultsets:
      1) Filas a corregir (antes → después)
      2) Resumen (grupos, filas, actualizadas)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_depurar_permanentes_duplicados_web]
    @cia         VARCHAR(10),
    @payrolltype VARCHAR(20) = NULL,
    @ejecutar    CHAR(1) = 'N'   -- 'N' preview, 'Y' aplica UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = NULLIF(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), '');
    SET @ejecutar = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@ejecutar, 'N'))), 1));
    IF @ejecutar NOT IN ('Y', 'N')
        SET @ejecutar = 'N';

    IF @cia = ''
    BEGIN
        RAISERROR('Debe indicar @cia.', 16, 1);
        RETURN;
    END

    ;WITH base AS (
        SELECT
            EC.Person,
            EC.Company,
            EC.Concept,
            EC.PayRollType,
            EC.PRPeriodStart,
            EC.CostCenter,
            EC.FlagFrecuencyType,
            EC.PRPeriodEnd,
            EC.ConceptValue,
            C.FormulaCode,
            C.Description AS ConceptDescription,
            COUNT(*) OVER (
                PARTITION BY EC.Company, EC.Person, EC.PayRollType, EC.Concept
            ) AS cnt_grupo,
            ROW_NUMBER() OVER (
                PARTITION BY EC.Company, EC.Person, EC.PayRollType, EC.Concept
                ORDER BY EC.PRPeriodStart DESC, EC.CostCenter DESC
            ) AS rn_keep,
            LEAD(EC.PRPeriodStart) OVER (
                PARTITION BY EC.Company, EC.Person, EC.PayRollType, EC.Concept
                ORDER BY EC.PRPeriodStart ASC, EC.CostCenter ASC
            ) AS next_start
        FROM PR_EmployeeConcept EC WITH (NOLOCK)
            INNER JOIN PR_Concept C WITH (NOLOCK)
                ON C.Concept = EC.Concept
               AND C.Company = EC.Company
        WHERE EC.Company = @cia
          AND EC.FlagFrecuencyType = 'P'
          AND (@payrolltype IS NULL OR EC.PayRollType = @payrolltype)
    ),
    candidatas AS (
        SELECT
            b.*,
            CASE
                WHEN b.rn_keep = 1 THEN 'P'
                ELSE 'T'
            END AS nuevo_flag,
            CASE
                WHEN b.rn_keep = 1 THEN NULL
                ELSE COALESCE(
                    (
                        SELECT TOP 1 p2.PRPeriod
                        FROM PR_Period p1 WITH (NOLOCK)
                            INNER JOIN PR_Period p2 WITH (NOLOCK)
                                ON p2.Company = p1.Company
                               AND p2.PayRollType = p1.PayRollType
                               AND p2.PeriodOrder = p1.PeriodOrder - 1
                        WHERE p1.Company = b.Company
                          AND p1.PayRollType = b.PayRollType
                          AND p1.PRPeriod = b.next_start
                    ),
                    /* Fallback: periodo tipo YYYY + MM + MM (mes anterior). */
                    CASE
                        WHEN LEN(ISNULL(b.next_start, '')) = 8
                             AND b.next_start NOT LIKE '%[^0-9]%'
                        THEN
                            CASE
                                WHEN CONVERT(INT, SUBSTRING(b.next_start, 5, 2)) = 1
                                THEN CONVERT(CHAR(4), CONVERT(INT, LEFT(b.next_start, 4)) - 1)
                                     + '1212'
                                ELSE LEFT(b.next_start, 4)
                                     + RIGHT('0' + CONVERT(VARCHAR(2), CONVERT(INT, SUBSTRING(b.next_start, 5, 2)) - 1), 2)
                                     + RIGHT('0' + CONVERT(VARCHAR(2), CONVERT(INT, SUBSTRING(b.next_start, 5, 2)) - 1), 2)
                            END
                        ELSE NULL
                    END
                )
            END AS nuevo_period_end
        FROM base b
        WHERE b.cnt_grupo > 1
    )
    SELECT
        Person,
        Company,
        PayRollType,
        Concept,
        FormulaCode,
        ConceptDescription,
        CostCenter,
        ConceptValue,
        PRPeriodStart,
        FlagFrecuencyType AS flag_actual,
        NULLIF(LTRIM(RTRIM(ISNULL(PRPeriodEnd, ''))), '') AS period_end_actual,
        nuevo_flag,
        nuevo_period_end,
        CASE WHEN rn_keep = 1 THEN 'MANTIENE permanente' ELSE 'Convierte a temporal' END AS accion,
        next_start AS inicio_siguiente
    INTO #cambios
    FROM candidatas;

    /* Preview detalle */
    SELECT
        Person,
        FormulaCode,
        ConceptDescription,
        CostCenter,
        ConceptValue,
        PRPeriodStart,
        flag_actual,
        period_end_actual,
        nuevo_flag,
        nuevo_period_end,
        accion,
        inicio_siguiente
    FROM #cambios
    ORDER BY Person, FormulaCode, PRPeriodStart, CostCenter;

    DECLARE @grupos INT = (
        SELECT COUNT(*) FROM (
            SELECT Person, PayRollType, Concept
            FROM #cambios
            GROUP BY Person, PayRollType, Concept
        ) g
    );
    DECLARE @filas INT = (SELECT COUNT(*) FROM #cambios);
    DECLARE @a_temporal INT = (SELECT COUNT(*) FROM #cambios WHERE nuevo_flag = 'T');
    DECLARE @actualizadas INT = 0;

    IF @ejecutar = 'Y'
    BEGIN
        BEGIN TRAN;

        UPDATE EC
        SET
            EC.FlagFrecuencyType = C.nuevo_flag,
            EC.PRPeriodEnd = C.nuevo_period_end,
            EC.XLastUser = 'DEPURAR_PERM',
            EC.XLastDate = GETDATE()
        FROM PR_EmployeeConcept EC
            INNER JOIN #cambios C
                ON EC.Company = C.Company
               AND EC.Person = C.Person
               AND EC.Concept = C.Concept
               AND EC.PayRollType = C.PayRollType
               AND EC.PRPeriodStart = C.PRPeriodStart
               AND (
                    (EC.CostCenter = C.CostCenter)
                    OR (EC.CostCenter IS NULL AND C.CostCenter IS NULL)
               )
        WHERE EC.FlagFrecuencyType = 'P'
          AND (
                C.nuevo_flag = 'T'
                OR (
                    C.nuevo_flag = 'P'
                    AND NULLIF(LTRIM(RTRIM(ISNULL(EC.PRPeriodEnd, ''))), '') IS NOT NULL
                )
            );

        SET @actualizadas = @@ROWCOUNT;

        COMMIT TRAN;
    END

    SELECT
        @cia AS cia,
        ISNULL(@payrolltype, '(TODAS)') AS payrolltype,
        @ejecutar AS ejecutar,
        @grupos AS grupos_duplicados,
        @filas AS filas_en_grupos,
        @a_temporal AS filas_a_temporal,
        @actualizadas AS filas_actualizadas,
        CASE
            WHEN @ejecutar = 'Y' THEN 'APLICADO'
            ELSE 'PREVIEW (sin cambios). Ejecutar con @ejecutar=''Y'' para aplicar.'
        END AS estado;
END
GO
