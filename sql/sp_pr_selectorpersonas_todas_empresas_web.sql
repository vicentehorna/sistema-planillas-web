/*
    Selector de trabajadores en TODAS las empresas (activos e inactivos).
    Uso: modal "Buscar todos" en Lista de trabajadores (hm_alamo).

    @filtro: texto (mín. 2 caracteres en API). Busca en documento, nombre y compañía.
    Devuelve una fila por (persona, empresa): documento, nombre, company, planilla, estado.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorpersonas_todas_empresas_web]
    @filtro VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SET @filtro = LTRIM(RTRIM(ISNULL(@filtro, '')));

    IF LEN(@filtro) < 2
    BEGIN
        SELECT TOP (0)
            CAST(N'' AS VARCHAR(30))  AS documentnumber,
            CAST(N'' AS VARCHAR(200)) AS nombre,
            CAST(N'' AS VARCHAR(20))  AS company,
            CAST(N'' AS VARCHAR(200)) AS companynombre,
            CAST(N'' AS VARCHAR(100)) AS planilla,
            CAST(N'' AS VARCHAR(20))  AS person,
            CAST(N'' AS VARCHAR(20))  AS estado;
        RETURN;
    END;

    SELECT TOP (500)
        ISNULL(LTRIM(RTRIM(p.DocumentNumber)), '') AS documentnumber,
        LTRIM(RTRIM(
            CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(p.Name, ''))), '') IS NOT NULL
                    THEN LTRIM(RTRIM(p.Name))
                ELSE
                    ISNULL(p.LastName1, '') + ' ' +
                    ISNULL(p.LastName2, '') + ' ' +
                    ISNULL(p.Name1, '') + ' ' +
                    ISNULL(p.Name2, '')
            END
        )) AS nombre,
        e.Company AS company,
        ISNULL(NULLIF(LTRIM(RTRIM(c.Description)), ''), e.Company) AS companynombre,
        ISNULL(pt.Description, '') AS planilla,
        e.Person AS person,
        CASE
            WHEN e.Status = 'N' THEN 'Activo'
            ELSE 'Inactivo'
        END AS estado
    FROM PR_Employee e (NOLOCK)
    INNER JOIN SY_Person p (NOLOCK)
        ON p.Person = e.Person
    LEFT JOIN SY_Company c (NOLOCK)
        ON c.Company = e.Company
    LEFT JOIN PR_PayRollType pt (NOLOCK)
        ON pt.PayRollType = e.PayRollType
       AND pt.Company = e.Company
    WHERE
           ISNULL(p.DocumentNumber, '') LIKE '%' + @filtro + '%'
        OR ISNULL(p.Name, '') LIKE '%' + @filtro + '%'
        OR ISNULL(p.LastName1, '') LIKE '%' + @filtro + '%'
        OR ISNULL(p.LastName2, '') LIKE '%' + @filtro + '%'
        OR ISNULL(p.Name1, '') LIKE '%' + @filtro + '%'
        OR ISNULL(p.Name2, '') LIKE '%' + @filtro + '%'
        OR            ISNULL(c.Description, '') LIKE '%' + @filtro + '%'
        OR ISNULL(e.Company, '') LIKE '%' + @filtro + '%'
        OR ISNULL(e.EmployeeCode, '') LIKE '%' + @filtro + '%'
    ORDER BY nombre, companynombre, documentnumber, e.Company;
END
GO
