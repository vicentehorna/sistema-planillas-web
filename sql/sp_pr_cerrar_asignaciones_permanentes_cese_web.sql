/*
    Cierra asignaciones PERMANENTES (FlagFrecuencyType = 'P') de trabajadores cesados:
      - FlagFrecuencyType = 'T' (temporal)
      - PRPeriodEnd = periodo de planilla del mes de cese (CeaseDate)

    Usos:
      - Ficha trabajador (datos laborales) al inactivar individualmente.
      - Inactivación masiva de cesados (mismo rango de fechas).

    Filtros:
      @person       — si se indica, solo ese trabajador.
      @fecha_desde / @fecha_hasta — si se indican, filtra por CeaseDate (YYYY-MM-DD).

    Solo afecta trabajadores con Status = 'Y' (inactivo) y CeaseDate no nulo.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_cerrar_asignaciones_permanentes_cese_web]
    @cia          VARCHAR(10),
    @person       VARCHAR(20) = NULL,
    @fecha_desde  VARCHAR(10) = NULL,
    @fecha_hasta  VARCHAR(10) = NULL,
    @xlastuser    VARCHAR(20) = NULL,
    @emit_result  CHAR(1) = 'Y'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @cia_n VARCHAR(10) = LTRIM(RTRIM(ISNULL(@cia, '')));
    DECLARE @person_n VARCHAR(20) = NULLIF(LTRIM(RTRIM(ISNULL(@person, ''))), '');
    DECLARE @user_n VARCHAR(20) = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    DECLARE @emit CHAR(1) = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@emit_result, 'Y'))), 1));
    DECLARE @fd DATE = NULL;
    DECLARE @fh DATE = NULL;
    DECLARE @cantidad INT = 0;

    IF @emit NOT IN ('Y', 'N') SET @emit = 'Y';

    IF @cia_n = ''
    BEGIN
        RAISERROR('Debe indicar la compañía.', 16, 1);
        RETURN;
    END;

    SET @fecha_desde = LTRIM(RTRIM(ISNULL(@fecha_desde, '')));
    SET @fecha_hasta = LTRIM(RTRIM(ISNULL(@fecha_hasta, '')));

    IF @fecha_desde <> ''
    BEGIN
        IF ISDATE(@fecha_desde) = 0
        BEGIN
            RAISERROR('Indique un periodo inicio válido.', 16, 1);
            RETURN;
        END;
        SET @fd = CONVERT(DATE, @fecha_desde, 120);
    END;

    IF @fecha_hasta <> ''
    BEGIN
        IF ISDATE(@fecha_hasta) = 0
        BEGIN
            RAISERROR('Indique un periodo final válido.', 16, 1);
            RETURN;
        END;
        SET @fh = CONVERT(DATE, @fecha_hasta, 120);
    END;

    IF @fd IS NOT NULL AND @fh IS NOT NULL AND @fd > @fh
    BEGIN
        RAISERROR('El periodo inicio no puede ser mayor que el periodo final.', 16, 1);
        RETURN;
    END;

    ;WITH destino AS (
        SELECT
            ec.Person,
            ec.Company,
            ec.Concept,
            ec.PayRollType,
            ec.PRPeriodStart,
            ec.CostCenter,
            periodo_fin = ISNULL(
                per.PRPeriod,
                LEFT(CONVERT(VARCHAR(8), e.CeaseDate, 112), 6)
                + CASE
                    WHEN LEN(LTRIM(RTRIM(ec.PRPeriodStart))) >= 8
                        THEN SUBSTRING(LTRIM(RTRIM(ec.PRPeriodStart)), 7, 2)
                    ELSE '01'
                  END
            )
        FROM PR_EmployeeConcept ec (NOLOCK)
            INNER JOIN PR_Employee e (NOLOCK)
                ON e.Company = ec.Company
               AND e.Person = ec.Person
            OUTER APPLY (
                SELECT TOP 1 p.PRPeriod
                FROM PR_Period p (NOLOCK)
                WHERE p.Company = ec.Company
                  AND p.PayRollType = ec.PayRollType
                  AND LEFT(LTRIM(RTRIM(p.PRPeriod)), 6)
                      = LEFT(CONVERT(VARCHAR(8), e.CeaseDate, 112), 6)
                ORDER BY p.PRPeriod DESC
            ) per
        WHERE ec.Company = @cia_n
          AND UPPER(LTRIM(RTRIM(ISNULL(ec.FlagFrecuencyType, 'P')))) = 'P'
          AND LTRIM(RTRIM(ISNULL(e.Status, 'N'))) = 'Y'
          AND e.CeaseDate IS NOT NULL
          AND (@person_n IS NULL OR e.Person = @person_n)
          AND (@fd IS NULL OR CAST(e.CeaseDate AS DATE) >= @fd)
          AND (@fh IS NULL OR CAST(e.CeaseDate AS DATE) <= @fh)
          AND LEFT(LTRIM(RTRIM(ec.PRPeriodStart)), 6)
              <= LEFT(CONVERT(VARCHAR(8), e.CeaseDate, 112), 6)
    )
    UPDATE ec
    SET
        FlagFrecuencyType = 'T',
        PRPeriodEnd = d.periodo_fin,
        XLastDate = GETDATE(),
        XLastUser = ISNULL(@user_n, ec.XLastUser)
    FROM PR_EmployeeConcept ec
        INNER JOIN destino d
            ON d.Person = ec.Person
           AND d.Company = ec.Company
           AND d.Concept = ec.Concept
           AND d.PayRollType = ec.PayRollType
           AND d.PRPeriodStart = ec.PRPeriodStart
           AND d.CostCenter = ec.CostCenter;

    SET @cantidad = @@ROWCOUNT;

    IF @emit = 'Y'
    BEGIN
        SELECT
            @cia_n AS cia,
            @person_n AS person,
            CONVERT(VARCHAR(10), @fd, 23) AS fecha_desde,
            CONVERT(VARCHAR(10), @fh, 23) AS fecha_hasta,
            @cantidad AS cantidad;
    END
END
GO
