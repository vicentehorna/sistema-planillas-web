/*
    Plantilla Apertura CTS (hm_alamo) — trabajadores activos sin cuenta CTS.

    Listado alineado a "Listado de nuevos trabajadores" de Plantilla_Cuenta_CTS.xlsm,
    con Empresa como primera columna.

    Parámetros:
      @companies — códigos Company separados por coma (vacío = todas)
      @cesados   — T=Todos / Y=Sí (CeaseDate no nulo) / N=No (CeaseDate nulo)

    Criterio:
      - PR_Employee.Status = 'N' (activo)
      - CTSAccount vacío / NULL / '0'
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plantilla_apertura_cts_web]
    @companies VARCHAR(MAX) = NULL,
    @cesados   CHAR(1) = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    SET @companies = LTRIM(RTRIM(ISNULL(@companies, '')));
    SET @cesados = UPPER(LEFT(LTRIM(RTRIM(ISNULL(@cesados, 'N'))), 1));
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'N';

    IF OBJECT_ID('tempdb..#cias') IS NOT NULL DROP TABLE #cias;
    CREATE TABLE #cias (Company CHAR(4) NOT NULL PRIMARY KEY);

    IF @companies = ''
    BEGIN
        INSERT INTO #cias (Company)
        SELECT DISTINCT c.Company
        FROM SY_Company c (NOLOCK);
    END
    ELSE
    BEGIN
        DECLARE @lista VARCHAR(MAX) = @companies + ',';
        DECLARE @pos INT;
        DECLARE @item VARCHAR(20);

        WHILE CHARINDEX(',', @lista) > 0
        BEGIN
            SET @pos = CHARINDEX(',', @lista);
            SET @item = LTRIM(RTRIM(LEFT(@lista, @pos - 1)));
            SET @lista = SUBSTRING(@lista, @pos + 1, LEN(@lista));
            IF @item <> '' AND NOT EXISTS (SELECT 1 FROM #cias WHERE Company = LEFT(@item, 4))
                INSERT INTO #cias (Company) VALUES (LEFT(@item, 4));
        END
    END

    SELECT
        LTRIM(RTRIM(ISNULL(NULLIF(c.description_total, ''), c.Description))) AS empresa,
        ROW_NUMBER() OVER (
            ORDER BY
                LTRIM(RTRIM(ISNULL(NULLIF(c.description_total, ''), c.Description))),
                ISNULL(p.LastName1, ''),
                ISNULL(p.LastName2, ''),
                ISNULL(p.Name1, ''),
                ISNULL(p.Name2, ''),
                p.DocumentNumber
        ) AS nro_registro,
        CASE
            WHEN RTRIM(ISNULL(pdt.Description, '')) = 'DNI'
              OR pdt.Description LIKE 'DNI%' THEN 'DNI'
            WHEN pdt.Description LIKE N'%Ext.%'
              OR pdt.Description LIKE N'%Extranjer%'
              OR pdt.Description LIKE 'CPP%'
              OR pdt.Description LIKE '%PTP%' THEN 'CE'
            WHEN pdt.Description LIKE 'Pasaporte%' THEN 'PS'
            ELSE LEFT(LTRIM(RTRIM(ISNULL(pdt.Description, ''))), 20)
        END AS tipo_documento,
        LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) AS num_documento,
        LTRIM(RTRIM(ISNULL(p.LastName1, ''))) AS apellido_paterno,
        LTRIM(RTRIM(ISNULL(p.LastName2, ''))) AS apellido_materno,
        LTRIM(RTRIM(
            LTRIM(RTRIM(ISNULL(p.Name1, '')))
            + CASE
                WHEN LTRIM(RTRIM(ISNULL(p.Name2, ''))) = '' THEN ''
                ELSE ' ' + LTRIM(RTRIM(p.Name2))
              END
        )) AS nombres,
        LTRIM(RTRIM(ISNULL(pp.Description, ISNULL(p.Ocupation, '')))) AS ocupacion,
        'NO' AS obligaciones_otro_pais,
        COALESCE(
            NULLIF(LTRIM(RTRIM(p.SecTelephone)), ''),
            NULLIF(LTRIM(RTRIM(p.Telephone)), ''),
            ''
        ) AS telefono,
        LTRIM(RTRIM(ISNULL(p.EMail, ''))) AS correo,
        CASE
            WHEN UPPER(LTRIM(RTRIM(ISNULL(e.CTSCurrency, 'LO')))) = 'EX' THEN 'Dólares'
            ELSE 'Soles'
        END AS moneda_cuenta,
        LTRIM(RTRIM(ISNULL(d.Name, ''))) AS departamento,
        LTRIM(RTRIM(ISNULL(pr.Name, ''))) AS provincia,
        e.Company AS company,
        e.Person AS person
    FROM PR_Employee e (NOLOCK)
        INNER JOIN #cias xc ON xc.Company = e.Company
        INNER JOIN SY_Person p (NOLOCK) ON p.Person = e.Person
        INNER JOIN SY_Company c (NOLOCK) ON c.Company = e.Company
        LEFT JOIN SY_PersonDocumentType pdt (NOLOCK)
            ON p.EmployeeDocumentType = pdt.PersonDocumentType
        LEFT JOIN PR_Position pp (NOLOCK)
            ON e.Position = pp.Position
           AND e.Company = pp.Company
        LEFT JOIN SY_Department d (NOLOCK)
            ON d.Department = p.Department
        LEFT JOIN SY_Province pr (NOLOCK)
            ON pr.Province = p.Province
           AND pr.Department = p.Department
    WHERE e.Status = 'N'
      AND LTRIM(RTRIM(ISNULL(e.CTSAccount, ''))) IN ('', '0')
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
    ORDER BY
        empresa,
        apellido_paterno,
        apellido_materno,
        nombres,
        num_documento;
END
GO
