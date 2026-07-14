/*
    Actualiza datos de pensiones del trabajador (PR_Employee).
    Clave: person + company (@cia).
    Fecha inscripción: VARCHAR(10) YYYY-MM-DD o vacío → NULL.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_pensiones_trabajador_web]
    @cia                        VARCHAR(10),
    @person                     VARCHAR(20),
    @pensiontype                VARCHAR(20),
    @pensioninscriptiondate     VARCHAR(10) = '',
    @regimehealth               VARCHAR(20),
    @flagmixta                  VARCHAR(1) = 'N',
    @cuspp                      VARCHAR(20) = NULL,
    @xlastuser                  VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM pr_employee
        WHERE company = @cia AND person = @person
    )
    BEGIN
        RAISERROR('Trabajador no encontrado para la compañía indicada.', 16, 1);
        RETURN;
    END

    IF RTRIM(ISNULL(@flagmixta, '')) NOT IN ('Y', 'N') SET @flagmixta = 'N';

    DECLARE @fecha_inscripcion DATETIME = NULL;
    IF RTRIM(ISNULL(@pensioninscriptiondate, '')) <> ''
       AND ISDATE(@pensioninscriptiondate) = 1
        SET @fecha_inscripcion = CONVERT(DATETIME, @pensioninscriptiondate, 120);

    UPDATE pr_employee
    SET
        pensiontype = NULLIF(LTRIM(RTRIM(@pensiontype)), ''),
        pensioninscriptiondate = @fecha_inscripcion,
        regimehealth = NULLIF(LTRIM(RTRIM(@regimehealth)), ''),
        flagmixta = @flagmixta,
        afpcard = NULLIF(LTRIM(RTRIM(@cuspp)), ''),
        xlastdate = GETDATE(),
        xlastuser = NULLIF(LTRIM(RTRIM(@xlastuser)), '')
    WHERE company = @cia
      AND person = @person;
END
GO
