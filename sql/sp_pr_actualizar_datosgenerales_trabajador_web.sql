/*
    Actualiza datos generales de SY_Person para un trabajador web.
    El código (person) no se modifica. Status siempre Activo (A).
    Name se calcula: ApellidoPaterno + ApellidoMaterno + Nombre1 + Nombre2.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_datosgenerales_trabajador_web]
    @cia                    VARCHAR(10),
    @person                 VARCHAR(20),
    @name1                  VARCHAR(40),
    @name2                  VARCHAR(40) = NULL,
    @lastname1              VARCHAR(40),
    @lastname2              VARCHAR(40) = NULL,
    @sectelephone           VARCHAR(15) = NULL,
    @email                  VARCHAR(255) = NULL,
    @employeedocumenttype   VARCHAR(20),
    @documentnumber         VARCHAR(15),
    @replicationunit        VARCHAR(4),
    @userid                 VARCHAR(20) = NULL,
    @xlastuser              VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @nombre_completo VARCHAR(100);
    DECLARE @userid_norm     VARCHAR(20);

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = UPPER(LTRIM(RTRIM(ISNULL(@person, ''))));
    SET @name1 = UPPER(LTRIM(RTRIM(ISNULL(@name1, ''))));
    SET @name2 = UPPER(LTRIM(RTRIM(ISNULL(@name2, ''))));
    SET @lastname1 = UPPER(LTRIM(RTRIM(ISNULL(@lastname1, ''))));
    SET @lastname2 = UPPER(LTRIM(RTRIM(ISNULL(@lastname2, ''))));
    SET @sectelephone = NULLIF(LTRIM(RTRIM(ISNULL(@sectelephone, ''))), '');
    SET @email = NULLIF(LTRIM(RTRIM(ISNULL(@email, ''))), '');
    SET @employeedocumenttype = LTRIM(RTRIM(ISNULL(@employeedocumenttype, '')));
    SET @documentnumber = LTRIM(RTRIM(ISNULL(@documentnumber, '')));
    SET @replicationunit = UPPER(LTRIM(RTRIM(ISNULL(@replicationunit, ''))));
    SET @userid_norm = NULLIF(LOWER(LTRIM(RTRIM(ISNULL(@userid, '')))), '');
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @cia = '' OR @person = ''
    BEGIN
        RAISERROR('Indique compañía y código de trabajador.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM pr_employee (NOLOCK)
        WHERE company = @cia
          AND person = @person
    )
    BEGIN
        RAISERROR('Trabajador no encontrado para la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sy_person (NOLOCK)
        WHERE person = @person
    )
    BEGIN
        RAISERROR('No se encontró la persona indicada.', 16, 1);
        RETURN;
    END;

    IF @name1 = '' OR @lastname1 = ''
    BEGIN
        RAISERROR('Indique primer nombre y apellido paterno.', 16, 1);
        RETURN;
    END;

    IF @employeedocumenttype = ''
    BEGIN
        RAISERROR('Indique el tipo de documento.', 16, 1);
        RETURN;
    END;

    IF @documentnumber = ''
    BEGIN
        RAISERROR('Indique el número de documento.', 16, 1);
        RETURN;
    END;

    IF @replicationunit = ''
    BEGIN
        RAISERROR('Indique la unidad.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sy_persondocumenttype (NOLOCK)
        WHERE persondocumenttype = @employeedocumenttype
          AND company = @cia
    )
    BEGIN
        RAISERROR('Tipo de documento no válido para la compañía.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM sy_replicationunit (NOLOCK)
        WHERE replicationunit = @replicationunit
    )
    BEGIN
        RAISERROR('Unidad no válida.', 16, 1);
        RETURN;
    END;

    IF @userid_norm IS NOT NULL
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM sy_user (NOLOCK)
            WHERE userid = @userid_norm
        )
        BEGIN
            RAISERROR('El usuario indicado no existe en el sistema.', 16, 1);
            RETURN;
        END;

        IF EXISTS (
            SELECT 1
            FROM sy_person (NOLOCK)
            WHERE userid = @userid_norm
              AND person <> @person
        )
        BEGIN
            RAISERROR('El usuario ya está asignado a otro trabajador.', 16, 1);
            RETURN;
        END;
    END;

    SET @nombre_completo = UPPER(LTRIM(RTRIM(
        ISNULL(@lastname1, '') + ' ' +
        ISNULL(@lastname2, '') + ' ' +
        ISNULL(@name1, '') + ' ' +
        ISNULL(@name2, '')
    )));

    IF LEN(@nombre_completo) > 100
        SET @nombre_completo = LEFT(@nombre_completo, 100);

    UPDATE sy_person
    SET name1 = @name1,
        name2 = NULLIF(@name2, ''),
        lastname1 = @lastname1,
        lastname2 = NULLIF(@lastname2, ''),
        name = @nombre_completo,
        sectelephone = @sectelephone,
        email = @email,
        employeedocumenttype = @employeedocumenttype,
        documenttype = @employeedocumenttype,
        documentnumber = @documentnumber,
        replicationunit = @replicationunit,
        userid = @userid_norm,
        flaguserid = CASE WHEN @userid_norm IS NULL THEN 'N' ELSE 'Y' END,
        status = 'A',
        flagname = 'P',
        isemployee = 'Y',
        xlastuser = @xlastuser,
        xlastdate = GETDATE()
    WHERE person = @person;
END
GO
