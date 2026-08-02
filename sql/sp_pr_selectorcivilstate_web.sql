/*
    Selector de estados civiles (SY_CivilState) por compañía.
    Si la compañía no tiene catálogo propio, usa el de BGT.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorcivilstate_web]
    @cia VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    IF @cia = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM SY_CivilState cs (NOLOCK)
        WHERE cs.Company = @cia
    )
    BEGIN
        SELECT
            cs.CivilState AS id,
            LTRIM(RTRIM(ISNULL(cs.Description, ''))) AS text
        FROM SY_CivilState cs (NOLOCK)
        WHERE cs.Company = @cia
        ORDER BY cs.Description ASC, cs.CivilState ASC;
        RETURN;
    END;

    SELECT
        cs.CivilState AS id,
        LTRIM(RTRIM(ISNULL(cs.Description, ''))) AS text
    FROM SY_CivilState cs (NOLOCK)
    WHERE cs.Company = 'BGT'
    ORDER BY cs.Description ASC, cs.CivilState ASC;
END
GO
