/*
    Asignación unificada de tareo → conceptos + descansos médicos (PLAME).
    Reemplazo set-based de:
      - sp_pr_interfazplanillas_ultra  → PR_EmployeeConcept (XLastUser='TAREO')
      - sp_pr_interfazplanillas_DM     → PR_EmployeeMedicalRest

    Fuente: PR_REGISTERHOUR en el rango CADateBegin/CADateEnd del periodo.
    Sin cursores. Idempotente: borra y regenera lo marcado TAREO / medical rest del periodo.

    Usado por: POST /api/tareo/asignacion/procesar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_asignar_tareo_periodo_web]
    @cia           VARCHAR(4),
    @period        VARCHAR(8),
    @payrolltype   VARCHAR(20),
    @person_all    CHAR(1) = 'Y',
    @person        VARCHAR(20) = NULL,
    @repunit_all   CHAR(1) = 'Y',
    @repunit       VARCHAR(20) = NULL,
    @cesados       CHAR(1) = 'T',   -- T=todos, Y=solo cesados, N=solo activos
    @xlastuser     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @inicio CHAR(8);
    DECLARE @fin CHAR(8);
    DECLARE @now DATETIME = GETDATE();
    DECLARE @personas INT = 0;
    DECLARE @conceptos INT = 0;
    DECLARE @eventos INT = 0;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @person_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@person_all, 'Y'))), 1));
    SET @person = NULLIF(LTRIM(RTRIM(ISNULL(@person, ''))), '');
    SET @repunit_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@repunit_all, 'Y'))), 1));
    SET @repunit = NULLIF(LTRIM(RTRIM(ISNULL(@repunit, ''))), '');
    SET @cesados = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@cesados, 'T'))), 1));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    IF @xlastuser IS NULL SET @xlastuser = 'WEB';
    IF @person_all NOT IN ('Y', 'N') SET @person_all = 'Y';
    IF @repunit_all NOT IN ('Y', 'N') SET @repunit_all = 'Y';
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    IF @cia = '' OR @period = '' OR @payrolltype = ''
    BEGIN
        RAISERROR('Indique compañía, periodo y tipo de planilla.', 16, 1);
        RETURN;
    END;

    IF @person_all = 'N' AND @person IS NULL
    BEGIN
        RAISERROR('Indique la persona a procesar.', 16, 1);
        RETURN;
    END;

    SELECT
        @inicio = CONVERT(VARCHAR(8), CADateBegin, 112),
        @fin = CONVERT(VARCHAR(8), CADateEnd, 112)
    FROM PR_Period (NOLOCK)
    WHERE Company = @cia
      AND PRPeriod = @period
      AND PayRollType = @payrolltype;

    IF @inicio IS NULL OR @fin IS NULL
    BEGIN
        RAISERROR('No existe el periodo indicado para la planilla.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        /* Igual que ultra: alinear ReplicationUnit del mes */
        UPDATE RH
        SET ReplicationUnit = P.ReplicationUnit
        FROM PR_REGISTERHOUR RH
        INNER JOIN SY_Person P ON P.Person = RH.Person
        WHERE CONVERT(VARCHAR(6), RH.RegisterDate, 112) = LEFT(@period, 6);

        /* Agregados por persona (equivalente al cursor de ultra) */
        IF OBJECT_ID('tempdb..#agg') IS NOT NULL DROP TABLE #agg;

        SELECT
            B.Person AS dni,
            ISNULL(RH.horas, 0) AS horas,
            ISNULL(RH.h25, 0) AS h25,
            ISNULL(RH.h35, 0) AS h35,
            ISNULL(RH.hnoc, 0) AS hnoc,
            ISNULL(RH.faltas, 0) AS faltas,
            ISNULL(RH.vacas, 0) AS vacas,
            ISNULL(RH.dm, 0) AS dm,
            ISNULL(RH.suspen, 0) AS suspen,
            ISNULL(RH.lcg, 0) AS lcg,
            ISNULL(RH.lsg, 0) AS lsg,
            ISNULL(RH.lpat, 0) AS lpat,
            ISNULL(RH.fer, 0) AS fer,
            ISNULL(RH.descanso, 0) AS descanso,
            ISNULL(RH.lma, 0) AS lma,
            ISNULL(RH.sub, 0) AS sub,
            ISNULL(RH.hfer, 0) AS hfer,
            E.CeaseDate AS ceasedate,
            ISNULL(E.ReEntryDate, E.EntryDate) AS entrydate,
            E.PayRollType AS payrolltype_emp,
            E.CostCenter AS costcenter,
            E.Costcentername AS costcentercode,
            CONVERT(NUMERIC(19, 4), 0) AS diastrab
        INTO #agg
        FROM (
            SELECT DISTINCT RH0.Person
            FROM PR_REGISTERHOUR RH0 (NOLOCK)
            INNER JOIN PR_Employee E0 (NOLOCK)
                ON E0.Person = RH0.Person
               AND E0.Company = @cia
               AND E0.Status = 'N'
            WHERE RH0.Company = @cia
              AND RH0.Payrolltype = @payrolltype
              AND CONVERT(VARCHAR(8), RH0.RegisterDate, 112) BETWEEN @inicio AND @fin
              AND (@person_all = 'Y' OR RH0.Person = @person)
              AND (@repunit_all = 'Y' OR RH0.ReplicationUnit = @repunit)
              AND (
                    @cesados = 'T'
                 OR (@cesados = 'Y' AND E0.CeaseDate IS NOT NULL)
                 OR (@cesados = 'N' AND E0.CeaseDate IS NULL)
              )
        ) B
        INNER JOIN PR_Employee E (NOLOCK)
            ON E.Person = B.Person AND E.Company = @cia AND E.Status = 'N'
        LEFT JOIN (
            SELECT
                a.Person,
                SUM(ISNULL(a.hourday, 0)) AS horas,
                SUM(ISNULL(a.extrahour25, 0)) AS h25,
                SUM(ISNULL(a.extrahour35, 0)) AS h35,
                SUM(ISNULL(a.extrahour100, 0)) AS hnoc,
                SUM(CASE WHEN a.RegisterType = 'F' THEN 1 ELSE 0 END) AS faltas,
                SUM(CASE WHEN a.RegisterType = 'V' THEN 1 ELSE 0 END) AS vacas,
                SUM(CASE WHEN a.RegisterType = 'DM' THEN 1 ELSE 0 END) AS dm,
                SUM(CASE WHEN a.RegisterType = 'S' THEN 1 ELSE 0 END) AS suspen,
                SUM(CASE WHEN a.RegisterType = 'LCG' THEN 1 ELSE 0 END) AS lcg,
                SUM(CASE WHEN a.RegisterType = 'LSG' THEN 1 ELSE 0 END) AS lsg,
                SUM(CASE WHEN a.RegisterType = 'LPA' THEN 1 ELSE 0 END) AS lpat,
                SUM(CASE WHEN a.RegisterType = 'FTD' THEN 1 ELSE 0 END) AS fer,
                SUM(CASE WHEN a.RegisterType = 'DS' THEN 1 ELSE 0 END) AS descanso,
                SUM(CASE WHEN a.RegisterType = 'LMA' THEN 1 ELSE 0 END) AS lma,
                SUM(CASE WHEN a.RegisterType = 'SUB' THEN 1 ELSE 0 END) AS sub,
                SUM(ISNULL(a.descansolab, 0)) AS hfer
            FROM PR_REGISTERHOUR a (NOLOCK)
            WHERE a.Company = @cia
              AND a.Payrolltype = @payrolltype
              AND CONVERT(VARCHAR(8), a.RegisterDate, 112) BETWEEN @inicio AND @fin
              AND (@person_all = 'Y' OR a.Person = @person)
              AND (@repunit_all = 'Y' OR a.ReplicationUnit = @repunit)
            GROUP BY a.Person
        ) RH ON RH.Person = B.Person;

        CREATE CLUSTERED INDEX IX_agg_dni ON #agg (dni);

        /* Cálculo de días trabajados (misma lógica que sp_pr_interfazplanillas_ultra) */
        UPDATE A
        SET diastrab = CASE
            WHEN CONVERT(VARCHAR(6), A.entrydate, 112) = CONVERT(VARCHAR(6), A.ceasedate, 112) THEN
                CASE
                    WHEN A.ceasedate IS NOT NULL THEN
                        DATEPART(DAY, A.ceasedate) - DATEPART(DAY, A.entrydate) + 1
                        - (ISNULL(A.lpat, 0) + ISNULL(A.lma, 0) + ISNULL(A.vacas, 0) + ISNULL(A.faltas, 0)
                           + ISNULL(A.lsg, 0) + ISNULL(A.lcg, 0) + ISNULL(A.dm, 0) + ISNULL(A.suspen, 0) + ISNULL(A.sub, 0))
                    ELSE
                        30 - (ISNULL(A.lpat, 0) + ISNULL(A.lma, 0) + ISNULL(A.vacas, 0) + ISNULL(A.faltas, 0)
                              + ISNULL(A.lsg, 0) + ISNULL(A.lcg, 0) + ISNULL(A.dm, 0) + ISNULL(A.suspen, 0) + ISNULL(A.sub, 0))
                END
            ELSE
                CASE
                    WHEN A.ceasedate IS NOT NULL THEN
                        CASE WHEN DATEPART(DAY, A.ceasedate) = 31 THEN 30 ELSE DATEPART(DAY, A.ceasedate) END
                        - (ISNULL(A.lpat, 0) + ISNULL(A.lma, 0) + ISNULL(A.vacas, 0) + ISNULL(A.faltas, 0)
                           + ISNULL(A.lsg, 0) + ISNULL(A.lcg, 0) + ISNULL(A.dm, 0) + ISNULL(A.suspen, 0) + ISNULL(A.sub, 0))
                    ELSE
                        (
                            CASE
                                WHEN A.entrydate IS NOT NULL
                                 AND CONVERT(VARCHAR(6), A.entrydate, 112) = CONVERT(VARCHAR(6), CONVERT(DATETIME, @inicio), 112)
                                THEN
                                    (
                                        CASE
                                            WHEN MONTH(A.entrydate) IN (1, 3, 5, 7, 8, 10, 12) AND DAY(A.entrydate) <> 1 THEN 31
                                            WHEN MONTH(A.entrydate) = 2 THEN 28
                                            ELSE 30
                                        END
                                    ) - DATEPART(DAY, A.entrydate) + 1
                                ELSE 30
                            END
                        )
                        - (ISNULL(A.lpat, 0) + ISNULL(A.lma, 0) + ISNULL(A.vacas, 0) + ISNULL(A.faltas, 0)
                           + ISNULL(A.lsg, 0) + ISNULL(A.lcg, 0) + ISNULL(A.dm, 0) + ISNULL(A.suspen, 0) + ISNULL(A.sub, 0))
                END
        END
        FROM #agg A;

        UPDATE #agg
        SET diastrab = diastrab - 2
        WHERE CONVERT(VARCHAR(6), entrydate, 112) = LEFT(@period, 6)
          AND CONVERT(VARCHAR(6), ceasedate, 112) <> LEFT(@period, 6)
          AND MONTH(entrydate) = 2;

        UPDATE #agg
        SET diastrab = 0
        WHERE SUBSTRING(@period, 5, 2) = '02'
          AND ISNULL(sub, 0) = 28;

        SELECT @personas = COUNT(*) FROM #agg;

        /* ---------- Conceptos (ultra) ---------- */
        DELETE EC
        FROM PR_EmployeeConcept EC
        INNER JOIN #agg A ON A.dni = EC.Person
        WHERE EC.Company = @cia
          AND EC.XLastUser = 'TAREO'
          AND EC.PRPeriodStart = @period
          AND EC.PayRollType = @payrolltype;

        IF OBJECT_ID('tempdb..#concept_map') IS NOT NULL DROP TABLE #concept_map;
        SELECT FormulaCode, Concept
        INTO #concept_map
        FROM PR_Concept (NOLOCK)
        WHERE Company = @cia
          AND FormulaCode IN (
                'DIASTRABAJADOS', 'C_HORASTRABAJADAS', 'CANT_HORAS_25', 'CANT_HORAS_35',
                'CANT_HORAS_NOC', 'DIAS_DESC_SUBSI_INAF', 'DIAS_PATERNIDAD', 'H_FERIADOS_TRAB',
                'CANT_DIAS_AUSENCIA', 'DIASUSPENSION', 'DIAS_LICENCIA_GOCE', 'DIASLICSGOCE',
                'DIAS_DESCANSO_EMPRES', 'DIAS_DESC_SUBSI_AFEC'
          );

        IF OBJECT_ID('tempdb..#concept_vals') IS NOT NULL DROP TABLE #concept_vals;
        SELECT
            A.dni AS Person,
            M.Concept,
            V.FormulaCode,
            V.ConceptValue
        INTO #concept_vals
        FROM #agg A
        CROSS APPLY (
            VALUES
                ('DIASTRABAJADOS', A.diastrab),
                ('C_HORASTRABAJADAS', A.horas),
                ('CANT_HORAS_25', A.h25),
                ('CANT_HORAS_35', A.h35),
                ('CANT_HORAS_NOC', A.hnoc),
                ('DIAS_DESC_SUBSI_INAF', A.lma),
                ('DIAS_PATERNIDAD', A.lpat),
                ('H_FERIADOS_TRAB', A.hfer),
                ('CANT_DIAS_AUSENCIA', A.faltas),
                ('DIASUSPENSION', A.suspen),
                ('DIAS_LICENCIA_GOCE', A.lcg),
                ('DIASLICSGOCE', A.lsg),
                ('DIAS_DESCANSO_EMPRES', A.dm),
                ('DIAS_DESC_SUBSI_AFEC', A.sub)
        ) V (FormulaCode, ConceptValue)
        INNER JOIN #concept_map M ON M.FormulaCode = V.FormulaCode
        WHERE V.ConceptValue > 0;

        DELETE EC
        FROM PR_EmployeeConcept EC
        INNER JOIN #concept_vals V
            ON V.Person = EC.Person
           AND V.Concept = EC.Concept
        WHERE EC.Company = @cia
          AND EC.PRPeriodStart = @period
          AND EC.PayRollType = @payrolltype;

        INSERT INTO PR_EmployeeConcept (
            Person, Company, Concept, PayRollType, PRPeriodStart, CostCenter, PRPeriodEnd,
            ConceptValue, Application, ConceptCurrency, ConceptValueLo, ConceptValueEx,
            ExchangeRate, FlagApplyFormula, FlagFrecuencyType, ReplicationUnit,
            XLastUser, XLastDate, CostCenterCode, PercentageDistribution
        )
        SELECT
            A.dni,
            @cia,
            V.Concept,
            A.payrolltype_emp,
            @period,
            A.costcenter,
            @period,
            V.ConceptValue,
            'PR',
            'LO',
            V.ConceptValue,
            0,
            3.00,
            'N',
            'T',
            'LIMA',
            'TAREO',
            @now,
            A.costcentercode,
            'D'
        FROM #concept_vals V
        INNER JOIN #agg A ON A.dni = V.Person;

        SET @conceptos = @@ROWCOUNT;

        /* ---------- Descansos médicos / PLAME (DM) ---------- */
        DELETE MR
        FROM PR_EmployeeMedicalRest MR
        INNER JOIN #agg A ON A.dni = MR.Person
        WHERE MR.Company = @cia
          AND MR.PRPeriod = @period;

        IF OBJECT_ID('tempdb..#dm_map') IS NOT NULL DROP TABLE #dm_map;
        SELECT v.RegisterType, t.MedicalRestType, t.pdt
        INTO #dm_map
        FROM (VALUES
            ('DM', '20'),
            ('F',  '07'),
            ('LCG','26'),
            ('S',  '01'),
            ('LSG','05'),
            ('LPA','28'),
            ('LMA','22'),
            ('SUB','21')
        ) v (RegisterType, pdt)
        INNER JOIN PR_MedicalRestType t (NOLOCK)
            ON t.Company = @cia AND t.pdt = v.pdt;

        IF OBJECT_ID('tempdb..#dm_base') IS NOT NULL DROP TABLE #dm_base;
        SELECT
            A.dni AS Person,
            ISNULL(MAX(MR.line), 0) AS maxline
        INTO #dm_base
        FROM #agg A
        LEFT JOIN PR_EmployeeMedicalRest MR (NOLOCK)
            ON MR.Company = @cia
           AND MR.Person = A.dni
           AND MR.PRPeriod < @period
        GROUP BY A.dni;

        INSERT INTO PR_EmployeeMedicalRest (
            Person, Company, line, MedicalRestType, DateBegin, DateEnd, Days,
            PRPeriod, PayReponsableFlag, Status, ReplicationUnit, XLastUser, XLastDate,
            CostCenter, CostCenterCode
        )
        SELECT
            S.Person,
            S.Company,
            ROW_NUMBER() OVER (PARTITION BY S.Person ORDER BY S.RegisterDate, S.MedicalRestType)
                + ISNULL(B.maxline, 0) AS line,
            S.MedicalRestType,
            S.RegisterDate,
            S.RegisterDate,
            1,
            @period,
            CASE WHEN S.pdt IN ('21', '22') THEN 'S' ELSE 'E' END,
            'P',
            'LIMA',
            'TAREO',
            @now,
            A.costcenter,
            A.costcentercode
        FROM (
            SELECT
                RH.Person,
                RH.Company,
                RH.RegisterDate,
                M.MedicalRestType,
                M.pdt
            FROM PR_REGISTERHOUR RH (NOLOCK)
            INNER JOIN #agg A0 ON A0.dni = RH.Person
            INNER JOIN #dm_map M ON M.RegisterType = RH.RegisterType
            WHERE RH.Company = @cia
              AND RH.Payrolltype = @payrolltype
              AND CONVERT(VARCHAR(8), RH.RegisterDate, 112) BETWEEN @inicio AND @fin
              AND (@repunit_all = 'Y' OR RH.ReplicationUnit = @repunit)
        ) S
        INNER JOIN #agg A ON A.dni = S.Person
        INNER JOIN #dm_base B ON B.Person = S.Person;

        SET @eventos = @@ROWCOUNT;

        COMMIT TRAN;

        SELECT
            1 AS ok,
            @personas AS personas,
            @conceptos AS conceptos,
            @eventos AS eventos,
            'Asignación de tareo procesada (conceptos + descansos médicos).' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@err, 16, 1);
    END CATCH
END
GO
