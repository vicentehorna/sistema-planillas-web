/*
    Unidades con cuenta BCP (SY_ReplicationUnit.bcpAccount) para Pago por Unidad.
    Solo hm_alamo / maestro Unidades.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_unidades_bcp_pago_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        LTRIM(RTRIM(ru.ReplicationUnit)) AS replicationunit,
        LTRIM(RTRIM(ISNULL(ru.name, ru.ReplicationUnit))) AS name,
        LTRIM(RTRIM(ISNULL(ru.bcpAccount, ''))) AS bcpaccount
    FROM SY_ReplicationUnit ru (NOLOCK)
    WHERE NULLIF(LTRIM(RTRIM(ISNULL(ru.bcpAccount, ''))), '') IS NOT NULL
      AND (
            ru.Status IS NULL
         OR LTRIM(RTRIM(ru.Status)) = ''
         OR UPPER(LTRIM(RTRIM(ru.Status))) = 'A'
      )
    ORDER BY name, replicationunit;
END
GO
