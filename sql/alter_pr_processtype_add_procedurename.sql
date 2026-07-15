/*
    Agrega la columna ProcedureName en PR_ProcessType y asigna el SP de cálculo
    por persona según la descripción del proceso (Procesar planilla → Calcular).

    ProcedureName NULL: proceso sin SP de cálculo individual configurado.
*/
IF OBJECT_ID(N'dbo.PR_ProcessType', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_ProcessType', 'ProcedureName') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_ProcessType ADD ProcedureName VARCHAR(50) NULL');
END
GO

IF OBJECT_ID(N'dbo.PR_ProcessType', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_ProcessType', 'ProcedureName') IS NOT NULL
BEGIN
    UPDATE PR_ProcessType SET ProcedureName = NULL WHERE RTRIM(LTRIM(Description)) = 'PRESTAMOS';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_finmes_persona' WHERE RTRIM(LTRIM(Description)) = 'MENSUAL';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_pagocts_persona' WHERE RTRIM(LTRIM(Description)) = 'PAGO DE CTS';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_vacaciones_persona' WHERE RTRIM(LTRIM(Description)) = 'VACACIONES';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_quincena_persona' WHERE RTRIM(LTRIM(Description)) = 'QUINCENA';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_provcts_persona' WHERE RTRIM(LTRIM(Description)) = 'PROVISION CTS';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_provvac_persona' WHERE RTRIM(LTRIM(Description)) = 'PROVISION VACACIONES';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_provgrati_persona' WHERE RTRIM(LTRIM(Description)) = 'PROVISION GRATIFICACION';
    UPDATE PR_ProcessType
    SET ProcedureName = 'sp_pr_calcular_gratificacion_persona'
    WHERE RTRIM(LTRIM(ShortName)) = 'GRATIFICACION'
       OR RTRIM(LTRIM(Description)) = 'GRATIFICACION';
    UPDATE PR_ProcessType SET ProcedureName = NULL WHERE RTRIM(LTRIM(Description)) = 'UTILIDADES';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_liquidacion_persona' WHERE RTRIM(LTRIM(Description)) = 'LIQUIDACION';
    UPDATE PR_ProcessType SET ProcedureName = NULL WHERE RTRIM(LTRIM(Description)) = 'PROMEDIO VACACION';
    UPDATE PR_ProcessType SET ProcedureName = NULL WHERE RTRIM(LTRIM(Description)) = 'REINTEGRO';
END
GO
