/*
    Listado de AFPs por compañía (maestro AFPs — PR_AFP).
    Usado por: POST /api/afps/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarafp_web]
    @company  VARCHAR(4),
    @busqueda VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        a.AFP AS afp,
        LTRIM(RTRIM(ISNULL(a.Description, ''))) AS description,
        LTRIM(RTRIM(ISNULL(a.AFPCode, ''))) AS afpcode,
        LTRIM(RTRIM(ISNULL(a.afpcodenet, ''))) AS afpcodenet,
        a.XLastUser AS xlastuser,
        a.XLastDate AS xlastdate
    FROM PR_AFP a (NOLOCK)
    WHERE a.Company = @company
      AND (
            @busqueda IS NULL
         OR a.Description LIKE '%' + @busqueda + '%'
         OR a.AFPCode LIKE '%' + @busqueda + '%'
         OR a.afpcodenet LIKE '%' + @busqueda + '%'
         OR a.AFP LIKE '%' + @busqueda + '%'
      )
    ORDER BY
        a.Description ASC,
        a.AFP ASC;
END
GO
