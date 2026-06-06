/*
    Listado de trabajadores para el módulo web de Planillas.
    Filtros: compañía (obligatorio), tipo planilla, trabajador (person), DNI, nombre,
    estado, banco haberes y cesados.
    Parámetros opcionales con valor '0' o vacío = sin filtro (excepto estado: A = Activos por defecto).
    @cesados: T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listatrabajadores_web]
    @cia          VARCHAR(4),
    @payrolltype  VARCHAR(20),
    @person       VARCHAR(20),
    @docnro       VARCHAR(20),
    @nombre       VARCHAR(100),
    @estado       VARCHAR(1),
    @salarybank   VARCHAR(20),
    @cesados      CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@payrolltype, '')) = '' SET @payrolltype = '0';
    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF @docnro IS NULL SET @docnro = '';
    IF @nombre IS NULL SET @nombre = '';
    SET @nombre = LTRIM(RTRIM(@nombre));
    IF RTRIM(ISNULL(@estado, '')) = '' SET @estado = 'A';
    IF RTRIM(ISNULL(@salarybank, '')) = '' SET @salarybank = '0';
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';

    SELECT
        PR_PAYROLLTYPE.DESCRIPTION AS tipoplanilla,
        PR_EMPLOYEE.EMPLOYEECODE AS codigo,
        PR_EMPLOYEE.PERSON AS person,
        LTRIM(RTRIM(
            ISNULL(SY_PERSON_A.LASTNAME1, '') + ' ' +
            ISNULL(SY_PERSON_A.LASTNAME2, '') + ' ' +
            ISNULL(SY_PERSON_A.NAME1, '') + ' ' +
            ISNULL(SY_PERSON_A.NAME2, '')
        )) AS nombre,
        CASE PR_EMPLOYEE.STATUS
            WHEN 'N' THEN 'Activo'
            ELSE 'Inactivo'
        END AS estado,
        SY_PERSONDOCUMENTTYPE.DESCRIPTION AS tipodocumento,
        SY_PERSON_A.DOCUMENTNUMBER AS numerodocumento,
        PR_EMPLOYEE.ENTRYDATE AS fechaingreso,
        PR_EMPLOYEE.CEASEDATE AS fechacese,
        PR_POSITION.DESCRIPTION AS cargo,
        ISNULL(AC_COSTCENTER.NAME, PR_EMPLOYEE.COSTCENTERNAME) AS centrocosto,
        SY_PERSON_A.TELEPHONE AS telefono,
        SY_PERSON_A.EMAIL AS email,
        PR_EMPLOYEETYPE.DESCRIPTION AS tipotrabajador,
        PR_EMPLOYEECATEGORY.DESCRIPTION AS categoria
    FROM PR_EMPLOYEE
        INNER JOIN SY_PERSON SY_PERSON_A
            ON PR_EMPLOYEE.PERSON = SY_PERSON_A.PERSON
        LEFT JOIN PR_PAYROLLTYPE
            ON PR_EMPLOYEE.PAYROLLTYPE = PR_PAYROLLTYPE.PAYROLLTYPE
        LEFT JOIN SY_PERSONDOCUMENTTYPE
            ON SY_PERSON_A.EMPLOYEEDOCUMENTTYPE = SY_PERSONDOCUMENTTYPE.PERSONDOCUMENTTYPE
        LEFT JOIN PR_POSITION
            ON PR_EMPLOYEE.POSITION = PR_POSITION.POSITION
        LEFT JOIN AC_COSTCENTER
            ON PR_EMPLOYEE.COSTCENTER = AC_COSTCENTER.COSTCENTER
        LEFT JOIN PR_EMPLOYEETYPE
            ON PR_EMPLOYEE.EMPLOYEETYPE = PR_EMPLOYEETYPE.EMPLOYEETYPE
        LEFT JOIN PR_EMPLOYEECATEGORY
            ON PR_EMPLOYEE.EMPLOYEECATEGORY = PR_EMPLOYEECATEGORY.EMPLOYEECATEGORY
    WHERE PR_EMPLOYEE.COMPANY = @cia
      --AND ISNULL(PR_EMPLOYEE.REGISTER, 'Y') = 'Y'
      AND (@payrolltype = '0' OR PR_EMPLOYEE.PAYROLLTYPE = @payrolltype)
      AND (@person = '0' OR PR_EMPLOYEE.PERSON = @person)
      AND (@docnro = '' OR SY_PERSON_A.DOCUMENTNUMBER LIKE '%' + @docnro + '%')
      AND (
            @nombre = ''
         OR LTRIM(RTRIM(
                ISNULL(SY_PERSON_A.LASTNAME1, '') + ' ' +
                ISNULL(SY_PERSON_A.LASTNAME2, '') + ' ' +
                ISNULL(SY_PERSON_A.NAME1, '') + ' ' +
                ISNULL(SY_PERSON_A.NAME2, '')
            )) LIKE '%' + @nombre + '%'
      )
      AND (@salarybank = '0' OR PR_EMPLOYEE.SalaryBank = @salarybank)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND PR_EMPLOYEE.CEASEDATE IS NOT NULL)
         OR (@cesados = 'N' AND PR_EMPLOYEE.CEASEDATE IS NULL)
      )
      AND (
          @estado = 'T'
          OR (@estado = 'A' AND PR_EMPLOYEE.STATUS = 'N')
          OR (@estado = 'I' AND ISNULL(PR_EMPLOYEE.STATUS, '') <> 'N')
      )
    ORDER BY nombre, codigo;
END
GO
