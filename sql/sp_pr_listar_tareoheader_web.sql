/*
    Listado de cabeceras de tareo (PR_TareoHeader) para Registro de Tareos.
    Usado por: POST /api/tareo/registro/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_tareoheader_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20) = NULL,
    @prperiod    VARCHAR(20) = NULL,
    @costcenter  VARCHAR(20) = NULL,
    @busqueda    VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = NULLIF(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), '');
    SET @prperiod = NULLIF(LTRIM(RTRIM(ISNULL(@prperiod, ''))), '');
    SET @costcenter = NULLIF(LTRIM(RTRIM(ISNULL(@costcenter, ''))), '');
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    SELECT
        H.TareoHeader AS tareoheader,
        H.company,
        H.payrolltype,
        LTRIM(RTRIM(ISNULL(PT.Description, ''))) AS payrolltype_name,
        H.prperiod,
        H.costcenter,
        LTRIM(RTRIM(ISNULL(CC.Name, ISNULL(CC.Description, '')))) AS costcenter_name,
        CONVERT(varchar(19), H.registerdate, 120) AS registerdate,
        CONVERT(varchar(19), H.LastProcessDate, 120) AS lastprocessdate,
        LTRIM(RTRIM(ISNULL(H.xlastuser, ''))) AS xlastuser,
        CONVERT(varchar(19), H.xlastdate, 120) AS xlastdate,
        (
            SELECT COUNT(1)
            FROM PR_TareoGeneral G (NOLOCK)
            WHERE G.TareoHeader = H.TareoHeader
        ) AS detalle_count
    FROM PR_TareoHeader H (NOLOCK)
    LEFT JOIN PR_PayRollType PT (NOLOCK)
        ON PT.Company = H.company
       AND PT.PayRollType = H.payrolltype
    LEFT JOIN AC_CostCenter CC (NOLOCK)
        ON CC.Company = H.company
       AND CC.CostCenter = H.costcenter
    WHERE H.company = @company
      AND (@payrolltype IS NULL OR H.payrolltype = @payrolltype)
      AND (@prperiod IS NULL OR H.prperiod = @prperiod)
      AND (@costcenter IS NULL OR H.costcenter = @costcenter)
      AND (
            @busqueda IS NULL
         OR H.TareoHeader LIKE '%' + @busqueda + '%'
         OR H.prperiod LIKE '%' + @busqueda + '%'
         OR ISNULL(CC.Name, '') LIKE '%' + @busqueda + '%'
         OR ISNULL(PT.Description, '') LIKE '%' + @busqueda + '%'
      )
    ORDER BY H.prperiod DESC, ISNULL(CC.Name, ''), H.xlastdate DESC;
END
GO
