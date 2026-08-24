/*
    Borrar tareos filtrados de PR_REGISTERHOUR (hm_ngservicios).
    Mismos criterios que sp_pr_reportetareos_detalle_web.

    Obligatorio: @company + rango de fechas (@fecha_all='N' con @fecha_ini/@fecha_fin).
    Devuelve: eliminados (INT), mensaje (VARCHAR).

    Usado por: POST /api/tareo-ng/reporte-detalle/borrar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_borrar_tareos_filtrados_web]
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

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@payrolltype_all, 'Y'))), 1));
    SET @fecha_all = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@fecha_all, 'N'))), 1));
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

    IF @company = ''
    BEGIN
        SELECT 0 AS eliminados, 'Seleccione una compañía.' AS mensaje;
        RETURN;
    END;

    /* Seguridad: siempre exigir rango de fechas (no borrar toda la historia). */
    IF @fecha_all = 'Y' OR @fecha_ini IS NULL OR @fecha_fin IS NULL
    BEGIN
        SELECT 0 AS eliminados, 'Indique un rango de fechas para borrar.' AS mensaje;
        RETURN;
    END;

    IF CONVERT(DATE, @fecha_ini) > CONVERT(DATE, @fecha_fin)
    BEGIN
        SELECT 0 AS eliminados, 'La fecha inicial no puede ser mayor que la final.' AS mensaje;
        RETURN;
    END;

    DECLARE @eliminados INT = 0;

    DELETE a
    FROM PR_REGISTERHOUR a
        INNER JOIN SY_Person b
            ON a.Person = b.Person
        INNER JOIN AC_CostCenter c
            ON a.CostCenter = c.CostCenter
        INNER JOIN PR_Employee d
            ON a.Person = d.Person
           AND d.Status = 'N'
           AND d.Company = @company
    WHERE c.Company = @company
      AND (
            LTRIM(RTRIM(ISNULL(a.Company, ''))) = ''
            OR a.Company = @company
          )
      AND (@payrolltype_all = 'Y' OR a.Payrolltype = @payrolltype)
      AND CONVERT(VARCHAR(8), a.RegisterDate, 112) BETWEEN
            CONVERT(VARCHAR(8), CONVERT(DATETIME, @fecha_ini), 112)
            AND CONVERT(VARCHAR(8), CONVERT(DATETIME, @fecha_fin), 112)
      AND (@person_all = 'Y' OR a.Person = @person)
      AND (@costcenter_all = 'Y' OR a.CostCenter = @costcenter)
      AND (
            @repunit_all = 'Y'
            OR LTRIM(RTRIM(ISNULL(b.ReplicationUnit, ''))) = @repunit
          )
      AND (@tipodia_all = 'Y' OR a.RegisterType = @tipodia);

    SET @eliminados = @@ROWCOUNT;

    SELECT
        @eliminados AS eliminados,
        CASE
            WHEN @eliminados = 0 THEN 'No hay tareos que coincidan con el filtro.'
            WHEN @eliminados = 1 THEN 'Se eliminó 1 registro de tareo.'
            ELSE 'Se eliminaron ' + CONVERT(VARCHAR(20), @eliminados) + ' registros de tareo.'
        END AS mensaje;
END
GO
