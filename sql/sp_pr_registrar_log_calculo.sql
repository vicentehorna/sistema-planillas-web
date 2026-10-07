/*
    Registra un paso del cálculo en PR_LOG_CALCULO_PLANILLAS (reporte Log de Cálculo).
    Llamado por los sp_pr_calcular_*_persona.
    No registra importes = 0 (sí registra negativos).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_registrar_log_calculo]
@company varchar(4), @payrolltype varchar(20),  @processtype varchar(20), @period varchar(20), @person varchar(20), @UserID varchar(20), @formulacode varchar(255), @importe numeric(19,4), @tipo char(1)
as
begin	
	if isnull(@importe,0) = 0 return

	insert into PR_LOG_CALCULO_PLANILLAS (Company, payrolltype,process,period,person, fecha,concepto,importe,tipo,xlastuser,xlastdate)
	values (@company,@payrolltype,@processtype,@period,@person,getdate(), @formulacode,@importe,@tipo,@UserID,getdate())
	
end
GO
