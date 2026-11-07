/*
    hm_divisa — trabajadores del asiento (planilla/proceso/periodo) sin
    Distribución Porcentual por centro de costo (tipo CC) en ese periodo.

    Usado por: POST /api/asientos/reporte-contable/sin-distribucion
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_sin_distribucion_asiento_cc_web]
    @company     VARCHAR(10),
    @payrolltype VARCHAR(30),
    @processtype VARCHAR(30),
    @period      VARCHAR(20),
    @person      VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @person = NULLIF(LTRIM(RTRIM(ISNULL(@person, ''))), '');

    IF @company = '' OR @payrolltype = '' OR @processtype = '' OR @period = ''
    BEGIN
        RAISERROR('Indique compañía, tipo de planilla, proceso y periodo.', 16, 1);
        RETURN;
    END;

    ;WITH planilla AS (
        SELECT DISTINCT
            LTRIM(RTRIM(ep.Person)) AS person
        FROM PR_EmployeePayRoll ep (NOLOCK)
        WHERE ep.Company = @company
          AND ep.PayRollType = @payrolltype
          AND ep.ProcessType = @processtype
          AND ep.PRPeriod = @period
          AND (@person IS NULL OR LTRIM(RTRIM(ep.Person)) = @person)
    )
    SELECT
        p.person AS dni,
        LTRIM(RTRIM(ISNULL(sp.Name, ''))) AS nombre
    FROM planilla p
    LEFT JOIN SY_Person sp (NOLOCK)
        ON sp.Person = p.person
    WHERE NOT EXISTS (
        SELECT 1
        FROM PR_DistribucionVoucher d (NOLOCK)
        WHERE d.company = @company
          AND d.period = @period
          AND LTRIM(RTRIM(ISNULL(d.tipo, ''))) = 'CC'
          AND LTRIM(RTRIM(d.dni)) = p.person
          AND ISNULL(d.valor, 0) <> 0
    )
    ORDER BY sp.Name, p.person;
END
GO
