/*
    Detalle de una empresa (SY_Company) para edición en el maestro web.
    Usado por: POST /api/empresas/obtener

    Ubigeo: se resuelve desde SY_Localite (distrito) → provincia → departamento → país.
    Si la empresa no tiene distrito, se muestran provincia/departamento guardados.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerempresa_web]
    @company VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    IF @company = ''
    BEGIN
        RAISERROR('Indique el código de la empresa.', 16, 1);
        RETURN;
    END;

    SELECT
        LTRIM(RTRIM(C.Company)) AS company,
        LTRIM(RTRIM(ISNULL(C.Description, ''))) AS description,
        LTRIM(RTRIM(ISNULL(C.RUC, ''))) AS ruc,
        LTRIM(RTRIM(ISNULL(C.Telephone, ''))) AS telephone,
        LTRIM(RTRIM(ISNULL(C.Address, ''))) AS address,
        LTRIM(RTRIM(ISNULL(C.localite, ''))) AS localite,
        LTRIM(RTRIM(ISNULL(L.Name, ''))) AS distrito,
        LTRIM(RTRIM(ISNULL(P.Name, ''))) AS provincia,
        LTRIM(RTRIM(ISNULL(D.Name, ''))) AS departamento,
        LTRIM(RTRIM(ISNULL(PA.Name, ''))) AS pais,
        LTRIM(RTRIM(ISNULL(L.pdt, ''))) AS ubigeo,
        CASE
            WHEN L.Localite IS NOT NULL THEN
                LTRIM(RTRIM(ISNULL(D.Name, '') + ' / ' + ISNULL(P.Name, '') + ' / ' + ISNULL(L.Name, '')))
            ELSE ''
        END AS ubigeo_texto,
        UPPER(LTRIM(RTRIM(ISNULL(C.Status, 'A')))) AS status,
        LTRIM(RTRIM(ISNULL(C.Representative, ''))) AS representative,
        LTRIM(RTRIM(ISNULL(C.Rep_DocType, ''))) AS rep_doctype,
        LTRIM(RTRIM(ISNULL(DT.Description, ''))) AS rep_doctypedesc,
        LTRIM(RTRIM(ISNULL(C.Rep_DocNumber, ''))) AS rep_docnumber,
        LTRIM(RTRIM(ISNULL(C.Rep_Position, ''))) AS rep_position,
        LTRIM(RTRIM(ISNULL(C.XCreateUser, ''))) AS xcreateuser,
        C.XCreateDate AS xcreatedate,
        LTRIM(RTRIM(ISNULL(C.XLastUser, ''))) AS xlastuser,
        C.XLastDate AS xlastdate
    FROM SY_Company C (NOLOCK)
        OUTER APPLY (
            SELECT TOP 1 l0.Localite, l0.Name, l0.pdt, l0.Province
            FROM SY_Localite l0 (NOLOCK)
            WHERE l0.Localite = C.localite
        ) L
        OUTER APPLY (
            SELECT TOP 1 p0.Name, p0.Department
            FROM SY_Province p0 (NOLOCK)
            WHERE p0.Province = ISNULL(L.Province, C.province)
        ) P
        OUTER APPLY (
            SELECT TOP 1 d0.Name, d0.Country
            FROM SY_Department d0 (NOLOCK)
            WHERE d0.Department = ISNULL(P.Department, C.department)
        ) D
        OUTER APPLY (
            SELECT TOP 1 c0.Name
            FROM SY_Country c0 (NOLOCK)
            WHERE c0.Country = ISNULL(D.Country, C.country)
        ) PA
        OUTER APPLY (
            SELECT TOP 1 dt0.Description
            FROM SY_PersonDocumentType dt0 (NOLOCK)
            WHERE dt0.PersonDocumentType = C.Rep_DocType
        ) DT
    WHERE C.Company = @company;
END
GO
