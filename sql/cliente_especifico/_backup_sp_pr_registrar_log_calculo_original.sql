/*
    Versión original (idéntica en hm_aci, hm_alamo, hm_atilio, hm_credireport, hm_cristal, hm_divisa,
    hm_elclan, hm_garc, hm_globaltec, hm_lumat, hm_mailbox, hm_maritima, hm_ngservicios, hm_prescription,
    hm_prescription2, hm_quimica, hm_safari, hm_sgp, hm_ultra, hm_ultra2) antes de filtrar importes = 0.
*/
create procedure [dbo].[sp_pr_registrar_log_calculo]
@company varchar(4), @payrolltype varchar(20),  @processtype varchar(20), @period varchar(20), @person varchar(20), @UserID varchar(20), @formulacode varchar(255), @importe numeric(19,4), @tipo char(1)
as
begin	
	
	insert into PR_LOG_CALCULO_PLANILLAS (Company, payrolltype,process,period,person, fecha,concepto,importe,tipo,xlastuser,xlastdate)
	values (@company,@payrolltype,@processtype,@period,@person,getdate(), @formulacode,@importe,@tipo,@UserID,getdate())
	
end
GO
