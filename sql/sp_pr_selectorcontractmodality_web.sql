/*
    Selector de modalidad de contrato (HR_ContractModality) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorcontractmodality_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(m.ContractModality)) AS id,
        LTRIM(RTRIM(ISNULL(m.Description, m.ContractModality))) AS text
    FROM HR_ContractModality m (NOLOCK)
    WHERE m.Company = @cia
    ORDER BY text ASC, id ASC;
END
GO
