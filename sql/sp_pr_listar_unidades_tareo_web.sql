/*
    Unidades de tareo = centros de costo nivel 1 (AC_CostCenter.CCLevel = 1).
    Usado por: POST /api/tareo/registro/catalogos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_unidades_tareo_web]
    @company VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));

    SELECT
        A.CostCenter AS costcenter,
        LTRIM(RTRIM(ISNULL(A.Abbrev, ''))) AS abbrev,
        LTRIM(RTRIM(ISNULL(A.Name, ''))) AS name,
        LTRIM(RTRIM(ISNULL(A.Description, ''))) AS description
    FROM AC_CostCenter A (NOLOCK)
    WHERE A.Company = @company
      AND ISNULL(A.CCLevel, 0) = 1
      AND ISNULL(A.Status, 'A') = 'A'
    ORDER BY A.Name, A.Abbrev, A.CostCenter;
END
GO
