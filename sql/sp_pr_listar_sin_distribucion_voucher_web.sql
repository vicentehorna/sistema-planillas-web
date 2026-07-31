/*
    Trabajadores de la compañía sin distribución OT en el periodo.
    Usado por: POST /api/asientos/distribucion-porcentual/sin-distribucion
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_sin_distribucion_voucher_web]
    @company  VARCHAR(4),
    @period   VARCHAR(20),
    @busqueda VARCHAR(255) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        LTRIM(RTRIM(p.Person)) AS dni,
        LTRIM(RTRIM(ISNULL(p.Name, ''))) AS nombre
    FROM PR_Employee e (NOLOCK)
    INNER JOIN SY_Person p (NOLOCK)
        ON p.Person = e.Person
    WHERE e.Company = @company
      /* Activo en este sistema: Status = 'N' (ver sp_pr_listatrabajadores_web) */
      AND LTRIM(RTRIM(ISNULL(e.Status, ''))) = 'N'
      AND (e.CeaseDate IS NULL OR e.CeaseDate >= CAST(GETDATE() AS DATE))
      AND NOT EXISTS (
            SELECT 1
            FROM PR_DistribucionVoucher d (NOLOCK)
            WHERE d.company = @company
              AND d.period = @period
              AND ISNULL(NULLIF(LTRIM(RTRIM(d.tipo)), ''), 'OT') = 'OT'
              AND LTRIM(RTRIM(d.dni)) = LTRIM(RTRIM(p.Person))
      )
      AND (
            @busqueda IS NULL
         OR p.Person LIKE '%' + @busqueda + '%'
         OR p.Name LIKE '%' + @busqueda + '%'
      )
    ORDER BY p.Name, p.Person;
END
GO
