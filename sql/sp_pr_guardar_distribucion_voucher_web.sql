/*
    Maestro Distribución Porcentual — alta / edición de PR_DistribucionVoucher.
    ID Fila es IDENTITY (no se genera por SY_ObjectSecuence).
    tipo = 'OT' por defecto. Sin réplica a otras compañías.

    Usado por: POST /api/asientos/distribucion-porcentual/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardar_distribucion_voucher_web]
    @modo      CHAR(1),
    @company   VARCHAR(4),
    @period    VARCHAR(20),
    @fila      INT = NULL,
    @dni       VARCHAR(255),
    @nombre    VARCHAR(255),
    @codigo    VARCHAR(50),
    @valor     DECIMAL(18, 2),
    @xlastuser VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @fila_nueva INT;
    DECLARE @tipo VARCHAR(20) = 'OT';

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @dni = LTRIM(RTRIM(ISNULL(@dni, '')));
    SET @nombre = LTRIM(RTRIM(ISNULL(@nombre, '')));
    SET @codigo = LTRIM(RTRIM(ISNULL(@codigo, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    SET @valor = ROUND(ISNULL(@valor, 0), 2);

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido.', 16, 1);
        RETURN;
    END;

    IF @company = '' OR @period = ''
    BEGIN
        RAISERROR('Indique compañía y periodo.', 16, 1);
        RETURN;
    END;

    IF @dni = '' OR @nombre = '' OR @codigo = ''
    BEGIN
        RAISERROR('Indique DNI, nombres y código de unidad.', 16, 1);
        RETURN;
    END;

    IF @valor < 0.01 OR @valor > 100
    BEGIN
        RAISERROR('El valor debe estar entre 0.01 y 100 (hasta 2 decimales).', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM SY_ReplicationUnit (NOLOCK)
        WHERE LTRIM(RTRIM(ReplicationUnit)) = @codigo
    )
    BEGIN
        RAISERROR('El código de unidad no existe en SY_ReplicationUnit.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_DistribucionVoucher (NOLOCK)
        WHERE company = @company
          AND period = @period
          AND ISNULL(NULLIF(LTRIM(RTRIM(tipo)), ''), 'OT') = @tipo
          AND LTRIM(RTRIM(dni)) = @dni
          AND LTRIM(RTRIM(codigo)) = @codigo
          AND (@modo = 'I' OR Fila <> @fila)
    )
    BEGIN
        RAISERROR('Ya existe una distribución para el mismo DNI y código en el periodo.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        INSERT INTO PR_DistribucionVoucher (
            dni, nombre, codigo, valor, period, tipo, company,
            xlastuser, xlastdate
        )
        VALUES (
            @dni, @nombre, @codigo, @valor, @period, @tipo, @company,
            @xlastuser, GETDATE()
        );

        SET @fila_nueva = SCOPE_IDENTITY();

        SELECT
            @fila_nueva AS fila,
            'Distribución registrada correctamente.' AS mensaje;
        RETURN;
    END;

    IF @fila IS NULL OR NOT EXISTS (
        SELECT 1
        FROM PR_DistribucionVoucher (NOLOCK)
        WHERE Fila = @fila
          AND company = @company
          AND period = @period
    )
    BEGIN
        RAISERROR('No se encontró el registro de distribución a actualizar.', 16, 1);
        RETURN;
    END;

    UPDATE PR_DistribucionVoucher
    SET dni = @dni,
        nombre = @nombre,
        codigo = @codigo,
        valor = @valor,
        tipo = @tipo,
        xlastuser = @xlastuser,
        xlastdate = GETDATE()
    WHERE Fila = @fila
      AND company = @company
      AND period = @period;

    SELECT
        @fila AS fila,
        'Distribución actualizada correctamente.' AS mensaje;
END
GO
