/*
    hm_elclan: cargos no usados en PR_Employee ni PR_EmployeePayroll -> Status = I.
    Los que sí se usan quedan Activos (A).
*/
SET NOCOUNT ON;

IF COL_LENGTH(N'dbo.PR_Position', N'Status') IS NULL
BEGIN
    RAISERROR('Falta PR_Position.Status. Ejecute primero alter_pr_position_add_status.sql.', 16, 1);
    RETURN;
END

UPDATE p
SET Status = 'A'
FROM dbo.PR_Position p
WHERE UPPER(ISNULL(p.Status, '')) <> 'A'
  AND (
        EXISTS (
            SELECT 1
            FROM dbo.PR_Employee e (NOLOCK)
            WHERE e.Position = p.Position
              AND (e.Company = p.Company OR e.Company IS NULL)
        )
     OR EXISTS (
            SELECT 1
            FROM dbo.PR_EmployeePayroll ep (NOLOCK)
            WHERE ep.Position = p.Position
              AND (ep.Company = p.Company OR ep.Company IS NULL)
        )
  );

UPDATE p
SET Status = 'I'
FROM dbo.PR_Position p
WHERE UPPER(ISNULL(p.Status, 'A')) <> 'I'
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.PR_Employee e (NOLOCK)
        WHERE e.Position = p.Position
          AND (e.Company = p.Company OR e.Company IS NULL)
  )
  AND NOT EXISTS (
        SELECT 1
        FROM dbo.PR_EmployeePayroll ep (NOLOCK)
        WHERE ep.Position = p.Position
          AND (ep.Company = p.Company OR ep.Company IS NULL)
  );

SELECT
    CASE WHEN UPPER(ISNULL(Status, 'A')) = 'I' THEN 'I' ELSE 'A' END AS status,
    COUNT(*) AS cargos
FROM dbo.PR_Position
GROUP BY CASE WHEN UPPER(ISNULL(Status, 'A')) = 'I' THEN 'I' ELSE 'A' END;
GO
