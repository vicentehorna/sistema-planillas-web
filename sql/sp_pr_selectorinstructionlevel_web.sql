/*
    Selector de nivel de instrucción (PR_InstructionLevel) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorinstructionlevel_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(il.instructionlevel)) AS id,
        LTRIM(RTRIM(ISNULL(il.description, il.instructionlevel))) AS text,
        LTRIM(RTRIM(ISNULL(il.pdt, ''))) AS pdt
    FROM pr_instructionlevel il (NOLOCK)
    WHERE il.company = @cia
       OR il.instructionlevel LIKE 'LIMA' + @cia + '%'
    ORDER BY
        CASE WHEN ISNUMERIC(il.pdt) = 1 THEN CAST(il.pdt AS INT) ELSE 999 END,
        text ASC,
        id ASC;
END
GO
