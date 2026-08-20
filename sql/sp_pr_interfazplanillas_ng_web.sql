/*
    Wrapper web para Asignación de Tareo NG.
    - Valida parámetros de entrada (incluye Unidad / SY_ReplicationUnit).
    - Ejecuta sp_pr_interfazplanillas legacy.
    - Retorna payload estándar para UI web.

    @repunit_all = 'Y' → todas las unidades
    @repunit_all = 'N' → filtra por @repunit (ReplicationUnit)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_interfazplanillas_ng_web]
    @cia         VARCHAR(4),
    @period      VARCHAR(8),
    @payrolltype VARCHAR(20),
    @person_all  CHAR(1) = 'Y',
    @person      VARCHAR(20) = NULL,
    @repunit_all CHAR(1) = 'Y',
    @repunit     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @person_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@person_all, 'Y'))), 1));
    SET @repunit_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@repunit_all, 'Y'))), 1));
    SET @person = NULLIF(LTRIM(RTRIM(ISNULL(@person, ''))), '');
    SET @repunit = NULLIF(LTRIM(RTRIM(ISNULL(@repunit, ''))), '');
    IF @repunit IN ('0', '*') SET @repunit = NULL;

    IF @cia = '' OR @period = '' OR @payrolltype = ''
    BEGIN
        RAISERROR('Indique compañía, periodo y tipo de planilla.', 16, 1);
        RETURN;
    END;

    IF @person_all NOT IN ('Y', 'N') SET @person_all = 'Y';
    IF @repunit_all NOT IN ('Y', 'N') SET @repunit_all = 'Y';

    IF @person_all = 'N' AND @person IS NULL
    BEGIN
        RAISERROR('Indique la persona a procesar.', 16, 1);
        RETURN;
    END;

    IF @repunit_all = 'N' AND @repunit IS NULL
    BEGIN
        RAISERROR('Indique la unidad a procesar.', 16, 1);
        RETURN;
    END;

    IF @repunit_all = 'N' AND @repunit IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
            FROM SY_ReplicationUnit ru (NOLOCK)
            WHERE LTRIM(RTRIM(ru.ReplicationUnit)) = LTRIM(RTRIM(@repunit))
       )
    BEGIN
        RAISERROR('La unidad indicada no existe en SY_ReplicationUnit.', 16, 1);
        RETURN;
    END;

    IF @repunit IS NULL
        SET @repunit_all = 'Y';

    BEGIN TRY
        EXEC dbo.sp_pr_interfazplanillas
            @cia = @cia,
            @period = @period,
            @payrolltype = @payrolltype,
            @person_all = @person_all,
            @person = @person,
            @repunit_all = @repunit_all,
            @repunit = @repunit;

        SELECT
            CAST(1 AS INT) AS ok,
            CAST(0 AS INT) AS personas,
            CAST(0 AS INT) AS conceptos,
            CAST(
                CASE
                    WHEN @repunit_all = 'N' THEN
                        'Proceso completado (unidad ' + @repunit + ').'
                    ELSE
                        'Proceso completado.'
                END
            AS VARCHAR(255)) AS mensaje;
    END TRY
    BEGIN CATCH
        DECLARE @err VARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@err, 16, 1);
    END CATCH
END
GO
