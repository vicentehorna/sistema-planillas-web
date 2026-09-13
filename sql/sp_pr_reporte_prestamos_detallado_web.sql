/*
    Reporte de Préstamos - Detallado (una fila por cuota / amortización).
    Usado por: POST /api/reportes/prestamos-detallado

    Filtros:
      @company     — obligatorio
      @payrolltype — '0' = todos
      @nombre      — busca en nombre / documento / código
      @estado      — 'T' todos | 'P' Pendiente | 'A' Amortizado | 'N' Anulado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporte_prestamos_detallado_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20) = '0',
    @nombre      VARCHAR(100) = '',
    @estado      VARCHAR(1) = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    IF RTRIM(ISNULL(@payrolltype, '')) = '' SET @payrolltype = '0';
    SET @nombre = LTRIM(RTRIM(ISNULL(@nombre, '')));
    SET @estado = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@estado, 'T'))), 1));
    IF @estado NOT IN ('T', 'P', 'A', 'N') SET @estado = 'T';

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    SELECT
        LTRIM(RTRIM(ISNULL(NULLIF(emp.EmployeeCode, ''), a.Person))) AS codigo,
        LTRIM(RTRIM(
            ISNULL(p.LastName1, '') + ' ' +
            ISNULL(p.LastName2, '') + ' ' +
            ISNULL(p.Name1, '') + ' ' +
            ISNULL(p.Name2, '')
        )) AS trabajador,
        LTRIM(RTRIM(ISNULL(
            NULLIF(LTRIM(RTRIM(ISNULL(l.Reference, ''))), ''),
            ISNULL(a.comments, '')
        ))) AS observacion,
        CASE
            WHEN LEN(LTRIM(RTRIM(ISNULL(a.PRperiod, '')))) >= 6
                THEN LEFT(LTRIM(RTRIM(a.PRperiod)), 4) + '-' + SUBSTRING(LTRIM(RTRIM(a.PRperiod)), 5, 2)
            ELSE LTRIM(RTRIM(ISNULL(a.PRperiod, '')))
        END AS periodo,
        CASE UPPER(LTRIM(RTRIM(ISNULL(a.flagliquidation, ''))))
            WHEN 'F' THEN 'FIN DE MES'
            WHEN 'G' THEN 'GRATIFICACION'
            WHEN 'L' THEN 'LIQUIDACION'
            WHEN 'Q' THEN 'QUINCENA'
            WHEN 'U' THEN 'UTILIDADES'
            WHEN 'N' THEN ''
            WHEN '' THEN ''
            ELSE LTRIM(RTRIM(a.flagliquidation))
        END AS proceso,
        CONVERT(DECIMAL(18, 2), ISNULL(a.Amount, 0)) AS importe,
        CASE UPPER(LTRIM(RTRIM(ISNULL(a.Status, ''))))
            WHEN 'P' THEN 'Pendiente'
            WHEN 'A' THEN 'Amortizado'
            WHEN 'N' THEN 'Anulado'
            ELSE LTRIM(RTRIM(ISNULL(a.Status, '')))
        END AS estado,
        UPPER(LTRIM(RTRIM(ISNULL(a.Status, '')))) AS estado_codigo,
        a.Person AS person,
        a.Company AS company,
        CONVERT(INT, ISNULL(a.LOANSECUENCE, 0)) AS loansecuence,
        a.Secuence AS secuence,
        LTRIM(RTRIM(ISNULL(a.PRperiod, ''))) AS prperiod,
        emp.Payrolltype AS payrolltype,
        pt.Description AS tipoplanilla
    FROM PR_EmployeeLoanAmortization a (NOLOCK)
        LEFT JOIN PR_EmployeeLoan l (NOLOCK)
            ON l.Company = a.Company
           AND l.Person = a.Person
           AND l.Secuence = CONVERT(INT, ISNULL(a.LOANSECUENCE, 0))
        INNER JOIN PR_Employee emp (NOLOCK)
            ON emp.Company = a.Company
           AND emp.Person = a.Person
        LEFT JOIN SY_Person p (NOLOCK)
            ON p.Company = a.Company
           AND p.Person = a.Person
        LEFT JOIN PR_PayRollType pt (NOLOCK)
            ON pt.Company = emp.Company
           AND pt.PayRollType = emp.Payrolltype
    WHERE a.Company = @company
      AND (@payrolltype = '0' OR emp.Payrolltype = @payrolltype)
      AND (@estado = 'T' OR UPPER(LTRIM(RTRIM(ISNULL(a.Status, '')))) = @estado)
      AND (
            @nombre = ''
         OR LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) LIKE '%' + @nombre + '%'
         OR LTRIM(RTRIM(ISNULL(emp.EmployeeCode, ''))) LIKE '%' + @nombre + '%'
         OR LTRIM(RTRIM(ISNULL(a.Person, ''))) LIKE '%' + @nombre + '%'
         OR LTRIM(RTRIM(
                ISNULL(p.LastName1, '') + ' ' +
                ISNULL(p.LastName2, '') + ' ' +
                ISNULL(p.Name1, '') + ' ' +
                ISNULL(p.Name2, '')
            )) LIKE '%' + @nombre + '%'
      )
    ORDER BY
        trabajador ASC,
        a.Person ASC,
        CONVERT(INT, ISNULL(a.LOANSECUENCE, 0)) ASC,
        LTRIM(RTRIM(ISNULL(a.PRperiod, ''))) ASC,
        a.Secuence ASC;
END
GO
