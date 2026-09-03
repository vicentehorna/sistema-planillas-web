/*
    Inactiva trabajadores cesados de una compañía en un rango de fechas de cese.

    PR_Employee.Status = 'Y'  (Inactivo)
    PR_Employee.Status = 'N'  (Activo)

    Filtra por Company = @cia y CeaseDate entre @fecha_desde y @fecha_hasta (inclusive).
    Solo actualiza los que aún están activos (Status = 'N').

    Usado por: POST /api/trabajadores/inactivar-cesados
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_inactivar_cesados_web]
    @cia          VARCHAR(10),
    @fecha_desde  VARCHAR(10),
    @fecha_hasta  VARCHAR(10),
    @xlastuser    VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @cia_n VARCHAR(10) = LTRIM(RTRIM(ISNULL(@cia, '')));
    DECLARE @user_n VARCHAR(20) = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    DECLARE @fd DATE = NULL;
    DECLARE @fh DATE = NULL;
    DECLARE @cantidad INT = 0;

    IF @cia_n = ''
    BEGIN
        RAISERROR('Debe indicar la compañía.', 16, 1);
        RETURN;
    END;

    SET @fecha_desde = LTRIM(RTRIM(ISNULL(@fecha_desde, '')));
    SET @fecha_hasta = LTRIM(RTRIM(ISNULL(@fecha_hasta, '')));

    IF @fecha_desde = '' OR ISDATE(@fecha_desde) = 0
    BEGIN
        RAISERROR('Indique un periodo inicio válido.', 16, 1);
        RETURN;
    END;

    IF @fecha_hasta = '' OR ISDATE(@fecha_hasta) = 0
    BEGIN
        RAISERROR('Indique un periodo final válido.', 16, 1);
        RETURN;
    END;

    SET @fd = CONVERT(DATE, @fecha_desde, 120);
    SET @fh = CONVERT(DATE, @fecha_hasta, 120);

    IF @fd > @fh
    BEGIN
        RAISERROR('El periodo inicio no puede ser mayor que el periodo final.', 16, 1);
        RETURN;
    END;

    UPDATE PR_Employee
    SET
        Status = 'Y',
        xlastdate = GETDATE(),
        xlastuser = ISNULL(@user_n, xlastuser)
    WHERE Company = @cia_n
      AND CeaseDate IS NOT NULL
      AND CAST(CeaseDate AS DATE) >= @fd
      AND CAST(CeaseDate AS DATE) <= @fh
      AND LTRIM(RTRIM(ISNULL(Status, 'N'))) = 'N';

    SET @cantidad = @@ROWCOUNT;

    /* Cerrar asignaciones permanentes de los recién inactivados en el rango */
    IF @cantidad > 0
    BEGIN
        EXEC dbo.sp_pr_cerrar_asignaciones_permanentes_cese_web
            @cia = @cia_n,
            @fecha_desde = @fecha_desde,
            @fecha_hasta = @fecha_hasta,
            @xlastuser = @user_n,
            @emit_result = 'N';
    END

    SELECT
        @cia_n AS cia,
        CONVERT(VARCHAR(10), @fd, 23) AS fecha_desde,
        CONVERT(VARCHAR(10), @fh, 23) AS fecha_hasta,
        @cantidad AS cantidad;
END
GO
