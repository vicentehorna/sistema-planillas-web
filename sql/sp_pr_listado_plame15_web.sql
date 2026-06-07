/*
    PLAME Archivo 15 (.snl) — Días subsidiados y no laborados.

    Usado por: POST /api/plame/archivo-15/listado y generación TXT.

    Línea TXT: TipoDoc|NroDoc|TipoSuspensión|Días|
    Ejemplo:   01|46741460|01|07|

    Parámetros:
      @cia    — compañía
      @period — periodo tributario YYYYMM (6 dígitos)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_plame15_web]
    @cia    VARCHAR(10),
    @period VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    SELECT
        D.person,
        CASE WHEN sy_persondocumenttype.pdt = '03' THEN '04' ELSE sy_persondocumenttype.pdt END AS documenttype,
        LTRIM(RTRIM(sy_person.documentnumber)) AS documentnumber,
        LTRIM(RTRIM(
            ISNULL(sy_person.lastname1, '') + ' ' +
            ISNULL(sy_person.lastname2, '') + ' ' +
            ISNULL(sy_person.name1, '') + ' ' +
            ISNULL(sy_person.name2, '')
        )) AS name,
        LTRIM(RTRIM(D.pdt)) AS suspensiontype,
        LTRIM(RTRIM(ISNULL(T21.description, D.pdt))) AS suspensionname,
        CAST(D.days AS INT) AS days,
        'N' AS selection
    FROM (
        /* Descanso médico — ESSALUD / subsidio (payreponsableflag = S) */
        SELECT
            pr_employee.person AS person,
            pr_medicalresttype.pdt AS pdt,
            SUM(pr_employeemedicalrest.days) AS days
        FROM pr_employee (NOLOCK)
            INNER JOIN pr_employeemedicalrest (NOLOCK)
                ON pr_employee.person = pr_employeemedicalrest.person
               AND pr_employee.company = pr_employeemedicalrest.company
            INNER JOIN pr_medicalresttype (NOLOCK)
                ON pr_medicalresttype.medicalresttype = pr_employeemedicalrest.medicalresttype
        WHERE pr_employee.company = @cia
          AND LEFT(pr_employeemedicalrest.prperiod, 6) = @period
          AND pr_medicalresttype.pdt IN ('01', '05', '07', '26', '20', '21', '22')
          AND pr_employeemedicalrest.payreponsableflag = 'S'
        GROUP BY
            pr_employee.person,
            pr_medicalresttype.pdt

        UNION

        /* Vacaciones — días (tipo D) */
        SELECT
            pr_vacationdetail.person AS person,
            pr_mapping.vacationpdt AS pdt,
            SUM(pr_vacationdetail.days) AS days
        FROM pr_vacationdetail (NOLOCK)
            INNER JOIN pr_mapping (NOLOCK)
                ON pr_mapping.company = @cia
        WHERE pr_vacationdetail.company = @cia
          AND pr_vacationdetail.vacationtype = 'D'
          AND LEFT(pr_vacationdetail.prperiod, 6) = @period
        GROUP BY
            pr_vacationdetail.person,
            pr_mapping.vacationpdt

        UNION

        /* Descanso médico — empleador (payreponsableflag = E) */
        SELECT
            pr_employeemedicalrest.person AS person,
            pr_medicalresttype.pdt AS pdt,
            SUM(pr_employeemedicalrest.days) AS days
        FROM pr_employeemedicalrest (NOLOCK)
            INNER JOIN pr_medicalresttype (NOLOCK)
                ON pr_employeemedicalrest.medicalresttype = pr_medicalresttype.medicalresttype
        WHERE pr_employeemedicalrest.company = @cia
          AND pr_medicalresttype.company = @cia
          AND LEFT(pr_employeemedicalrest.prperiod, 6) = @period
          AND pr_employeemedicalrest.payreponsableflag = 'E'
          AND pr_medicalresttype.pdt NOT IN ('21', '22', '99')
        GROUP BY
            pr_employeemedicalrest.person,
            pr_medicalresttype.pdt
    ) D
        INNER JOIN pr_employee (NOLOCK)
            ON pr_employee.person = D.person
           AND pr_employee.company = @cia
        INNER JOIN sy_person (NOLOCK)
            ON sy_person.person = pr_employee.person
        LEFT JOIN sy_persondocumenttype (NOLOCK)
            ON sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype
        LEFT JOIN (
            SELECT
                LTRIM(RTRIM(pdt)) AS pdt,
                MIN(LTRIM(RTRIM(Description))) AS description
            FROM pr_medicalresttype (NOLOCK)
            WHERE company = @cia
            GROUP BY LTRIM(RTRIM(pdt))
        ) T21
            ON T21.pdt = LTRIM(RTRIM(D.pdt))
    WHERE ISNULL(D.days, 0) <> 0
      AND LTRIM(RTRIM(ISNULL(sy_person.documentnumber, ''))) <> ''
    ORDER BY name, suspensiontype;
END
GO
