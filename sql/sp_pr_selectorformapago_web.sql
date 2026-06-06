/*
    Selector de formas de pago (TE_CollectionForm) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorformapago_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        cf.collectionform AS id,
        LTRIM(RTRIM(ISNULL(cf.description, cf.name))) AS text
    FROM te_collectionform cf
    WHERE cf.status = 'A'
      AND cf.company = @cia
    ORDER BY cf.description ASC;
END
GO
