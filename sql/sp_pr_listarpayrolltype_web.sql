/*
    Listado de tipos de planilla por compañía (maestro Tipo de Planillas).
    Usado por: POST /api/tipos-planilla/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarpayrolltype_web]
    @company  VARCHAR(4),
    @busqueda VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        pt.PayRollType AS payrolltype,
        LTRIM(RTRIM(ISNULL(pt.ShortName, ''))) AS shortname,
        LTRIM(RTRIM(ISNULL(pt.Description, ''))) AS description,
        ISNULL(pt.DiasVacaciones, 30) AS diasvacaciones,
        pt.XLastUser AS xlastuser,
        pt.XLastDate AS xlastdate
    FROM PR_PayRollType pt (NOLOCK)
    WHERE pt.Company = @company
      AND (
            @busqueda IS NULL
         OR pt.ShortName LIKE '%' + @busqueda + '%'
         OR pt.Description LIKE '%' + @busqueda + '%'
         OR pt.PayRollType LIKE '%' + @busqueda + '%'
      )
    ORDER BY
        pt.Description ASC,
        pt.PayRollType ASC;
END
GO
