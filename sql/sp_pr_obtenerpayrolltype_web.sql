/*
    Detalle de tipo de planilla para edición web.
    Usado por: POST /api/tipos-planilla/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerpayrolltype_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT
        pt.PayRollType AS payrolltype,
        pt.Company AS company,
        LTRIM(RTRIM(ISNULL(pt.ShortName, ''))) AS shortname,
        LTRIM(RTRIM(ISNULL(pt.Description, ''))) AS description,
        LTRIM(RTRIM(ISNULL(pt.Title, ''))) AS title,
        ISNULL(pt.DiasVacaciones, 30) AS diasvacaciones,
        pt.XLastUser AS xlastuser,
        pt.XLastDate AS xlastdate
    FROM PR_PayRollType pt (NOLOCK)
    WHERE pt.Company = @company
      AND pt.PayRollType = @payrolltype;
END
GO
