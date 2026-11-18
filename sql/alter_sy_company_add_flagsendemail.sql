/*
    Flag de envío por email de documentos (boletas, CTS, liquidación, certificados, etc.).

    SY_Company.FlagSendEmail: 'Y' = permite Enviar por Email; 'N' = oculta la opción.
    No se expone aún en el maestro web; se gestiona por BD.

    Por defecto: Y. En hm_servigen se deja en N para todas las empresas.
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.SY_Company', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.SY_Company', N'FlagSendEmail') IS NULL
BEGIN
    EXEC(N'ALTER TABLE dbo.SY_Company ADD FlagSendEmail CHAR(1) NULL');
END
GO

IF OBJECT_ID(N'dbo.SY_Company', N'U') IS NOT NULL
   AND COL_LENGTH(N'dbo.SY_Company', N'FlagSendEmail') IS NOT NULL
BEGIN
    UPDATE dbo.SY_Company
    SET FlagSendEmail = 'Y'
    WHERE FlagSendEmail IS NULL
       OR LTRIM(RTRIM(FlagSendEmail)) = '';

    IF EXISTS (
        SELECT 1
        FROM sys.default_constraints dc
        INNER JOIN sys.columns c
            ON c.default_object_id = dc.object_id
        WHERE dc.parent_object_id = OBJECT_ID(N'dbo.SY_Company')
          AND c.name = 'FlagSendEmail'
    )
    BEGIN
        DECLARE @df sysname;
        SELECT @df = dc.name
        FROM sys.default_constraints dc
        INNER JOIN sys.columns c
            ON c.default_object_id = dc.object_id
        WHERE dc.parent_object_id = OBJECT_ID(N'dbo.SY_Company')
          AND c.name = 'FlagSendEmail';

        IF @df IS NOT NULL
            EXEC(N'ALTER TABLE dbo.SY_Company DROP CONSTRAINT [' + @df + N']');
    END

    IF NOT EXISTS (
        SELECT 1
        FROM sys.default_constraints dc
        INNER JOIN sys.columns c
            ON c.default_object_id = dc.object_id
        WHERE dc.parent_object_id = OBJECT_ID(N'dbo.SY_Company')
          AND c.name = 'FlagSendEmail'
    )
    BEGIN
        ALTER TABLE dbo.SY_Company
        ADD CONSTRAINT DF_SY_Company_FlagSendEmail DEFAULT ('Y') FOR FlagSendEmail;
    END
END
GO
