/*
    Tablas para carga de archivos XML SUNAT (R01, R04, R5) — validación PLAME.
    Ejecutar una vez en la base destino antes de usar la pantalla Validar PLAME.
*/
IF OBJECT_ID('dbo.PR_PlameSunatCarga', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PR_PlameSunatCarga (
        CargaId         INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        Company         VARCHAR(10) NOT NULL,
        Period          VARCHAR(6) NOT NULL,
        Ruc             VARCHAR(11) NOT NULL,
        EmployerName    NVARCHAR(300) NULL,
        PeriodoSunat    VARCHAR(7) NULL,
        FileR01Name     NVARCHAR(260) NULL,
        FileR04Name     NVARCHAR(260) NULL,
        FileR05Name     NVARCHAR(260) NULL,
        RowsR01         INT NOT NULL DEFAULT 0,
        RowsR04         INT NOT NULL DEFAULT 0,
        RowsR05         INT NOT NULL DEFAULT 0,
        UploadedAt      DATETIME NOT NULL DEFAULT GETDATE(),
        UploadedBy      VARCHAR(50) NULL,
        CONSTRAINT UQ_PR_PlameSunatCarga_CompanyPeriod UNIQUE (Company, Period)
    );
END
GO

IF OBJECT_ID('dbo.PR_PlameSunatFila', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PR_PlameSunatFila (
        FilaId          BIGINT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        CargaId         INT NOT NULL,
        Archivo         CHAR(3) NOT NULL,
        NumFila         INT NOT NULL,
        TipoDoc         VARCHAR(2) NULL,
        DocumentNumber  VARCHAR(20) NULL,
        LastName1       NVARCHAR(100) NULL,
        LastName2       NVARCHAR(100) NULL,
        Names           NVARCHAR(200) NULL,
        Situacion       NVARCHAR(80) NULL,
        MontosJson      NVARCHAR(MAX) NULL,
        CONSTRAINT FK_PR_PlameSunatFila_Carga
            FOREIGN KEY (CargaId) REFERENCES dbo.PR_PlameSunatCarga (CargaId)
            ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_PR_PlameSunatFila_CargaArchivo'
      AND object_id = OBJECT_ID('dbo.PR_PlameSunatFila')
)
BEGIN
    CREATE INDEX IX_PR_PlameSunatFila_CargaArchivo
        ON dbo.PR_PlameSunatFila (CargaId, Archivo);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_PR_PlameSunatFila_Document'
      AND object_id = OBJECT_ID('dbo.PR_PlameSunatFila')
)
BEGIN
    CREATE INDEX IX_PR_PlameSunatFila_Document
        ON dbo.PR_PlameSunatFila (CargaId, DocumentNumber);
END
GO
