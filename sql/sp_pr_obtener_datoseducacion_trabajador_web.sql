/*
    Datos de educación de SY_Person para edición web del trabajador.
    Campos reutilizados del legado (w_pr_person_edit / Datos Adicionales):
      instructionlevel, costcenter1 (institución PDT), costcenter2 (carrera PDT),
      driverlicenseantiquity (año egreso), specialty, profesionalstudiescentertype,
      istrainer (estudios concluidos), indicator.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtener_datoseducacion_trabajador_web]
    @cia    VARCHAR(10),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = UPPER(LTRIM(RTRIM(ISNULL(@person, ''))));

    SELECT
        e.person,
        e.company,
        e.employeecode,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        ISNULL(sc.description, '') AS company_desc,
        LTRIM(RTRIM(ISNULL(sp.instructionlevel, ''))) AS instructionlevel,
        LTRIM(RTRIM(ISNULL(il.description, ''))) AS instructionlevel_desc,
        LTRIM(RTRIM(ISNULL(sp.costcenter1, ''))) AS costcenter1,
        LTRIM(RTRIM(ISNULL(inst.description, ''))) AS institucion_desc,
        LTRIM(RTRIM(ISNULL(sp.costcenter2, ''))) AS costcenter2,
        LTRIM(RTRIM(ISNULL(car.description, ''))) AS carrera_desc,
        CASE
            WHEN sp.driverlicenseantiquity IS NULL THEN ''
            ELSE LTRIM(RTRIM(CAST(sp.driverlicenseantiquity AS VARCHAR(20))))
        END AS anio_egreso,
        LTRIM(RTRIM(ISNULL(sp.specialty, ''))) AS specialty,
        LTRIM(RTRIM(ISNULL(sp.profesionalstudiescentertype, ''))) AS profesionalstudiescentertype,
        LTRIM(RTRIM(ISNULL(sp.istrainer, 'N'))) AS istrainer,
        LTRIM(RTRIM(ISNULL(sp.indicator, ''))) AS indicator
    FROM pr_employee e (NOLOCK)
        INNER JOIN sy_person sp (NOLOCK)
            ON sp.person = e.person
        LEFT JOIN sy_company sc (NOLOCK)
            ON sc.company = e.company
        LEFT JOIN pr_instructionlevel il (NOLOCK)
            ON il.instructionlevel = sp.instructionlevel
        LEFT JOIN pr_institution inst (NOLOCK)
            ON inst.company = e.company
           AND inst.pdt = sp.costcenter1
        LEFT JOIN pr_career car (NOLOCK)
            ON car.company = e.company
           AND car.institution = inst.institution
           AND car.pdt = sp.costcenter2
    WHERE e.company = @cia
      AND e.person = @person;
END
GO
