/*
    Trabajadores de la planilla del periodo sin régimen de pensión (ONP/AFP).
    Usado por validaciones del reporte Declaración AFP / AFPnet.

    Sin régimen: PensionType vacío o PR_PensionType.PDT = '99' (sin régimen pensionario).
    Alcance: trabajadores con conceptos de planilla en el periodo (@period YYYYMM).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_trabajadores_sin_regimen_pension_afp_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(20),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 6);
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));

    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';

    SELECT DISTINCT
        LTRIM(RTRIM(E.person)) AS person,
        LTRIM(RTRIM(ISNULL(P.documentnumber, ''))) AS documentnumber,
        LTRIM(RTRIM(
            ISNULL(P.lastname1, '') + ' ' +
            ISNULL(P.lastname2, '') + ' ' +
            ISNULL(P.name1, '') + ' ' +
            ISNULL(P.name2, '')
        )) AS nombre,
        LTRIM(RTRIM(ISNULL(E.pensiontype, ''))) AS pensiontype,
        LTRIM(RTRIM(ISNULL(PT.description, ''))) AS pensiontype_desc,
        LTRIM(RTRIM(ISNULL(PT.pdt, ''))) AS pension_pdt
    FROM PR_Employee E (NOLOCK)
        INNER JOIN SY_Person P (NOLOCK)
            ON P.person = E.person
        LEFT JOIN PR_PensionType PT (NOLOCK)
            ON PT.PensionType = E.PensionType
           AND (
                LTRIM(RTRIM(ISNULL(PT.Company, ''))) = ''
                OR LTRIM(RTRIM(PT.Company)) = E.Company
           )
    WHERE E.Company = @cia
      AND EXISTS (
            SELECT 1
            FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            WHERE EPC.Company = @cia
              AND EPC.Person = E.person
              AND LEFT(EPC.PRPeriod, 6) = @period
              AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
      )
      AND (
            LTRIM(RTRIM(ISNULL(E.PensionType, ''))) = ''
            OR LTRIM(RTRIM(ISNULL(PT.PDT, ''))) = '99'
      )
    ORDER BY nombre, person;
END
GO
