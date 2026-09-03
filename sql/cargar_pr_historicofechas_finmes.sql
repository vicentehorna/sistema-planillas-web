/*
    Carga / refresca PR_HistoricoFechas desde PR_EmployeePayRoll (proceso FIN_DE_MES).

    Por Company + Person + CONVERT(DATE, EntryDate):
      FechaInicio = EntryDate del voucher (ya es ISNULL(ReEntryDate, EntryDate) al calcular)
      FechaFin    = MAX(CeaseDate) de ese ciclo (NULL si sigue vigente)

    Idempotente: elimina filas existentes y vuelve a insertar desde FIN_DE_MES.
    Usado inicialmente en hm_ngservicios.
*/
SET NOCOUNT ON;

IF OBJECT_ID(N'dbo.PR_HistoricoFechas', N'U') IS NULL
BEGIN
    RAISERROR('No existe PR_HistoricoFechas. Ejecute primero create_pr_historicofechas.sql', 16, 1);
    RETURN;
END

DECLARE @xuser VARCHAR(20) = 'CARGA_FINMES';
DECLARE @ahora DATETIME = GETDATE();

DELETE FROM dbo.PR_HistoricoFechas;

INSERT INTO dbo.PR_HistoricoFechas (Company, Person, FechaInicio, FechaFin, XLastUser, XLastDate)
SELECT
    ep.Company,
    ep.Person,
    CONVERT(DATETIME, CONVERT(DATE, ep.EntryDate)),
    MAX(CASE WHEN ep.CeaseDate IS NULL THEN NULL ELSE CONVERT(DATETIME, CONVERT(DATE, ep.CeaseDate)) END),
    @xuser,
    @ahora
FROM PR_EmployeePayRoll ep (NOLOCK)
    INNER JOIN PR_ProcessType pt (NOLOCK)
        ON pt.ProcessType = ep.ProcessType
WHERE pt.ShortName = 'FIN_DE_MES'
  AND ep.EntryDate IS NOT NULL
GROUP BY
    ep.Company,
    ep.Person,
    CONVERT(DATE, ep.EntryDate);

DECLARE @n INT = @@ROWCOUNT;

/* Si un ciclo quedó sin Fin pero existe otro posterior, cerrarlo al día previo al siguiente inicio */
UPDATE h
SET
    h.FechaFin = DATEADD(DAY, -1, n.FechaInicio),
    h.XLastUser = @xuser,
    h.XLastDate = @ahora
FROM dbo.PR_HistoricoFechas h
    INNER JOIN dbo.PR_HistoricoFechas n
        ON n.Company = h.Company
       AND n.Person = h.Person
       AND n.FechaInicio = (
            SELECT MIN(x.FechaInicio)
            FROM dbo.PR_HistoricoFechas x
            WHERE x.Company = h.Company
              AND x.Person = h.Person
              AND x.FechaInicio > h.FechaInicio
       )
WHERE h.FechaFin IS NULL;

PRINT CONCAT('PR_HistoricoFechas: ', @n, ' ciclo(s) cargados desde FIN_DE_MES.');

SELECT TOP 20
    Company,
    Person,
    CONVERT(VARCHAR(10), FechaInicio, 103) AS Inicio,
    CONVERT(VARCHAR(10), FechaFin, 103) AS Fin
FROM dbo.PR_HistoricoFechas
ORDER BY Company, Person, FechaInicio;
GO
