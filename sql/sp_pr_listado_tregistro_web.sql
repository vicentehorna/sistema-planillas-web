/*
    T-REGISTRO — Listado de trabajadores para generación de archivos TXT (datos personales).

    Usado por: POST /api/plame/t-registro/listado

    Parámetros:
      @cia         — compañía
      @fecha_desde — fecha ingreso/reingreso desde (YYYYMMDD o fecha convertible)
      @fecha_hasta — fecha ingreso/reingreso hasta
      @activos     — S = solo activos (PR_Employee.Status = 'N'); otro valor = todos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_tregistro_web]
    @cia         VARCHAR(10),
    @fecha_desde VARCHAR(20),
    @fecha_hasta VARCHAR(20),
    @activos     CHAR(1) = 'S'
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @fecha_desde = LTRIM(RTRIM(ISNULL(@fecha_desde, '')));
    SET @fecha_hasta = LTRIM(RTRIM(ISNULL(@fecha_hasta, '')));
    SET @activos = UPPER(LTRIM(RTRIM(ISNULL(@activos, 'S'))));

    DECLARE @fd CHAR(8);
    DECLARE @fh CHAR(8);

    IF LEN(@fecha_desde) >= 8 AND LEFT(@fecha_desde, 8) NOT LIKE '%[^0-9]%'
        SET @fd = LEFT(@fecha_desde, 8);
    ELSE IF ISDATE(@fecha_desde) = 1
        SET @fd = CONVERT(CHAR(8), CONVERT(DATE, @fecha_desde), 112);

    IF LEN(@fecha_hasta) >= 8 AND LEFT(@fecha_hasta, 8) NOT LIKE '%[^0-9]%'
        SET @fh = LEFT(@fecha_hasta, 8);
    ELSE IF ISDATE(@fecha_hasta) = 1
        SET @fh = CONVERT(CHAR(8), CONVERT(DATE, @fecha_hasta), 112);

    SELECT
        E.Person AS person,
        LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) AS documentnumber,
        LTRIM(RTRIM(
            ISNULL(P.LastName1, '') + ' ' +
            ISNULL(P.LastName2, '') + ' ' +
            ISNULL(P.Name1, '') + ' ' +
            ISNULL(P.Name2, '')
        )) AS name,
        CONVERT(CHAR(8), CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)), 112) AS entry_date,
        'N' AS selection
    FROM PR_Employee E (NOLOCK)
        INNER JOIN SY_Person P (NOLOCK)
            ON P.Person = E.Person
    WHERE E.Company = @cia
      AND (@activos <> 'S' OR E.Status = 'N')
      AND @fd IS NOT NULL
      AND @fh IS NOT NULL
      AND CONVERT(CHAR(8), CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)), 112)
          BETWEEN @fd AND @fh
      AND LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) <> ''
    ORDER BY name, documentnumber;
END
GO
