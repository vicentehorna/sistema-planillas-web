/*
    Selector SCTR Pensión (PR_SCTR con SCTRType = 'P').
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorsctrpension_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(S.SCTR)) AS id,
        LTRIM(RTRIM(ISNULL(S.Description, S.SCTR))) AS text
    FROM PR_SCTR S (NOLOCK)
    WHERE LTRIM(RTRIM(ISNULL(S.SCTRType, ''))) = 'P'
      AND (
            @cia = ''
            OR LTRIM(RTRIM(ISNULL(S.Company, ''))) = ''
            OR LTRIM(RTRIM(S.Company)) = @cia
          )
    ORDER BY text ASC;
END
GO
