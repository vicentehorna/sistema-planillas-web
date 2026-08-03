/*
    Listado de trabajadores con cuenta corriente / préstamos.
    Panel izquierdo — Control de Préstamos.
    Usado por: POST /api/prestamos/trabajadores

    Parámetros:
      @company       — obligatorio
      @payrolltype   — '0' = todos
      @busqueda      — nombre / documento / código
      @incluir_ceros — 'Y' incluye saldo pendiente = 0; 'N' solo > 0
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_listar_trabajadores_web]
    @company       VARCHAR(4),
    @payrolltype   VARCHAR(20) = '0',
    @busqueda      VARCHAR(100) = '',
    @incluir_ceros VARCHAR(1) = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    IF RTRIM(ISNULL(@payrolltype, '')) = '' SET @payrolltype = '0';
    SET @busqueda = LTRIM(RTRIM(ISNULL(@busqueda, '')));
    SET @incluir_ceros = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@incluir_ceros, 'N'))), 1));
    IF @incluir_ceros NOT IN ('Y', 'N') SET @incluir_ceros = 'N';

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    SELECT
        ca.Company AS company,
        ca.Person AS person,
        emp.EmployeeCode AS codigo,
        LTRIM(RTRIM(
            ISNULL(p.LastName1, '') + ' ' +
            ISNULL(p.LastName2, '') + ' ' +
            ISNULL(p.Name1, '') + ' ' +
            ISNULL(p.Name2, '')
        )) AS nombre,
        p.DocumentNumber AS documento,
        ca.CurrentAccountCurrency AS moneda,
        ISNULL(ca.TotalLoan, 0) AS totalloan,
        ISNULL(ca.TotalPayed, 0) AS totalpayed,
        ISNULL(ca.TotalPending, 0) AS totalpending,
        ca.XLastDate AS xlastdate,
        emp.Payrolltype AS payrolltype,
        pt.Description AS tipoplanilla
    FROM PR_EmployeeCurrentAccount ca (NOLOCK)
        INNER JOIN PR_Employee emp (NOLOCK)
            ON emp.Person = ca.Person
           AND emp.Company = ca.Company
        INNER JOIN SY_Person p (NOLOCK)
            ON p.Person = emp.Person
        LEFT JOIN PR_PayRollType pt (NOLOCK)
            ON pt.PayRollType = emp.Payrolltype
           AND pt.Company = emp.Company
    WHERE ca.Company = @company
      AND (@payrolltype = '0' OR emp.Payrolltype = @payrolltype)
      AND (
            @incluir_ceros = 'Y'
         OR ISNULL(ca.TotalPending, 0) > 0
      )
      AND (
            @busqueda = ''
         OR p.DocumentNumber LIKE '%' + @busqueda + '%'
         OR emp.EmployeeCode LIKE '%' + @busqueda + '%'
         OR LTRIM(RTRIM(
                ISNULL(p.LastName1, '') + ' ' +
                ISNULL(p.LastName2, '') + ' ' +
                ISNULL(p.Name1, '') + ' ' +
                ISNULL(p.Name2, '')
            )) LIKE '%' + @busqueda + '%'
      )
    ORDER BY nombre ASC, ca.Person ASC;
END
GO
