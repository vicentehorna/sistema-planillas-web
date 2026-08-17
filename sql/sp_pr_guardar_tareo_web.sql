/*
    Alta / edición de cabecera de tareo. En edición borra el detalle
    (el API reinserta el detalle completo).
    ID nuevo: sp_pr_genera_correlativo_web objeto TAREOGEN.
    Usado por: POST /api/tareo/registro/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardar_tareo_web]
    @modo         CHAR(1),
    @tareoheader  VARCHAR(20) = NULL,
    @company      VARCHAR(4),
    @payrolltype  VARCHAR(20),
    @prperiod     VARCHAR(20),
    @costcenter   VARCHAR(20),
    @registerdate DATETIME = NULL,
    @xlastuser    VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @id VARCHAR(20);
    DECLARE @tabla_id TABLE (id_generado VARCHAR(20));
    DECLARE @now DATETIME = GETDATE();

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @tareoheader = NULLIF(LTRIM(RTRIM(ISNULL(@tareoheader, ''))), '');
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @prperiod = LTRIM(RTRIM(ISNULL(@prperiod, '')));
    SET @costcenter = LTRIM(RTRIM(ISNULL(@costcenter, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido.', 16, 1);
        RETURN;
    END;

    IF @company = '' OR @payrolltype = '' OR @prperiod = '' OR @costcenter = ''
    BEGIN
        RAISERROR('Indique compañía, tipo de planilla, periodo y unidad.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM PR_PayRollType (NOLOCK)
        WHERE Company = @company AND PayRollType = @payrolltype
    )
    BEGIN
        RAISERROR('El tipo de planilla no existe.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM PR_Period (NOLOCK)
        WHERE Company = @company AND PayRollType = @payrolltype AND PRPeriod = @prperiod
    )
    BEGIN
        RAISERROR('El periodo no existe para el tipo de planilla.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM AC_CostCenter (NOLOCK)
        WHERE Company = @company
          AND CostCenter = @costcenter
          AND ISNULL(CCLevel, 0) = 1
    )
    BEGIN
        RAISERROR('La unidad (centro de costo nivel 1) no existe.', 16, 1);
        RETURN;
    END;

    IF @modo = 'U'
    BEGIN
        IF @tareoheader IS NULL
        BEGIN
            RAISERROR('Indique el tareo a modificar.', 16, 1);
            RETURN;
        END;
        IF NOT EXISTS (SELECT 1 FROM PR_TareoHeader (NOLOCK) WHERE TareoHeader = @tareoheader)
        BEGIN
            RAISERROR('El tareo no existe.', 16, 1);
            RETURN;
        END;
        SET @id = @tareoheader;
    END
    ELSE
    BEGIN
        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'TAREOGEN',
            @xlastuser = @xlastuser;

        SELECT @id = id_generado FROM @tabla_id;
        IF NULLIF(LTRIM(RTRIM(ISNULL(@id, ''))), '') IS NULL
        BEGIN
            RAISERROR('No se pudo generar el correlativo TAREOGEN.', 16, 1);
            RETURN;
        END;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @modo = 'I'
        BEGIN
            INSERT INTO PR_TareoHeader (
                TareoHeader, company, payrolltype, prperiod,
                registerdate, xlastuser, xlastdate, costcenter
            )
            VALUES (
                @id, @company, @payrolltype, @prperiod,
                ISNULL(@registerdate, @now), @xlastuser, @now, @costcenter
            );
        END
        ELSE
        BEGIN
            UPDATE PR_TareoHeader
            SET company = @company,
                payrolltype = @payrolltype,
                prperiod = @prperiod,
                registerdate = ISNULL(@registerdate, registerdate),
                xlastuser = @xlastuser,
                xlastdate = @now,
                costcenter = @costcenter
            WHERE TareoHeader = @id;
            /* El detalle se reemplaza en la API (delete+insert+traslado en una sola tx). */
        END;

        COMMIT TRANSACTION;

        SELECT
            @id AS tareoheader,
            CASE WHEN @modo = 'I' THEN 'Tareo registrado.' ELSE 'Tareo actualizado.' END AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
