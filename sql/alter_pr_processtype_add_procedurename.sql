/*
    Agrega la columna ProcedureName en PR_ProcessType y asigna el SP de cálculo
    por persona según la descripción del proceso (Procesar planilla → Calcular).

    ProcedureName NULL: proceso sin SP de cálculo individual configurado.
*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'PR_ProcessType'
      AND c.name = 'ProcedureName'
)
BEGIN
    ALTER TABLE dbo.PR_ProcessType
        ADD ProcedureName VARCHAR(50) NULL;
END
GO

UPDATE PR_ProcessType
SET ProcedureName = NULL
WHERE RTRIM(LTRIM(Description)) = 'PRESTAMOS';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_finmes_persona'
WHERE RTRIM(LTRIM(Description)) = 'MENSUAL';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_pagocts_persona'
WHERE RTRIM(LTRIM(Description)) = 'PAGO DE CTS';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_vacaciones_persona'
WHERE RTRIM(LTRIM(Description)) = 'VACACIONES';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_quincena_persona'
WHERE RTRIM(LTRIM(Description)) = 'QUINCENA';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_provcts_persona'
WHERE RTRIM(LTRIM(Description)) = 'PROVISION CTS';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_provvac_persona'
WHERE RTRIM(LTRIM(Description)) = 'PROVISION VACACIONES';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_provgrati_persona'
WHERE RTRIM(LTRIM(Description)) = 'PROVISION GRATIFICACION';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_gratificacion_persona'
WHERE RTRIM(LTRIM(ShortName)) = 'GRATIFICACION'
   OR RTRIM(LTRIM(Description)) = 'GRATIFICACION';
GO

UPDATE PR_ProcessType
SET ProcedureName = NULL
WHERE RTRIM(LTRIM(Description)) = 'UTILIDADES';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_liquidacion_persona'
WHERE RTRIM(LTRIM(Description)) = 'LIQUIDACION';
GO

UPDATE PR_ProcessType
SET ProcedureName = NULL
WHERE RTRIM(LTRIM(Description)) = 'PROMEDIO VACACION';
GO

UPDATE PR_ProcessType
SET ProcedureName = NULL
WHERE RTRIM(LTRIM(Description)) = 'REINTEGRO';
GO
