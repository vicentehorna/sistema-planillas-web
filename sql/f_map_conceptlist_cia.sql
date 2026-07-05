/*
    Mapea ConceptList (IDs de PR_Concept separados por |) de @cia_origen a @cia_destino
    usando FormulaCode como clave común entre empresas.
*/
CREATE OR ALTER FUNCTION [dbo].[f_map_conceptlist_cia]
(
    @conceptlist VARCHAR(500),
    @cia_origen  VARCHAR(4),
    @cia_destino VARCHAR(4)
)
RETURNS VARCHAR(500)
AS
BEGIN
    DECLARE @result VARCHAR(500) = '';
    DECLARE @work VARCHAR(500);
    DECLARE @pos INT;
    DECLARE @piece VARCHAR(50);
    DECLARE @fc VARCHAR(50);
    DECLARE @dest_concept VARCHAR(20);

    SET @conceptlist = NULLIF(LTRIM(RTRIM(ISNULL(@conceptlist, ''))), '');
    IF @conceptlist IS NULL
        RETURN NULL;

    SET @work = @conceptlist + '|';

    WHILE LEN(@work) > 0
    BEGIN
        SET @pos = CHARINDEX('|', @work);
        IF @pos = 0
            BREAK;

        SET @piece = LTRIM(RTRIM(LEFT(@work, @pos - 1)));
        SET @work = SUBSTRING(@work, @pos + 1, LEN(@work));

        IF @piece <> ''
        BEGIN
            SET @fc = NULL;
            SET @dest_concept = NULL;

            SELECT @fc = LTRIM(RTRIM(ISNULL(FormulaCode, '')))
            FROM PR_Concept (NOLOCK)
            WHERE Company = @cia_origen
              AND Concept = @piece;

            IF @fc IS NOT NULL AND @fc <> ''
            BEGIN
                SELECT @dest_concept = Concept
                FROM PR_Concept (NOLOCK)
                WHERE Company = @cia_destino
                  AND LTRIM(RTRIM(ISNULL(FormulaCode, ''))) = @fc;

                IF @dest_concept IS NOT NULL AND LTRIM(RTRIM(@dest_concept)) <> ''
                BEGIN
                    IF @result <> ''
                        SET @result = @result + '|';
                    SET @result = @result + @dest_concept;
                END
            END
        END
    END

    RETURN NULLIF(@result, '');
END
GO
