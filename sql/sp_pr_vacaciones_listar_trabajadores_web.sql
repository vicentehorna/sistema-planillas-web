/*
    Listado de trabajadores activos para el módulo Registro de Vacaciones.
    Usado por: POST /api/vacaciones/trabajadores (registro_vacaciones.html).

    Parámetros:
      @company     — obligatorio.
      @payrolltype — '0' = todos los tipos de planilla.
      @busqueda    — filtro opcional por nombre o documento.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_vacaciones_listar_trabajadores_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20) = '0',
    @busqueda    VARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@payrolltype, '')) = '' SET @payrolltype = '0';
    SET @busqueda = LTRIM(RTRIM(ISNULL(@busqueda, '')));

    SELECT
        PR_EMPLOYEE.PERSON AS person,
        PR_EMPLOYEE.EMPLOYEECODE AS codigo,
        LTRIM(RTRIM(
            ISNULL(SY_PERSON.LASTNAME1, '') + ' ' +
            ISNULL(SY_PERSON.LASTNAME2, '') + ' ' +
            ISNULL(SY_PERSON.NAME1, '') + ' ' +
            ISNULL(SY_PERSON.NAME2, '')
        )) AS nombre,
        SY_PERSON.DOCUMENTNUMBER AS documento,
        ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS fechaingreso,
        PR_EMPLOYEE.PAYROLLTYPE AS payrolltype,
        PR_PAYROLLTYPE.DESCRIPTION AS tipoplanilla
    FROM PR_EMPLOYEE
        INNER JOIN SY_PERSON
            ON PR_EMPLOYEE.PERSON = SY_PERSON.PERSON
        LEFT JOIN PR_PAYROLLTYPE
            ON PR_EMPLOYEE.PAYROLLTYPE = PR_PAYROLLTYPE.PAYROLLTYPE
    WHERE PR_EMPLOYEE.COMPANY = @company
      AND PR_EMPLOYEE.STATUS = 'N'
      AND PR_EMPLOYEE.CEASEDATE IS NULL
      AND (@payrolltype = '0' OR PR_EMPLOYEE.PAYROLLTYPE = @payrolltype)
      AND (
            @busqueda = ''
         OR SY_PERSON.DOCUMENTNUMBER LIKE '%' + @busqueda + '%'
         OR LTRIM(RTRIM(
                ISNULL(SY_PERSON.LASTNAME1, '') + ' ' +
                ISNULL(SY_PERSON.LASTNAME2, '') + ' ' +
                ISNULL(SY_PERSON.NAME1, '') + ' ' +
                ISNULL(SY_PERSON.NAME2, '')
            )) LIKE '%' + @busqueda + '%'
         OR PR_EMPLOYEE.EMPLOYEECODE LIKE '%' + @busqueda + '%'
      )
    ORDER BY nombre;
END
GO
