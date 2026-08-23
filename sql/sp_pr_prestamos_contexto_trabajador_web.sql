/*
    Contexto para registrar un préstamo:
      RS1) Datos del trabajador (planilla, moneda, CC, TC sugerido, periodo abierto FIN_DE_MES)
      RS2) Periodos de la planilla del trabajador (PR_Period) en formato YYYY-MM-DD

    Usado por: POST /api/prestamos/contexto
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_contexto_trabajador_web]
    @company VARCHAR(4),
    @person  VARCHAR(20),
    @fecha   VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    DECLARE @fecha_dt DATETIME;
    SET @fecha = REPLACE(REPLACE(LTRIM(RTRIM(ISNULL(@fecha, ''))), '-', ''), '/', '');
    IF LEN(@fecha) >= 8 AND ISNUMERIC(LEFT(@fecha, 8)) = 1
        SET @fecha_dt = CONVERT(DATETIME, LEFT(@fecha, 8), 112);
    ELSE
        SET @fecha_dt = CONVERT(DATETIME, CONVERT(DATE, GETDATE()));

    IF @company = '' OR @person = ''
    BEGIN
        RAISERROR('Indique compañía y trabajador.', 16, 1);
        RETURN;
    END;

    DECLARE
        @payrolltype     VARCHAR(20),
        @nombre          VARCHAR(200),
        @codigo          VARCHAR(20),
        @documento       VARCHAR(20),
        @currency        VARCHAR(2),
        @costcenter      VARCHAR(20),
        @costcentercode  VARCHAR(20),
        @replicationunit VARCHAR(4),
        @exchangerate    NUMERIC(19, 4),
        @default_period  VARCHAR(10),
        @processtype_fm  VARCHAR(20);

    SELECT
        @payrolltype = LTRIM(RTRIM(e.PayRollType)),
        @codigo = LTRIM(RTRIM(e.EmployeeCode)),
        @currency = UPPER(LTRIM(RTRIM(ISNULL(NULLIF(LTRIM(RTRIM(e.SalaryCurrency)), ''), 'LO')))),
        @costcenter = LTRIM(RTRIM(e.CostCenter)),
        @costcentercode = LTRIM(RTRIM(e.Costcentername)),
        @replicationunit = LTRIM(RTRIM(e.ReplicationUnit)),
        @nombre = LTRIM(RTRIM(
            ISNULL(p.LastName1, '') + ' ' +
            ISNULL(p.LastName2, '') + ' ' +
            ISNULL(p.Name1, '') + ' ' +
            ISNULL(p.Name2, '')
        )),
        @documento = LTRIM(RTRIM(p.DocumentNumber))
    FROM PR_Employee e (NOLOCK)
    INNER JOIN SY_Person p (NOLOCK) ON p.Person = e.Person
    WHERE e.Company = @company
      AND e.Person = @person
      AND e.Status = 'N';

    IF @payrolltype IS NULL
    BEGIN
        RAISERROR('Trabajador no encontrado o inactivo.', 16, 1);
        RETURN;
    END;

    IF @currency NOT IN ('LO', 'EX') SET @currency = 'LO';

    SELECT @exchangerate = dbo.F_SY_GetExchangeRate(@fecha_dt);
    IF @exchangerate IS NULL OR @exchangerate <= 0 SET @exchangerate = 1;

    SELECT TOP 1 @processtype_fm = pt.ProcessType
    FROM PR_ProcessType pt (NOLOCK)
    WHERE pt.Company = @company
      AND (
            UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName, '')))) = 'FIN_DE_MES'
         OR UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName, '')))) = 'MENSUAL'
         OR UPPER(LTRIM(RTRIM(ISNULL(pt.ShortName, '')))) LIKE '%FIN%MES%'
      )
    ORDER BY CASE WHEN UPPER(LTRIM(RTRIM(pt.ShortName))) = 'FIN_DE_MES' THEN 0 ELSE 1 END;

    SELECT TOP 1 @default_period = LTRIM(RTRIM(pc.PRPeriod))
    FROM PR_ProcessControl pc (NOLOCK)
    WHERE pc.Company = @company
      AND pc.PayRollType = @payrolltype
      AND pc.Status IN ('A', 'G')
      AND (
            @processtype_fm IS NULL
         OR pc.ProcessType = @processtype_fm
         OR EXISTS (
                SELECT 1
                FROM PR_ProcessType pt2 (NOLOCK)
                WHERE pt2.ProcessType = pc.ProcessType
                  AND pt2.Company = pc.Company
                  AND (
                        UPPER(LTRIM(RTRIM(ISNULL(pt2.ShortName, '')))) IN ('FIN_DE_MES', 'MENSUAL')
                     OR UPPER(LTRIM(RTRIM(ISNULL(pt2.ShortName, '')))) LIKE '%FIN%MES%'
                  )
            )
      )
    ORDER BY pc.PRPeriod DESC;

    /* RS1 meta */
    SELECT
        @company AS company,
        @person AS person,
        @codigo AS codigo,
        @nombre AS nombre,
        @documento AS documento,
        @payrolltype AS payrolltype,
        @currency AS moneda,
        CASE WHEN @currency = 'LO' THEN 'Soles' ELSE 'Extranjera' END AS moneda_texto,
        @costcenter AS costcenter,
        @costcentercode AS costcentercode,
        @replicationunit AS replicationunit,
        @exchangerate AS exchangerate,
        @default_period AS periodo_default,
        CASE
            WHEN LEN(ISNULL(@default_period, '')) >= 8
            THEN SUBSTRING(@default_period, 1, 4) + '-'
               + SUBSTRING(@default_period, 5, 2) + '-'
               + SUBSTRING(@default_period, 7, 2)
            ELSE NULL
        END AS periodo_default_fmt;

    /* RS2 periodos de la planilla (para generar cuotas por PeriodOrder) */
    SELECT
        LTRIM(RTRIM(pr.PRPeriod)) AS id,
        CASE
            WHEN LEN(LTRIM(RTRIM(pr.PRPeriod))) >= 8
            THEN SUBSTRING(LTRIM(RTRIM(pr.PRPeriod)), 1, 4) + '-'
               + SUBSTRING(LTRIM(RTRIM(pr.PRPeriod)), 5, 2) + '-'
               + SUBSTRING(LTRIM(RTRIM(pr.PRPeriod)), 7, 2)
            ELSE LTRIM(RTRIM(pr.PRPeriod))
        END AS text,
        pr.PeriodOrder AS periodorder
    FROM PR_Period pr (NOLOCK)
    WHERE pr.Company = @company
      AND pr.PayRollType = @payrolltype
    ORDER BY pr.PeriodOrder DESC;
END
GO
