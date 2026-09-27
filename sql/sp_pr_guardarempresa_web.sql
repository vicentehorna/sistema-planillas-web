/*
    Edición de empresa (SY_Company) desde el maestro web.
    Usado por: POST /api/empresas/guardar

    @localite — distrito (SY_Localite). Con valor, se completan province/department/country.
               Vacío: se limpia solo el distrito y se conservan los demás niveles.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarempresa_web]
    @company        VARCHAR(4),
    @description    VARCHAR(255),
    @ruc            VARCHAR(15)  = NULL,
    @telephone      VARCHAR(15)  = NULL,
    @address        VARCHAR(255) = NULL,
    @localite       VARCHAR(20)  = NULL,
    @status         VARCHAR(1)   = 'A',
    @representative VARCHAR(100) = NULL,
    @rep_doctype    VARCHAR(20)  = NULL,
    @rep_docnumber  VARCHAR(15)  = NULL,
    @rep_position   VARCHAR(100) = NULL,
    @xlastuser      VARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @description = LTRIM(RTRIM(ISNULL(@description, '')));
    SET @ruc = NULLIF(LTRIM(RTRIM(ISNULL(@ruc, ''))), '');
    SET @telephone = NULLIF(LTRIM(RTRIM(ISNULL(@telephone, ''))), '');
    SET @address = NULLIF(LTRIM(RTRIM(ISNULL(@address, ''))), '');
    SET @localite = NULLIF(LTRIM(RTRIM(ISNULL(@localite, ''))), '');
    SET @status = CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(@status, 'A')))) = 'I' THEN 'I' ELSE 'A' END;
    SET @representative = NULLIF(LTRIM(RTRIM(ISNULL(@representative, ''))), '');
    SET @rep_doctype = NULLIF(LTRIM(RTRIM(ISNULL(@rep_doctype, ''))), '');
    SET @rep_docnumber = NULLIF(LTRIM(RTRIM(ISNULL(@rep_docnumber, ''))), '');
    SET @rep_position = NULLIF(LTRIM(RTRIM(ISNULL(@rep_position, ''))), '');
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @company = ''
    BEGIN
        RAISERROR('Indique el código de la empresa.', 16, 1);
        RETURN;
    END;
    IF @description = ''
    BEGIN
        RAISERROR('Indique la razón social de la empresa.', 16, 1);
        RETURN;
    END;
    IF NOT EXISTS (SELECT 1 FROM SY_Company (NOLOCK) WHERE Company = @company)
    BEGIN
        RAISERROR('La empresa no existe.', 16, 1);
        RETURN;
    END;
    IF @ruc IS NOT NULL AND EXISTS (
        SELECT 1 FROM SY_Company (NOLOCK)
        WHERE LTRIM(RTRIM(ISNULL(RUC, ''))) = @ruc
          AND Company <> @company
    )
    BEGIN
        RAISERROR('El RUC ya está registrado en otra empresa.', 16, 1);
        RETURN;
    END;

    DECLARE @province VARCHAR(20), @department VARCHAR(20), @country VARCHAR(20);
    IF @localite IS NOT NULL
    BEGIN
        SELECT TOP 1
            @province = l.Province,
            @department = p.Department,
            @country = d.Country
        FROM SY_Localite l (NOLOCK)
            LEFT JOIN SY_Province p (NOLOCK) ON p.Province = l.Province
            LEFT JOIN SY_Department d (NOLOCK) ON d.Department = p.Department
        WHERE l.Localite = @localite;

        IF @province IS NULL
        BEGIN
            RAISERROR('El distrito seleccionado no existe.', 16, 1);
            RETURN;
        END;
    END;

    UPDATE SY_Company
    SET Description = @description,
        RUC = @ruc,
        Telephone = @telephone,
        Address = @address,
        localite = @localite,
        province = CASE WHEN @localite IS NULL THEN province ELSE @province END,
        department = CASE WHEN @localite IS NULL THEN department ELSE @department END,
        country = CASE WHEN @localite IS NULL THEN country ELSE @country END,
        Status = @status,
        Representative = @representative,
        Rep_DocType = @rep_doctype,
        Rep_DocNumber = @rep_docnumber,
        Rep_Position = @rep_position,
        XLastUser = ISNULL(@xlastuser, XLastUser),
        XLastDate = GETDATE()
    WHERE Company = @company;

    SELECT
        @company AS company,
        'U' AS modo,
        'Empresa actualizada correctamente.' AS mensaje;
END
GO
