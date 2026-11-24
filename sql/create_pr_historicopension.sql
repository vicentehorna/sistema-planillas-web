/*
    Tabla auxiliar de histórico de régimen pensionario por trabajador.
    Solo para visualización en ficha (popup Pensiones). No interviene en cálculo.

    Cada fila = un régimen + fecha de inscripción registrados al cambiar en ficha.
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.PR_HistoricoPension', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.PR_HistoricoPension (
        Company            VARCHAR(10)   NOT NULL,
        Person             VARCHAR(20)   NOT NULL,
        Line               INT           NOT NULL,
        PensionType        VARCHAR(20)   NULL,
        PensionTypeDesc    VARCHAR(120)  NULL,
        FechaInscripcion   DATETIME      NULL,
        XLastUser          VARCHAR(20)   NULL,
        XLastDate          DATETIME      NULL,
        CONSTRAINT PK_PR_HistoricoPension PRIMARY KEY (Company, Person, Line)
    );

    CREATE INDEX IX_PR_HistoricoPension_Person
        ON dbo.PR_HistoricoPension (Company, Person, Line);
END
GO
