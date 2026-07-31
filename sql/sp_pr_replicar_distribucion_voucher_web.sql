/*
    Asegura la distribución OT del periodo:
    1) Si el periodo está vacío: copia todos los registros OT del periodo previo
       (misma compañía).
    2) Siempre: agrega trabajadores activos de la compañía que aún no estén
       en el periodo, con codigo = SY_Person.ReplicationUnit y valor = 100.

    Activo en este sistema: PR_Employee.Status = 'N' y sin cese vigente
    (CeaseDate IS NULL o CeaseDate >= hoy).

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
    DECLARE @tiene_periodo BIT = 0;

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
        SET @tiene_periodo = 1;

    IF @tiene_periodo = 0
    BEGIN
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
    END
    ELSE
    BEGIN
        SELECT @period_ant = MAX(d.period)
        FROM PR_DistribucionVoucher d (NOLOCK)
        WHERE d.company = @company
          AND d.period < @period
          AND ISNULL(NULLIF(LTRIM(RTRIM(d.tipo)), ''), 'OT') = @tipo;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @tiene_periodo = 0
        BEGIN
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
        END;

        /* Trabajadores activos sin distribución en el periodo actual */
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
          AND LTRIM(RTRIM(ISNULL(e.Status, ''))) = 'N'
          AND (e.CeaseDate IS NULL OR e.CeaseDate >= CAST(GETDATE() AS DATE))
          AND NULLIF(LTRIM(RTRIM(ISNULL(p.ReplicationUnit, ''))), '') IS NOT NULL
          AND NOT EXISTS (
                SELECT 1
                FROM PR_DistribucionVoucher d (NOLOCK)
                WHERE d.company = @company
                  AND d.period = @period
                  AND ISNULL(NULLIF(LTRIM(RTRIM(d.tipo)), ''), 'OT') = @tipo
                  AND LTRIM(RTRIM(d.dni)) = LTRIM(RTRIM(p.Person))
          );

        SET @nuevos = @@ROWCOUNT;

        COMMIT TRANSACTION;

        SELECT
            @period_ant AS period_origen,
            @period AS period_destino,
            @copiados AS copiados,
            @nuevos AS nuevos,
            CASE
                WHEN @copiados > 0 AND @nuevos > 0 THEN
                    'Distribución replicada desde el periodo anterior. Copiados: '
                    + CAST(@copiados AS VARCHAR(10))
                    + '. Nuevos activos: ' + CAST(@nuevos AS VARCHAR(10)) + '.'
                WHEN @copiados > 0 THEN
                    'Distribución replicada desde el periodo anterior. Copiados: '
                    + CAST(@copiados AS VARCHAR(10)) + '.'
                WHEN @nuevos > 0 THEN
                    'Se agregaron ' + CAST(@nuevos AS VARCHAR(10))
                    + ' trabajador(es) activo(s) sin distribución (unidad de ficha, 100%).'
                ELSE
                    'Sin cambios. La distribución del periodo ya está actualizada.'
            END AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
