/*
    Detalle de descansos médicos de un trabajador para Registro de Descansos Médicos.
    Usado por: GET /descansos/trabajador/<id> (registro_descansos_medicos.html).

    Result sets:
      1 — Datos del empleado.
      2 — KPIs del año (@anio; por defecto año actual).
      3 — Historial completo de descansos (sin filtro de año).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_descansos_obtener_trabajador_web]
    @company VARCHAR(4),
    @person  VARCHAR(20),
    @anio    INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @anio IS NULL OR @anio < 1900
        SET @anio = YEAR(GETDATE());

    SELECT
        PR_Employee.Person AS person,
        PR_Employee.EmployeeCode AS codigo,
        LTRIM(RTRIM(
            ISNULL(SY_Person.LastName1, '') + ' ' +
            ISNULL(SY_Person.LastName2, '') + ' ' +
            ISNULL(SY_Person.Name1, '') + ' ' +
            ISNULL(SY_Person.Name2, '')
        )) AS nombre,
        SY_Person.DocumentNumber AS documento,
        ISNULL(PR_Employee.ReentryDate, PR_Employee.EntryDate) AS fechaingreso,
        PR_Employee.PayRollType AS payrolltype
    FROM PR_Employee
        INNER JOIN SY_Person
            ON PR_Employee.Person = SY_Person.Person
    WHERE PR_Employee.Company = @company
      AND PR_Employee.Person = @person;

    SELECT
        ISNULL(SUM(
            CASE
                WHEN emr.PayReponsableFlag = 'E'
                 AND LTRIM(RTRIM(ISNULL(mrt.PDT, ''))) = '20'
                THEN emr.Days
                ELSE 0
            END
        ), 0) AS dias_empleador,
        ISNULL(SUM(
            CASE
                WHEN emr.PayReponsableFlag = 'S'
                 AND LTRIM(RTRIM(ISNULL(mrt.PDT, ''))) IN ('21', '22')
                THEN emr.Days
                ELSE 0
            END
        ), 0) AS dias_essalud,
        ISNULL(SUM(emr.Days), 0) AS total_anio,
        20 AS limite_empleador
    FROM PR_EmployeeMedicalRest emr
        INNER JOIN PR_MedicalRestType mrt
            ON mrt.MedicalRestType = emr.MedicalRestType
           AND mrt.Company = emr.Company
    WHERE emr.Company = @company
      AND emr.Person = @person
      AND YEAR(emr.DateBegin) = @anio;

    SELECT
        emr.line AS line,
        emr.DateBegin AS datebegin,
        emr.DateEnd AS dateend,
        emr.Days AS days,
        emr.PRPeriod AS prperiod,
        emr.PayReponsableFlag AS payreponsableflag,
        CASE emr.PayReponsableFlag
            WHEN 'E' THEN 'Empleador'
            WHEN 'S' THEN 'Subsidio EsSalud'
            ELSE emr.PayReponsableFlag
        END AS cobertura_texto,
        emr.MedicalRestType AS medicalresttype,
        PR_MedicalRestType.Description AS tipo_descanso,
        PR_MedicalRestType.PDT AS pdt,
        emr.citt AS citt,
        emr.medico AS cmp_medico,
        emr.adjunto AS adjunto,
        emr.Status AS status,
        emr.XLastDate AS fecha_modificacion
    FROM PR_EmployeeMedicalRest emr
        INNER JOIN PR_MedicalRestType
            ON PR_MedicalRestType.MedicalRestType = emr.MedicalRestType
           AND PR_MedicalRestType.Company = emr.Company
    WHERE emr.Company = @company
      AND emr.Person = @person
    ORDER BY emr.DateBegin DESC, emr.line DESC;
END
GO
