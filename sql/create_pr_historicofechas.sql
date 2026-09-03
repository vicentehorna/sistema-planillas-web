/*
    Tabla auxiliar de histórico de ingresos/ceses por trabajador.
    Solo para visualización en ficha (popup). No interviene en cálculo.

    Ciclo = (Company, Person, FechaInicio); FechaFin NULL = ciclo vigente.
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.PR_HistoricoFechas', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PR_HistoricoFechas (
        Company     VARCHAR(10)  NOT NULL,
        Person      VARCHAR(20)  NOT NULL,
        FechaInicio DATETIME     NOT NULL,
        FechaFin    DATETIME     NULL,
        XLastUser   VARCHAR(20)  NULL,
        XLastDate   DATETIME     NULL,
        CONSTRAINT PK_PR_HistoricoFechas PRIMARY KEY (Company, Person, FechaInicio)
    );

    CREATE INDEX IX_PR_HistoricoFechas_Person
        ON dbo.PR_HistoricoFechas (Company, Person, FechaInicio);
END
GO
