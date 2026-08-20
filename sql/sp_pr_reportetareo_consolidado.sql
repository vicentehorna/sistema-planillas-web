/*
    Reporte consolidado de tareos NG (hm_ngservicios).
    Totales por trabajador según compañía, planilla, fechas, persona, CC, unidad y tipo de día.

    @repunit_all / @repunit: filtra por SY_Person.ReplicationUnit (unidad de ficha).
    Si @repunit_all = 'Y' o @repunit vacío/'0', no filtra por unidad.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportetareo_consolidado]
    @company         VARCHAR(4),
    @payrolltype_all CHAR(1),
    @payrolltype     VARCHAR(20),
    @fecha_all       CHAR(1),
    @fecha_ini       DATETIME,
    @fecha_fin       DATETIME,
    @person_all      CHAR(1),
    @person          VARCHAR(20),
    @costcenter_all  CHAR(1),
    @costcenter      VARCHAR(20),
    @repunit_all     CHAR(1),
    @repunit         VARCHAR(20),
    @tipodia_all     CHAR(1),
    @tipodia         CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    SET @payrolltype_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@payrolltype_all, 'Y'))), 1));
    SET @fecha_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@fecha_all, 'Y'))), 1));
    SET @person_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@person_all, 'Y'))), 1));
    SET @costcenter_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@costcenter_all, 'Y'))), 1));
    SET @repunit_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@repunit_all, 'Y'))), 1));
    SET @tipodia_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@tipodia_all, 'Y'))), 1));

    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @costcenter = LTRIM(RTRIM(ISNULL(@costcenter, '')));
    SET @repunit = LTRIM(RTRIM(ISNULL(@repunit, '')));
    IF @repunit IN ('0', '*') SET @repunit = '';
    IF @repunit = '' SET @repunit_all = 'Y';

    SELECT
        dni,
        nombre,
        SUM(horas) AS horas,
        SUM(h25) AS h25,
        SUM(h35) AS h35,
        SUM(hnoc) AS hnoc,
        SUM(faltas) AS faltas,
        SUM(vacas) AS vacas,
        SUM(dm) AS dm,
        SUM(suspen) AS suspen,
        SUM(lcg) AS lcg,
        SUM(lsg) AS lsg,
        SUM(lpat) AS lpat,
        SUM(fer) AS fer,
        SUM(descanso) AS descanso,
        SUM(normal) + SUM(descanso) AS diastrab
    FROM (
        SELECT
            b.DocumentNumber AS dni,
            b.Name AS nombre,
            a.RegisterDate AS fecha,
            ISNULL(a.hourday, 0) AS horas,
            ISNULL(a.extrahour25, 0) AS h25,
            ISNULL(a.extrahour35, 0) AS h35,
            ISNULL(a.extrahour100, 0) AS hnoc,
            CASE WHEN a.RegisterType = 'A' THEN 1 ELSE 0 END AS normal,
            CASE WHEN a.RegisterType = 'F' THEN 1 ELSE 0 END AS faltas,
            CASE WHEN a.RegisterType = 'V' THEN 1 ELSE 0 END AS vacas,
            CASE WHEN a.RegisterType = 'M' THEN 1 ELSE 0 END AS dm,
            CASE WHEN a.RegisterType = 'S' THEN 1 ELSE 0 END AS suspen,
            CASE WHEN a.RegisterType = 'L' THEN 1 ELSE 0 END AS lcg,
            CASE WHEN a.RegisterType = 'N' THEN 1 ELSE 0 END AS lsg,
            CASE WHEN a.RegisterType = 'P' THEN 1 ELSE 0 END AS lpat,
            CASE WHEN a.RegisterType = 'X' THEN 1 ELSE 0 END AS fer,
            CASE WHEN a.RegisterType = 'D' THEN 1 ELSE 0 END AS descanso
        FROM PR_REGISTERHOUR a
            INNER JOIN SY_Person b
                ON a.Person = b.Person
            INNER JOIN AC_CostCenter c
                ON a.CostCenter = c.CostCenter
            INNER JOIN PR_Employee d
                ON a.Person = d.Person
               AND d.Status = 'N'
               AND d.Company = @company
            INNER JOIN SY_Company e
                ON e.Company = d.Company
        WHERE c.Company = @company
          AND (@payrolltype_all = 'Y' OR a.Payrolltype = @payrolltype)
          AND (
                @fecha_all = 'Y'
                OR CONVERT(VARCHAR(8), a.RegisterDate, 112) BETWEEN
                    CONVERT(VARCHAR(8), CONVERT(DATETIME, @fecha_ini), 112)
                    AND CONVERT(VARCHAR(8), CONVERT(DATETIME, @fecha_fin), 112)
              )
          AND (@person_all = 'Y' OR a.Person = @person)
          AND (@costcenter_all = 'Y' OR a.CostCenter = @costcenter)
          AND (
                @repunit_all = 'Y'
                OR LTRIM(RTRIM(ISNULL(b.ReplicationUnit, ''))) = @repunit
              )
          AND (@tipodia_all = 'Y' OR a.RegisterType = @tipodia)
    ) T
    GROUP BY dni, nombre
    ORDER BY 2;
END
GO
