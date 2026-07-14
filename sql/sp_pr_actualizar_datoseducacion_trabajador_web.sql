/*
    Actualiza datos de educación en SY_Person para un trabajador web.
    Reutiliza campos del legado:
      InstructionLevel, CostCenter1, CostCenter2, DriverLicenseAntiquity,
      Specialty, ProfesionalStudiesCenterType, IsTrainer, Indicator.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_datoseducacion_trabajador_web]
    @cia                            VARCHAR(10),
    @person                         VARCHAR(20),
    @instructionlevel               VARCHAR(20) = NULL,
    @costcenter1                    VARCHAR(20) = NULL,
    @costcenter2                    VARCHAR(20) = NULL,
    @anio_egreso                    VARCHAR(10) = NULL,
    @specialty                      VARCHAR(100) = NULL,
    @profesionalstudiescentertype   CHAR(1) = NULL,
    @istrainer                      CHAR(1) = NULL,
    @indicator                      CHAR(1) = NULL,
    @xlastuser                      VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @anio_int INT;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = UPPER(LTRIM(RTRIM(ISNULL(@person, ''))));
    SET @instructionlevel = NULLIF(LTRIM(RTRIM(ISNULL(@instructionlevel, ''))), '');
    SET @costcenter1 = NULLIF(LTRIM(RTRIM(ISNULL(@costcenter1, ''))), '');
    SET @costcenter2 = NULLIF(LTRIM(RTRIM(ISNULL(@costcenter2, ''))), '');
    SET @anio_egreso = NULLIF(LTRIM(RTRIM(ISNULL(@anio_egreso, ''))), '');
    SET @specialty = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@specialty, '')))), '');
    SET @profesionalstudiescentertype = NULLIF(LTRIM(RTRIM(ISNULL(@profesionalstudiescentertype, ''))), '');
    SET @istrainer = UPPER(NULLIF(LTRIM(RTRIM(ISNULL(@istrainer, ''))), ''));
    SET @indicator = NULLIF(LTRIM(RTRIM(ISNULL(@indicator, ''))), '');
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @cia = '' OR @person = ''
    BEGIN
        RAISERROR('Indique compañía y código de trabajador.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM pr_employee (NOLOCK)
        WHERE company = @cia AND person = @person
    )
    BEGIN
        RAISERROR('Trabajador no encontrado para la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM sy_person (NOLOCK) WHERE person = @person)
    BEGIN
        RAISERROR('No se encontró la persona indicada.', 16, 1);
        RETURN;
    END;

    IF @instructionlevel IS NOT NULL
       AND NOT EXISTS (
            SELECT 1 FROM pr_instructionlevel (NOLOCK)
            WHERE instructionlevel = @instructionlevel
       )
    BEGIN
        RAISERROR('Nivel de instrucción no válido.', 16, 1);
        RETURN;
    END;

    IF @costcenter1 IS NOT NULL
       AND NOT EXISTS (
            SELECT 1 FROM pr_institution (NOLOCK)
            WHERE company = @cia AND pdt = @costcenter1
       )
    BEGIN
        RAISERROR('Institución no válida para la compañía.', 16, 1);
        RETURN;
    END;

    IF @costcenter2 IS NOT NULL
    BEGIN
        IF @costcenter1 IS NULL
        BEGIN
            RAISERROR('Seleccione la institución antes de la carrera.', 16, 1);
            RETURN;
        END;

        IF NOT EXISTS (
            SELECT 1
            FROM pr_career c (NOLOCK)
                INNER JOIN pr_institution i (NOLOCK)
                    ON i.institution = c.institution
                   AND i.company = c.company
            WHERE c.company = @cia
              AND i.pdt = @costcenter1
              AND c.pdt = @costcenter2
        )
        BEGIN
            RAISERROR('Carrera no válida para la institución seleccionada.', 16, 1);
            RETURN;
        END;
    END;

    SET @anio_int = NULL;
    IF @anio_egreso IS NOT NULL
    BEGIN
        IF ISNUMERIC(@anio_egreso) = 0
           OR LEN(@anio_egreso) <> 4
           OR CAST(@anio_egreso AS INT) < 1900
           OR CAST(@anio_egreso AS INT) > 2100
        BEGIN
            RAISERROR('Año de egreso no válido. Use formato YYYY (ej. 1997).', 16, 1);
            RETURN;
        END;
        SET @anio_int = CAST(@anio_egreso AS INT);
    END;

    IF @profesionalstudiescentertype IS NOT NULL
       AND @profesionalstudiescentertype NOT IN ('1', '2', '3', '4')
    BEGIN
        RAISERROR('Tipo de centro de formación no válido.', 16, 1);
        RETURN;
    END;

    IF @istrainer IS NULL
        SET @istrainer = 'N';
    IF @istrainer NOT IN ('Y', 'N')
    BEGIN
        RAISERROR('Valor de estudios concluidos no válido.', 16, 1);
        RETURN;
    END;

    IF @indicator IS NOT NULL AND LEN(@indicator) > 1
    BEGIN
        RAISERROR('Indicador no válido.', 16, 1);
        RETURN;
    END;

    UPDATE sy_person
    SET instructionlevel = @instructionlevel,
        costcenter1 = @costcenter1,
        costcenter2 = @costcenter2,
        driverlicenseantiquity = @anio_int,
        specialty = @specialty,
        profesionalstudiescentertype = @profesionalstudiescentertype,
        istrainer = @istrainer,
        indicator = @indicator,
        xlastuser = @xlastuser,
        xlastdate = GETDATE()
    WHERE person = @person;
END
GO
