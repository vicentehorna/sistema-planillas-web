/*
    Motivos de préstamo (PR_LoanReason) por compañía.
    Usado por: GET /api/prestamos/motivos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_motivos_web]
    @company VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    SELECT
        LTRIM(RTRIM(lr.LoanReason)) AS id,
        LTRIM(RTRIM(ISNULL(lr.Description, lr.LoanReason))) AS text
    FROM PR_LoanReason lr (NOLOCK)
    WHERE lr.Company = @company
    ORDER BY lr.Description, lr.LoanReason;
END
GO
