/*
    Validaciones previas al alta manual de trabajador (módulo Trabajadores / Nuevo).

    Result sets:
      1) cabecera: codigo_existe, documento_existe_cia, codigo_distinto_documento, hay_similares
      2) similares (solo si hay): person, name, documentnumber, company

    Usado por: POST /api/trabajadores/validar-alta
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_validar_alta_trabajador_web]
    @cia             VARCHAR(10),
    @person          VARCHAR(20),
    @documentnumber  VARCHAR(15),
    @name1           VARCHAR(40) = NULL,
    @name2           VARCHAR(40) = NULL,
    @lastname1       VARCHAR(40) = NULL,
    @lastname2       VARCHAR(40) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = UPPER(LTRIM(RTRIM(ISNULL(@person, ''))));
    SET @documentnumber = LTRIM(RTRIM(ISNULL(@documentnumber, '')));
    SET @name1 = UPPER(LTRIM(RTRIM(ISNULL(@name1, ''))));
    SET @name2 = UPPER(LTRIM(RTRIM(ISNULL(@name2, ''))));
    SET @lastname1 = UPPER(LTRIM(RTRIM(ISNULL(@lastname1, ''))));
    SET @lastname2 = UPPER(LTRIM(RTRIM(ISNULL(@lastname2, ''))));

    DECLARE @nombre_completo VARCHAR(100);
    DECLARE @codigo_existe BIT = 0;
    DECLARE @documento_existe_cia BIT = 0;
    DECLARE @codigo_distinto_documento BIT = 0;
    DECLARE @hay_similares BIT = 0;
    DECLARE @doc_norm VARCHAR(15) = @documentnumber;

    IF @doc_norm <> '' AND @doc_norm NOT LIKE '%[^0-9]%'
    BEGIN
        WHILE LEN(@doc_norm) > 1 AND LEFT(@doc_norm, 1) = '0'
            SET @doc_norm = SUBSTRING(@doc_norm, 2, 15);
    END;

    SET @nombre_completo = UPPER(LTRIM(RTRIM(
        ISNULL(@lastname1, '') + ' ' +
        ISNULL(@lastname2, '') + ' ' +
        ISNULL(@name1, '') + ' ' +
        ISNULL(@name2, '')
    )));
    WHILE CHARINDEX('  ', @nombre_completo) > 0
        SET @nombre_completo = REPLACE(@nombre_completo, '  ', ' ');
    IF LEN(@nombre_completo) > 100
        SET @nombre_completo = LEFT(@nombre_completo, 100);

    IF @person <> '' AND EXISTS (SELECT 1 FROM SY_Person (NOLOCK) WHERE Person = @person)
        SET @codigo_existe = 1;

    IF @cia <> '' AND @documentnumber <> ''
       AND EXISTS (
            SELECT 1
            FROM PR_Employee e (NOLOCK)
                INNER JOIN SY_Person p (NOLOCK) ON p.Person = e.Person
            WHERE e.Company = @cia
              AND (
                    LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) = @documentnumber
                 OR LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) = @doc_norm
                 OR (
                        ISNUMERIC(p.DocumentNumber) = 1
                    AND ISNUMERIC(@doc_norm) = 1
                    AND CAST(p.DocumentNumber AS BIGINT) = CAST(@doc_norm AS BIGINT)
                 )
              )
       )
        SET @documento_existe_cia = 1;

    IF @person <> '' AND @documentnumber <> ''
       AND UPPER(@person) <> UPPER(@documentnumber)
       AND UPPER(@person) <> UPPER(@doc_norm)
        SET @codigo_distinto_documento = 1;

    CREATE TABLE #similares (
        person          VARCHAR(20) NOT NULL,
        name            VARCHAR(100) NULL,
        documentnumber  VARCHAR(15) NULL,
        company         VARCHAR(10) NULL
    );

    IF @lastname1 <> '' AND @name1 <> ''
    BEGIN
        INSERT INTO #similares (person, name, documentnumber, company)
        SELECT TOP 25
            LTRIM(RTRIM(p.Person)),
            LTRIM(RTRIM(ISNULL(p.Name, ''))),
            LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))),
            LTRIM(RTRIM(ISNULL(p.Company, '')))
        FROM SY_Person p (NOLOCK)
        WHERE (
                UPPER(LTRIM(RTRIM(ISNULL(p.LastName1, '')))) = @lastname1
            AND UPPER(LTRIM(RTRIM(ISNULL(p.Name1, '')))) = @name1
          )
           OR (
                @nombre_completo <> ''
            AND UPPER(LTRIM(RTRIM(ISNULL(p.Name, '')))) = @nombre_completo
           )
        ORDER BY p.Name, p.Person;

        IF EXISTS (SELECT 1 FROM #similares)
            SET @hay_similares = 1;
    END;

    SELECT
        @codigo_existe AS codigo_existe,
        @documento_existe_cia AS documento_existe_cia,
        @codigo_distinto_documento AS codigo_distinto_documento,
        @hay_similares AS hay_similares,
        @nombre_completo AS nombre_completo;

    SELECT
        person,
        name,
        documentnumber,
        company
    FROM #similares
    ORDER BY name, person;
END
GO
