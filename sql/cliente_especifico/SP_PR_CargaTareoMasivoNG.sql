/*
    SP_PR_CargaTareoMasivoNG — carga set-based a PR_REGISTERHOUR (hm_ngservicios).
    Reemplaza cursores anidados + EXEC dinámico + SP_SY_ObjectSecuence_Edit por día
    (antes ~150s / HTTP 524 Cloudflare) por un INSERT masivo con reserva de correlativos.

    Usado por: POST /api/tareo-ng/importar/procesar
*/
CREATE OR ALTER PROCEDURE [dbo].[SP_PR_CargaTareoMasivoNG]
    @period VARCHAR(6),
    @cia    CHAR(4)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @fechainicio DATETIME,
        @fechafin DATETIME,
        @ini INT = 1,
        @n INT = 0,
        @seq_start INT,
        @seq_end INT,
        @now DATETIME = GETDATE(),
        @rep_seq VARCHAR(4) = 'LIMA',
        @cia_trim VARCHAR(4);

    SET @cia = LEFT(LTRIM(RTRIM(ISNULL(@cia,''))) + SPACE(3), 4);
    SET @cia_trim = LTRIM(RTRIM(@cia));
    SET @period = LTRIM(RTRIM(ISNULL(@period,'')));

    IF @period = '' OR @cia_trim = ''
    BEGIN
        RAISERROR('Indique periodo y compañía.', 16, 1);
        RETURN;
    END;

    SELECT TOP 1 @fechainicio = CADateBegin, @fechafin = CADateEnd
    FROM PR_Period WITH (NOLOCK)
    WHERE Company = @cia_trim AND GLPeriod = @period AND PayRollType = 'BGT 000000000001'
    ORDER BY PeriodOrder;

    IF @fechainicio IS NULL
        SELECT TOP 1 @fechainicio = CADateBegin, @fechafin = CADateEnd
        FROM PR_Period WITH (NOLOCK)
        WHERE Company = @cia_trim AND GLPeriod = @period
        ORDER BY PeriodOrder;

    IF @fechainicio IS NULL
    BEGIN
        RAISERROR('No se encontró periodo contable %s para la compañía.', 16, 1, @period);
        RETURN;
    END;

    IF OBJECT_ID('tempdb..#fechas') IS NOT NULL DROP TABLE #fechas;
    CREATE TABLE #fechas (dia CHAR(2) NOT NULL PRIMARY KEY, fecha DATETIME NOT NULL);
    WHILE @ini <= 31
    BEGIN
        INSERT INTO #fechas VALUES (RIGHT('0'+CONVERT(VARCHAR(2),@ini),2), DATEADD(DAY,@ini-1,@fechainicio));
        SET @ini += 1;
    END;

    UPDATE PR_TAREONG SET
        company = @cia,
        Result = 'OK',
        Message = '',
        hour01 = ISNULL(hour01,''),
        hour02 = ISNULL(hour02,''),
        hour03 = ISNULL(hour03,''),
        hour04 = ISNULL(hour04,''),
        hour05 = ISNULL(hour05,''),
        hour06 = ISNULL(hour06,''),
        hour07 = ISNULL(hour07,''),
        hour08 = ISNULL(hour08,''),
        hour09 = ISNULL(hour09,''),
        hour10 = ISNULL(hour10,''),
        hour11 = ISNULL(hour11,''),
        hour12 = ISNULL(hour12,''),
        hour13 = ISNULL(hour13,''),
        hour14 = ISNULL(hour14,''),
        hour15 = ISNULL(hour15,''),
        hour16 = ISNULL(hour16,''),
        hour17 = ISNULL(hour17,''),
        hour18 = ISNULL(hour18,''),
        hour19 = ISNULL(hour19,''),
        hour20 = ISNULL(hour20,''),
        hour21 = ISNULL(hour21,''),
        hour22 = ISNULL(hour22,''),
        hour23 = ISNULL(hour23,''),
        hour24 = ISNULL(hour24,''),
        hour25 = ISNULL(hour25,''),
        hour26 = ISNULL(hour26,''),
        hour27 = ISNULL(hour27,''),
        hour28 = ISNULL(hour28,''),
        hour29 = ISNULL(hour29,''),
        hour30 = ISNULL(hour30,''),
        hour31 = ISNULL(hour31,''),
        extras = 0, faltas = 0, vacaciones = 0, descmedico = 0, suspension = 0,
        LCG = 0, LSG = 0, LPP = 0, Feriado = 0, descansos = 0, adicionales = 0,
        observaciones = '';

    IF OBJECT_ID('tempdb..#Temporal') IS NOT NULL DROP TABLE #Temporal;
    SELECT
        Fila,
        name,
        CASE WHEN EXISTS(SELECT 1 FROM SY_Person WITH (NOLOCK) WHERE DocumentNumber = x.person)
             THEN x.person ELSE 'XX' END AS person,
        CASE WHEN EXISTS(
                SELECT 1 FROM AC_CostCenter WITH (NOLOCK)
                WHERE CCLevel = 1
                  AND RTRIM(Name) = RTRIM(LTRIM(RTRIM(x.destacamento)))
                  AND Company = @cia_trim)
             THEN x.destacamento ELSE 'XX' END AS destacamento,
        CASE WHEN hour01 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour01)=1 THEN hour01 ELSE 'XX' END AS hour01,
        CASE WHEN hour02 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour02)=1 THEN hour02 ELSE 'XX' END AS hour02,
        CASE WHEN hour03 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour03)=1 THEN hour03 ELSE 'XX' END AS hour03,
        CASE WHEN hour04 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour04)=1 THEN hour04 ELSE 'XX' END AS hour04,
        CASE WHEN hour05 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour05)=1 THEN hour05 ELSE 'XX' END AS hour05,
        CASE WHEN hour06 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour06)=1 THEN hour06 ELSE 'XX' END AS hour06,
        CASE WHEN hour07 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour07)=1 THEN hour07 ELSE 'XX' END AS hour07,
        CASE WHEN hour08 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour08)=1 THEN hour08 ELSE 'XX' END AS hour08,
        CASE WHEN hour09 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour09)=1 THEN hour09 ELSE 'XX' END AS hour09,
        CASE WHEN hour10 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour10)=1 THEN hour10 ELSE 'XX' END AS hour10,
        CASE WHEN hour11 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour11)=1 THEN hour11 ELSE 'XX' END AS hour11,
        CASE WHEN hour12 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour12)=1 THEN hour12 ELSE 'XX' END AS hour12,
        CASE WHEN hour13 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour13)=1 THEN hour13 ELSE 'XX' END AS hour13,
        CASE WHEN hour14 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour14)=1 THEN hour14 ELSE 'XX' END AS hour14,
        CASE WHEN hour15 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour15)=1 THEN hour15 ELSE 'XX' END AS hour15,
        CASE WHEN hour16 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour16)=1 THEN hour16 ELSE 'XX' END AS hour16,
        CASE WHEN hour17 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour17)=1 THEN hour17 ELSE 'XX' END AS hour17,
        CASE WHEN hour18 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour18)=1 THEN hour18 ELSE 'XX' END AS hour18,
        CASE WHEN hour19 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour19)=1 THEN hour19 ELSE 'XX' END AS hour19,
        CASE WHEN hour20 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour20)=1 THEN hour20 ELSE 'XX' END AS hour20,
        CASE WHEN hour21 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour21)=1 THEN hour21 ELSE 'XX' END AS hour21,
        CASE WHEN hour22 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour22)=1 THEN hour22 ELSE 'XX' END AS hour22,
        CASE WHEN hour23 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour23)=1 THEN hour23 ELSE 'XX' END AS hour23,
        CASE WHEN hour24 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour24)=1 THEN hour24 ELSE 'XX' END AS hour24,
        CASE WHEN hour25 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour25)=1 THEN hour25 ELSE 'XX' END AS hour25,
        CASE WHEN hour26 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour26)=1 THEN hour26 ELSE 'XX' END AS hour26,
        CASE WHEN hour27 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour27)=1 THEN hour27 ELSE 'XX' END AS hour27,
        CASE WHEN hour28 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour28)=1 THEN hour28 ELSE 'XX' END AS hour28,
        CASE WHEN hour29 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour29)=1 THEN hour29 ELSE 'XX' END AS hour29,
        CASE WHEN hour30 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour30)=1 THEN hour30 ELSE 'XX' END AS hour30,
        CASE WHEN hour31 IN ('D','FL','LCG','LSG','V','DM','F','S','LP','') OR ISNUMERIC(hour31)=1 THEN hour31 ELSE 'XX' END AS hour31,
        CAST(NULL AS VARCHAR(2)) AS Result,
        CAST(NULL AS VARCHAR(255)) AS Message
    INTO #Temporal
    FROM PR_TAREONG x WITH (NOLOCK);

    UPDATE #Temporal SET
        Result = CASE
            WHEN person = 'XX' OR destacamento = 'XX' THEN 'KO'
            WHEN 'XX' IN (hour01,hour02,hour03,hour04,hour05,hour06,hour07,hour08,hour09,hour10,hour11,hour12,hour13,hour14,hour15,hour16,hour17,hour18,hour19,hour20,hour21,hour22,hour23,hour24,hour25,hour26,hour27,hour28,hour29,hour30,hour31) THEN 'KO'
            ELSE 'OK' END,
        Message = CASE
            WHEN person = 'XX' THEN 'Código de trabajador no registrado'
            WHEN destacamento = 'XX' THEN 'Código de Establecimiento no registrado'
            WHEN 'XX' IN (hour01,hour02,hour03,hour04,hour05,hour06,hour07,hour08,hour09,hour10,hour11,hour12,hour13,hour14,hour15,hour16,hour17,hour18,hour19,hour20,hour21,hour22,hour23,hour24,hour25,hour26,hour27,hour28,hour29,hour30,hour31) THEN 'Registro Errado'
            ELSE '' END;

    UPDATE t SET Result = tmp.Result, Message = tmp.Message
    FROM PR_TAREONG t
    INNER JOIN #Temporal tmp ON tmp.Fila = t.Fila;

    /* Días del periodo a limpiar (incluye celdas vacías, como el SP antiguo).
       Borra por persona+fecha sin filtrar CC: evita residuos si antes hubo match ambiguo. */
    IF OBJECT_ID('tempdb..#clear') IS NOT NULL DROP TABLE #clear;
    SELECT DISTINCT
        p.Person AS personid,
        @cia_trim AS company,
        CONVERT(VARCHAR(8), f.fecha, 112) AS fecha8
    INTO #clear
    FROM PR_TAREONG o WITH (NOLOCK)
    INNER JOIN SY_Person p WITH (NOLOCK) ON p.DocumentNumber = LTRIM(RTRIM(o.person))
    CROSS JOIN #fechas f
    WHERE o.Result = 'OK'
      AND (@fechafin IS NULL OR f.fecha <= @fechafin);

    IF OBJECT_ID('tempdb..#raw') IS NOT NULL DROP TABLE #raw;
    SELECT
        o.Fila,
        LTRIM(RTRIM(o.person)) AS dni,
        LTRIM(RTRIM(o.destacamento)) AS destacamento,
        @cia_trim AS company,
        f.fecha,
        CONVERT(VARCHAR(8), f.fecha, 112) AS fecha8,
        LTRIM(RTRIM(v.hourval)) AS hourval,
        dbo.F_GetTipoDia(LTRIM(RTRIM(v.hourval))) AS tipodia,
        CASE WHEN ISNUMERIC(LTRIM(RTRIM(v.hourval))) = 1
             THEN CONVERT(NUMERIC(19,4), LTRIM(RTRIM(v.hourval))) ELSE 0 END AS numval
    INTO #raw
    FROM PR_TAREONG o WITH (NOLOCK)
    CROSS APPLY (VALUES ('01', o.hour01),('02', o.hour02),('03', o.hour03),('04', o.hour04),('05', o.hour05),('06', o.hour06),('07', o.hour07),('08', o.hour08),('09', o.hour09),('10', o.hour10),('11', o.hour11),('12', o.hour12),('13', o.hour13),('14', o.hour14),('15', o.hour15),('16', o.hour16),('17', o.hour17),('18', o.hour18),('19', o.hour19),('20', o.hour20),('21', o.hour21),('22', o.hour22),('23', o.hour23),('24', o.hour24),('25', o.hour25),('26', o.hour26),('27', o.hour27),('28', o.hour28),('29', o.hour29),('30', o.hour30),('31', o.hour31)) v(dia, hourval)
    INNER JOIN #fechas f ON f.dia = v.dia
    WHERE o.Result = 'OK'
      AND LTRIM(RTRIM(ISNULL(v.hourval,''))) <> ''
      AND (@fechafin IS NULL OR f.fecha <= @fechafin);

    IF OBJECT_ID('tempdb..#ready') IS NOT NULL DROP TABLE #ready;
    SELECT
        r.*,
        p.Person AS personid,
        ISNULL(NULLIF(LTRIM(RTRIM(p.Name)), ''), r.dni) AS personname,
        e.PayRollType,
        cc.CostCenter,
        cc.repunit,
        cc.cccode,
        CASE WHEN noct.Person IS NOT NULL THEN 1 ELSE 0 END AS flag_nocturno,
        CONVERT(NUMERIC(19,4), ISNULL(horas.ConceptValue, 0)) AS flag_horas_val,
        CASE WHEN he.Person IS NOT NULL THEN 1 ELSE 0 END AS flag_he_mitad
    INTO #ready
    FROM #raw r
    INNER JOIN SY_Person p WITH (NOLOCK) ON p.DocumentNumber = r.dni
    LEFT JOIN PR_Employee e WITH (NOLOCK) ON e.Person = p.Person AND e.Company = r.company
    /* Un solo CC por destacamento: evita triplicar si hay varios AC_CostCenter con el mismo RTRIM(Name). */
    OUTER APPLY (
        SELECT TOP 1
            cc0.CostCenter,
            cc0.ReplicationUnit AS repunit,
            cc0.Abbrev AS cccode
        FROM AC_CostCenter cc0 WITH (NOLOCK)
        WHERE cc0.CCLevel = 1
          AND RTRIM(cc0.Name) = RTRIM(r.destacamento)
          AND cc0.Company = r.company
        ORDER BY
            CASE WHEN e.CostCenter IS NOT NULL AND cc0.CostCenter = e.CostCenter THEN 0 ELSE 1 END,
            cc0.CostCenter
    ) cc
    OUTER APPLY (
        SELECT TOP 1 ec.Person
        FROM PR_EmployeeConcept ec WITH (NOLOCK)
        INNER JOIN PR_Concept c WITH (NOLOCK) ON c.Concept = ec.Concept AND c.Company = ec.Company
        WHERE ec.Person = p.Person AND ec.Company = r.company AND c.FormulaCode = 'FLAG_NOCTURNO'
          AND (
                (ec.FlagFrecuencyType = 'P' AND ec.PRPeriodStart <= @period)
             OR (ec.FlagFrecuencyType = 'T' AND @period BETWEEN ec.PRPeriodStart AND ec.PRPeriodEnd)
          )
    ) noct
    OUTER APPLY (
        SELECT TOP 1 ec.ConceptValue
        FROM PR_EmployeeConcept ec WITH (NOLOCK)
        INNER JOIN PR_Concept c WITH (NOLOCK) ON c.Concept = ec.Concept AND c.Company = ec.Company
        WHERE ec.Person = p.Person AND ec.Company = r.company AND c.FormulaCode = 'FLAG_HORAS'
    ) horas
    OUTER APPLY (
        SELECT TOP 1 ec.Person
        FROM PR_EmployeeConcept ec WITH (NOLOCK)
        INNER JOIN PR_Concept c WITH (NOLOCK) ON c.Concept = ec.Concept AND c.Company = ec.Company
        WHERE ec.Person = p.Person AND ec.Company = r.company AND c.FormulaCode = 'FLAG_HE_MITAD'
    ) he
    WHERE cc.CostCenter IS NOT NULL;

    IF OBJECT_ID('tempdb..#ins') IS NOT NULL DROP TABLE #ins;
    SELECT
        ROW_NUMBER() OVER (ORDER BY r.personid, r.fecha8, r.Fila) AS rn,
        r.personid, r.personname, r.fecha, r.fecha8, r.tipodia,
        r.CostCenter, r.PayRollType, r.repunit, r.cccode, r.company,
        CONVERT(NUMERIC(19,4), CASE
            WHEN r.tipodia IN ('V','M','D','L','N','F','P','S','X') THEN 0
            WHEN r.tipodia = 'A' AND r.flag_nocturno = 1 AND r.numval < 3 THEN r.numval
            WHEN r.tipodia = 'A' AND r.flag_nocturno = 1 THEN 2
            WHEN r.tipodia = 'A' AND r.numval < 9 AND r.flag_horas_val > 0 THEN r.flag_horas_val
            WHEN r.tipodia = 'A' AND r.numval < 9 THEN r.numval
            WHEN r.tipodia = 'A' THEN 8 ELSE 0 END) AS hourday,
        CONVERT(NUMERIC(19,4), CASE
            WHEN r.tipodia <> 'A' OR r.flag_nocturno = 1 THEN 0
            WHEN r.numval < 9 AND r.flag_horas_val > 0 THEN
                CASE WHEN (r.numval - r.flag_horas_val) > 2 THEN 2 ELSE (r.numval - r.flag_horas_val) END
            WHEN r.numval < 9 THEN 0
            WHEN r.flag_he_mitad = 1 THEN (r.numval - 8) / 2.00
            ELSE CASE WHEN (r.numval - 8) > 2 THEN 2 ELSE (r.numval - 8) END END) AS h25,
        CONVERT(NUMERIC(19,4), CASE
            WHEN r.tipodia <> 'A' OR r.flag_nocturno = 1 THEN 0
            WHEN r.numval < 9 AND r.flag_horas_val > 0 THEN
                CASE WHEN (r.numval - r.flag_horas_val) > 2 THEN (r.numval - r.flag_horas_val) - 2 ELSE 0 END
            WHEN r.numval < 9 THEN 0
            WHEN r.flag_he_mitad = 1 THEN (r.numval - 8) / 2.00
            ELSE CASE WHEN (r.numval - 8) > 2 THEN (r.numval - 8) - 2 ELSE 0 END END) AS h35,
        CONVERT(NUMERIC(19,4), CASE
            WHEN r.tipodia = 'A' AND r.flag_nocturno = 1 AND r.numval >= 3 THEN r.numval - 2 ELSE 0 END) AS h100
    INTO #ins
    FROM #ready r;

    SELECT @n = COUNT(*) FROM #ins;

    BEGIN TRY
        BEGIN TRAN;
        IF EXISTS (SELECT 1 FROM #clear)
        BEGIN
            DELETE RH
            FROM PR_REGISTERHOUR RH
            INNER JOIN #clear c
                ON LTRIM(RTRIM(RH.Company)) = c.company
               AND RH.Person = c.personid
               AND CONVERT(VARCHAR(8), RH.RegisterDate, 112) = c.fecha8;
        END;

        IF @n > 0
        BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM SY_ObjectSecuence WITH (UPDLOCK, HOLDLOCK)
                WHERE Company = @cia_trim AND Object = 'PR_REGHOUR' AND ReplicationUnit = @rep_seq
            )
                RAISERROR('No existe correlativo PR_REGHOUR / LIMA para la compañía.', 16, 1);

            UPDATE SY_ObjectSecuence WITH (UPDLOCK, HOLDLOCK)
            SET @seq_start = Secuence + 1,
                @seq_end = Secuence + @n,
                Secuence = Secuence + @n,
                XLastUser = 'MASIVO',
                XLastDate = @now
            WHERE Company = @cia_trim AND Object = 'PR_REGHOUR' AND ReplicationUnit = @rep_seq;

            IF @seq_start IS NULL OR @seq_end IS NULL
                RAISERROR('No se pudo reservar correlativos PR_REGHOUR.', 16, 1);

            INSERT INTO PR_REGISTERHOUR (
                Registerhour, Person, RegisterDate, RegisterType,
                CostCenter, Payrolltype, ReplicationUnit,
                hourday, extrahour25, extrahour35, extrahour100,
                Company, XLastuser, XLastDate, code, personname
            )
            SELECT
                LEFT(@rep_seq + SPACE(3), 4)
                    + LEFT(i.company + SPACE(3), 4)
                    + RIGHT(REPLICATE('0', 11) + CONVERT(VARCHAR(20), @seq_start + i.rn - 1), 12),
                i.personid, i.fecha, i.tipodia,
                i.CostCenter, i.PayRollType, i.repunit,
                i.hourday, i.h25, i.h35, i.h100,
                i.company, 'MASIVO', @now, i.cccode, i.personname
            FROM #ins i
            ORDER BY i.rn;
        END;
        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @errmsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@errmsg, 16, 1);
        RETURN;
    END CATCH

    SELECT @n AS filas_dia,
           (SELECT COUNT(*) FROM PR_TAREONG WITH (NOLOCK) WHERE Result='OK') AS personas_ok,
           (SELECT COUNT(*) FROM PR_TAREONG WITH (NOLOCK) WHERE Result='KO') AS personas_ko;
END
GO
