/*
    Replica la distribución OT del periodo anterior hacia @period.
    1) Copia todos los registros OT del periodo previo (misma compañía).
    2) Agrega trabajadores activos que no estaban en el periodo previo,
       con codigo = SY_Person.ReplicationUnit y valor = 100.

    Usado por: POST /api/asientos/distribucion-porcentual/replicar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_replicar_distribucion_voucher_web]
    @company   VARCHAR(4),
    @period    VARCHAR(20),
    @xlastuser VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @period_ant VARCHAR(20);
    DECLARE @tipo VARCHAR(20) = 'OT';
    DECLARE @copiados INT = 0;
    DECLARE @nuevos INT = 0;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @company = '' OR @period = ''
    BEGIN
        RAISERROR('Indique compañía y periodo.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_DistribucionVoucher (NOLOCK)
        WHERE company = @company
          AND period = @period
          AND ISNULL(NULLIF(LTRIM(RTRIM(tipo)), ''), 'OT') = @tipo
    )
    BEGIN
        RAISERROR('El periodo ya tiene distribución; no se puede replicar.', 16, 1);
        RETURN;
    END;

    SELECT @period_ant = MAX(d.period)
    FROM PR_DistribucionVoucher d (NOLOCK)
    WHERE d.company = @company
      AND d.period < @period
      AND ISNULL(NULLIF(LTRIM(RTRIM(d.tipo)), ''), 'OT') = @tipo;

    IF @period_ant IS NULL
    BEGIN
        RAISERROR('No existe un periodo anterior con distribución para replicar.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO PR_DistribucionVoucher (
            dni, nombre, codigo, valor, period, tipo, company,
            xlastuser, xlastdate
        )
        SELECT
            LTRIM(RTRIM(d.dni)),
            LTRIM(RTRIM(ISNULL(d.nombre, ''))),
            LTRIM(RTRIM(ISNULL(d.codigo, ''))),
            d.valor,
            @period,
            @tipo,
            @company,
            @xlastuser,
            GETDATE()
        FROM PR_DistribucionVoucher d (NOLOCK)
        WHERE d.company = @company
          AND d.period = @period_ant
          AND ISNULL(NULLIF(LTRIM(RTRIM(d.tipo)), ''), 'OT') = @tipo;

        SET @copiados = @@ROWCOUNT;

        INSERT INTO PR_DistribucionVoucher (
            dni, nombre, codigo, valor, period, tipo, company,
            xlastuser, xlastdate
        )
        SELECT
            LTRIM(RTRIM(p.Person)),
            LTRIM(RTRIM(ISNULL(p.Name, ''))),
            LTRIM(RTRIM(p.ReplicationUnit)),
            100,
            @period,
            @tipo,
            @company,
            @xlastuser,
            GETDATE()
        FROM PR_Employee e (NOLOCK)
        INNER JOIN SY_Person p (NOLOCK)
            ON p.Person = e.Person
        WHERE e.Company = @company
          AND UPPER(LTRIM(RTRIM(ISNULL(e.Status, 'Y')))) IN ('Y', 'A', '1')
          AND (e.CeaseDate IS NULL OR e.CeaseDate >= CAST(GETDATE() AS DATE))
          AND NULLIF(LTRIM(RTRIM(ISNULL(p.ReplicationUnit, ''))), '') IS NOT NULL
          AND NOT EXISTS (
                SELECT 1
                FROM PR_DistribucionVoucher d (NOLOCK)
                WHERE d.company = @company
                  AND d.period = @period_ant
                  AND ISNULL(NULLIF(LTRIM(RTRIM(d.tipo)), ''), 'OT') = @tipo
                  AND LTRIM(RTRIM(d.dni)) = LTRIM(RTRIM(p.Person))
          )
          AND NOT EXISTS (
                SELECT 1
                FROM PR_DistribucionVoucher d2 (NOLOCK)
                WHERE d2.company = @company
                  AND d2.period = @period
                  AND ISNULL(NULLIF(LTRIM(RTRIM(d2.tipo)), ''), 'OT') = @tipo
                  AND LTRIM(RTRIM(d2.dni)) = LTRIM(RTRIM(p.Person))
                  AND LTRIM(RTRIM(d2.codigo)) = LTRIM(RTRIM(p.ReplicationUnit))
          );

        SET @nuevos = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT
            @period_ant AS period_origen,
            @period AS period_destino,
            @copiados AS copiados,
            @nuevos AS nuevos,
            'Distribución replicada desde el periodo '
                + CASE
                    WHEN LEN(@period_ant) = 8 THEN
                        LEFT(@period_ant, 4) + '-' + SUBSTRING(@period_ant, 5, 2) + '-' + RIGHT(@period_ant, 2)
                    ELSE @period_ant
                  END
                + '. Copiados: ' + CAST(@copiados AS VARCHAR(10))
                + '. Nuevos: ' + CAST(@nuevos AS VARCHAR(10)) + '.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
