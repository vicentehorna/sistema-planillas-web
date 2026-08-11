/*
    hm_divisa — alta/edición Distribución Porcentual tipo CC (centro de costo).
    Valida codigo contra AC_CostCenter.Abbrev. No altera el SP OT de otras BD.
    Usado por: POST /api/asientos/distribucion-porcentual/guardar (solo hm_divisa)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardar_distribucion_voucher_cc_web]
    @modo      CHAR(1),
    @company   VARCHAR(4),
    @period    VARCHAR(20),
    @fila      INT = NULL,
    @dni       VARCHAR(255),
    @nombre    VARCHAR(255),
    @codigo    VARCHAR(50),
    @valor     INT,
    @xlastuser VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @fila_nueva INT;
    DECLARE @tipo VARCHAR(20) = 'CC';

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @dni = LTRIM(RTRIM(ISNULL(@dni, '')));
    SET @nombre = LTRIM(RTRIM(ISNULL(@nombre, '')));
    SET @codigo = LTRIM(RTRIM(ISNULL(@codigo, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    SET @valor = ISNULL(@valor, 0);

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
        RAISERROR('Indique DNI, nombres y código de centro de costo.', 16, 1);
        RETURN;
    END;

    IF @valor < 1 OR @valor > 100
    BEGIN
        RAISERROR('El valor debe ser un entero entre 1 y 100.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM AC_CostCenter (NOLOCK)
        WHERE Company = @company
          AND LTRIM(RTRIM(Abbrev)) = @codigo
    )
    BEGIN
        RAISERROR('El código no existe en AC_CostCenter (Abbrev).', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_DistribucionVoucher (NOLOCK)
        WHERE company = @company
          AND period = @period
          AND LTRIM(RTRIM(ISNULL(tipo, ''))) = @tipo
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
            dni, nombre, codigo, valor, period, tipo, company
        )
        VALUES (
            @dni, @nombre, @codigo, @valor, @period, @tipo, @company
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
          AND LTRIM(RTRIM(ISNULL(tipo, ''))) = @tipo
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
        tipo = @tipo
    WHERE Fila = @fila
      AND company = @company
      AND period = @period;

    SELECT
        @fila AS fila,
        'Distribución actualizada correctamente.' AS mensaje;
END
GO
