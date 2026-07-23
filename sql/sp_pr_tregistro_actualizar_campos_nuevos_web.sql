/*
    Actualiza solo campos post T-Registro que no vienen del ZIP:
      Position, CostCenter (+CostCenterName), AccountProfile,
      FlagAsigFamiliar, FlagMixta.

    Usado por: POST /api/tregistro-importacion/campos-nuevos/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_tregistro_actualizar_campos_nuevos_web]
    @cia              VARCHAR(10),
    @person           VARCHAR(20),
    @position         VARCHAR(20) = NULL,
    @costcenter       VARCHAR(20) = NULL,
    @accountprofile   VARCHAR(20) = NULL,
    @flagasigfamiliar VARCHAR(1) = 'N',
    @flagmixta        VARCHAR(1) = 'N',
    @xlastuser        VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    IF @cia = '' OR @person = ''
    BEGIN
        RAISERROR('Debe indicar compania y trabajador.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Employee (NOLOCK)
        WHERE Company = @cia
          AND Person = @person
    )
    BEGIN
        RAISERROR('Trabajador no encontrado para la compania indicada.', 16, 1);
        RETURN;
    END;

    IF RTRIM(ISNULL(@flagasigfamiliar, '')) NOT IN ('Y', 'N') SET @flagasigfamiliar = 'N';
    IF RTRIM(ISNULL(@flagmixta, '')) NOT IN ('Y', 'N') SET @flagmixta = 'N';

    DECLARE @costcentername VARCHAR(100) = NULL;
    IF NULLIF(LTRIM(RTRIM(ISNULL(@costcenter, ''))), '') IS NOT NULL
    BEGIN
        SELECT TOP 1 @costcentername = LTRIM(RTRIM(ISNULL(cc.Name, '')))
        FROM AC_CostCenter cc (NOLOCK)
        WHERE cc.Company = @cia
          AND cc.CostCenter = LTRIM(RTRIM(@costcenter));
    END;

    UPDATE PR_Employee
    SET
        Position = NULLIF(LTRIM(RTRIM(@position)), ''),
        CostCenter = NULLIF(LTRIM(RTRIM(@costcenter)), ''),
        CostCenterName = CASE
            WHEN NULLIF(LTRIM(RTRIM(@costcenter)), '') IS NULL THEN NULL
            ELSE NULLIF(@costcentername, '')
        END,
        AccountProfile = NULLIF(LTRIM(RTRIM(@accountprofile)), ''),
        FlagAsigFamiliar = @flagasigfamiliar,
        FlagMixta = @flagmixta,
        xlastdate = GETDATE(),
        xlastuser = NULLIF(LTRIM(RTRIM(@xlastuser)), '')
    WHERE Company = @cia
      AND Person = @person;

    SELECT
        CAST(1 AS INT) AS ok,
        @cia AS cia,
        @person AS person,
        'Campos actualizados correctamente.' AS mensaje;
END
GO
