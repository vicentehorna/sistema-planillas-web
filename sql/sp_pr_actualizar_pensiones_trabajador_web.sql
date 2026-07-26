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
    DECLARE @afp_id VARCHAR(20) = NULL;
    DECLARE @pension_pdt VARCHAR(20) = NULL;
    DECLARE @pensiontype_norm VARCHAR(20) = NULLIF(LTRIM(RTRIM(@pensiontype)), '');

    IF RTRIM(ISNULL(@pensioninscriptiondate, '')) <> ''
       AND ISDATE(@pensioninscriptiondate) = 1
        SET @fecha_inscripcion = CONVERT(DATETIME, @pensioninscriptiondate, 120);

    /* Resolver AFP automáticamente desde el régimen (sin UI). */
    IF @pensiontype_norm IS NOT NULL
    BEGIN
        SELECT @pension_pdt = LTRIM(RTRIM(ISNULL(pt.PDT, '')))
        FROM PR_PensionType pt (NOLOCK)
        WHERE pt.PensionType = @pensiontype_norm;

        IF @pension_pdt IN ('21', '23', '24', '25')
            OR EXISTS (
                SELECT 1
                FROM PR_PensionType pt (NOLOCK)
                WHERE pt.PensionType = @pensiontype_norm
                  AND (
                        UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) LIKE '%SPP%'
                     OR UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) LIKE '%AFP%'
                  )
                  AND UPPER(LTRIM(RTRIM(ISNULL(pt.Description, '')))) NOT LIKE '%ONP%'
            )
        BEGIN
            IF @pension_pdt IN ('21', '23', '24', '25')
                SELECT TOP 1 @afp_id = a.AFP
                FROM PR_AFP a (NOLOCK)
                WHERE a.Company = @cia
                  AND LTRIM(RTRIM(ISNULL(a.PDT, ''))) = @pension_pdt
                ORDER BY
                    CASE WHEN a.AFP LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END,
                    a.AFP;
        END;
    END;

    UPDATE pr_employee
    SET
        pensiontype = @pensiontype_norm,
        pensioninscriptiondate = @fecha_inscripcion,
        regimehealth = NULLIF(LTRIM(RTRIM(@regimehealth)), ''),
        flagmixta = @flagmixta,
        afpcard = NULLIF(LTRIM(RTRIM(@cuspp)), ''),
        afp = @afp_id,
        xlastdate = GETDATE(),
        xlastuser = NULLIF(LTRIM(RTRIM(@xlastuser)), '')
    WHERE company = @cia
      AND person = @person;
END
GO
