/*
    Legajo Digital — esquema demo PromPerú (solo hm_lumat2).
    Tablas: PR_LegajoSeccion (catálogo), PR_LegajoDocumento (archivos por trabajador).
    Secciones iniciales: FILIACION, ESTUDIOS, EXPERIENCIA.
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.PR_LegajoSeccion', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PR_LegajoSeccion (
        SeccionCode VARCHAR(20)  NOT NULL,
        Nombre      VARCHAR(100) NOT NULL,
        Orden       INT          NOT NULL CONSTRAINT DF_PR_LegajoSeccion_Orden DEFAULT (0),
        Status      CHAR(1)      NOT NULL CONSTRAINT DF_PR_LegajoSeccion_Status DEFAULT ('A'),
        CONSTRAINT PK_PR_LegajoSeccion PRIMARY KEY (SeccionCode)
    );
END
GO

IF OBJECT_ID(N'dbo.PR_LegajoDocumento', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PR_LegajoDocumento (
        IdDocumento       INT IDENTITY(1,1) NOT NULL,
        Company           VARCHAR(10)  NOT NULL,
        Person            VARCHAR(20)  NOT NULL,
        SeccionCode       VARCHAR(20)  NOT NULL,
        TipoDocumento     VARCHAR(100) NOT NULL,
        NombreArchivo     VARCHAR(255) NOT NULL,
        RutaArchivo       VARCHAR(500) NOT NULL,
        FechaEmision      DATE         NULL,
        Institucion       VARCHAR(200) NULL,
        FechaCarga        DATETIME     NOT NULL CONSTRAINT DF_PR_LegajoDocumento_FechaCarga DEFAULT (GETDATE()),
        Estado            VARCHAR(20)  NOT NULL CONSTRAINT DF_PR_LegajoDocumento_Estado DEFAULT ('VALIDADO'),
        XLastUser         VARCHAR(20)  NULL,
        XLastDate         DATETIME     NULL,
        CONSTRAINT PK_PR_LegajoDocumento PRIMARY KEY (IdDocumento),
        CONSTRAINT FK_PR_LegajoDocumento_Seccion
            FOREIGN KEY (SeccionCode) REFERENCES dbo.PR_LegajoSeccion (SeccionCode)
    );

    CREATE INDEX IX_PR_LegajoDocumento_CiaPerson
        ON dbo.PR_LegajoDocumento (Company, Person, SeccionCode);
END
GO

/* Seed secciones (idempotente) */
MERGE dbo.PR_LegajoSeccion AS t
USING (VALUES
    ('FILIACION',   '01. Filiación y Datos Personales', 1, 'A'),
    ('ESTUDIOS',    '02. Estudios y Capacitaciones',    2, 'A'),
    ('EXPERIENCIA', '03. Experiencia Laboral',          3, 'A')
) AS s (SeccionCode, Nombre, Orden, Status)
ON t.SeccionCode = s.SeccionCode
WHEN MATCHED THEN
    UPDATE SET Nombre = s.Nombre, Orden = s.Orden, Status = s.Status
WHEN NOT MATCHED THEN
    INSERT (SeccionCode, Nombre, Orden, Status)
    VALUES (s.SeccionCode, s.Nombre, s.Orden, s.Status);
GO
