/*
    Reporte Detallado de Tareos (hm_ngservicios).
    Una fila por día/registro — equivalente a sp_pr_reportetareos (PB9).

    Filtros alineados con sp_pr_reportetareo_consolidado:
      @repunit filtra por SY_Person.ReplicationUnit (unidad de ficha).

    Usado por: POST /api/tareo-ng/reporte-detalle
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportetareos_detalle_web]
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
        b.Person AS codigo,
        b.Name AS nombre,
        a.RegisterDate AS fecha,
        CASE
            WHEN a.RegisterType = 'A' THEN 'Normal'
            WHEN a.RegisterType = 'V' THEN 'Vacaciones'
            WHEN a.RegisterType = 'M' THEN 'Descanso Médico'
            WHEN a.RegisterType = 'D' THEN 'Descanso'
            WHEN a.RegisterType = 'L' THEN 'Licencia Con Goce'
            WHEN a.RegisterType = 'N' THEN 'Licencia Sin Goce'
            WHEN a.RegisterType = 'F' THEN 'Falta'
            WHEN a.RegisterType = 'S' THEN 'Suspensión'
            WHEN a.RegisterType = 'X' THEN 'Feriado Laborado'
            WHEN a.RegisterType = 'P' THEN 'Licencia Paternidad'
            ELSE ISNULL(a.RegisterType, '')
        END AS tipo_dia,
        /* En PB9: columna Agencia = costcenter (nombre CC) */
        c.Name AS agencia,
        /* En PB9: columna Cliente = unidad del centro de costo */
        (
            SELECT TOP 1 ru.Name
            FROM SY_ReplicationUnit ru
            WHERE ru.ReplicationUnit = c.ReplicationUnit
        ) AS cliente,
        (
            SELECT TOP 1 pt.Description
            FROM PR_PayRollType pt
            WHERE pt.PayRollType = a.Payrolltype
        ) AS tipo_planilla,
        ISNULL(a.hourday, 0) AS horas,
        ISNULL(a.extrahour25, 0) AS h25,
        ISNULL(a.extrahour35, 0) AS h35,
        ISNULL(a.extrahour100, 0) AS hnoc,
        c.CCCode AS cccode
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
      AND (
            LTRIM(RTRIM(ISNULL(a.Company, ''))) = ''
            OR a.Company = @company
          )
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
    ORDER BY b.Name, a.RegisterDate;
END
GO
