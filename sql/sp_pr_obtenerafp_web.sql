/*
    Detalle de AFP para edición (maestro AFPs — PR_AFP).
    Usado por: POST /api/afps/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerafp_web]
    @company VARCHAR(4),
    @afp     VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @afp = LTRIM(RTRIM(ISNULL(@afp, '')));

    SELECT
        a.AFP AS afp,
        a.Company AS company,
        LTRIM(RTRIM(ISNULL(a.Description, ''))) AS description,
        LTRIM(RTRIM(ISNULL(a.Vendor, ''))) AS vendor,
        a.PensionPercentage AS pensionpercentage,
        a.TopAFP AS topafp,
        a.TopAFPCurrency AS topafpcurrency,
        a.FixedAmount AS fixedamount,
        a.VariablePercentage AS variablepercentage,
        a.InsuredPercentage AS insuredpercentage,
        a.ReplicationUnit AS replicationunit,
        LTRIM(RTRIM(ISNULL(a.AFPCode, ''))) AS afpcode,
        LTRIM(RTRIM(ISNULL(a.pdt, ''))) AS pdt,
        LTRIM(RTRIM(ISNULL(a.afpcodenet, ''))) AS afpcodenet,
        a.XLastUser AS xlastuser,
        a.XLastDate AS xlastdate
    FROM PR_AFP a (NOLOCK)
    WHERE a.Company = @company
      AND a.AFP = @afp;
END
GO
