--sp_pr_calcular_liquidacion_persona 'BGT', 'LIMABGT 000000000005', 'BGT 000000000011', '20260404', '72789691', 'ADMIN', 3.14

--select * FROM PR_PROCESSTYPE

--select * FROM PR_PAYROLLTYPE

--select PR_Concept.FormulaCode  from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = 'BGT'
--	and PR_FormulaHeader.Proccestype = 'BGT 000000000002' and PR_FormulaHeader.Payrolltype = 'LIMABGT 000000000001')

	--select PR_FormulaHeader.FormulaHeader, PR_Concept.FormulaCode  from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = 'BGT'
	--and PR_FormulaHeader.Proccestype = 'BGT 000000000002' and PR_FormulaHeader.Payrolltype = 'LIMABGT 000000000001')
	
--	select * from PR_Concept where FormulaCode = 'HRS_EXTRAS_PORC_35'
--	select * from PR_FormulaDetail where FormulaHeader = 'LIMABGT 000000000031'


CREATE procedure [dbo].[sp_pr_calcular_liquidacion_persona]
@company varchar(4), @payrolltype varchar(20),  @processtype varchar(20), @period varchar(20), @person varchar(20), @UserID varchar(20), @tc numeric(19,4)
as
begin	
	declare @importe numeric(19,4), @horas25 numeric(19,4), @horas35 numeric(19,4), @horas100 numeric(19,4), @total_5ta numeric(19,4), @total_ingreso numeric(19,4), @total_AFP numeric(19,4)
	declare @tardanza numeric(19,4), @faltas numeric(19,4), @cesado int

	/*INGRESAR EN ASIGNACION DE CONCEPTOS*/


	--execute sp_pr_asignar_conceptos_persona @company, @payrolltype,  @period, @person, @UserID
	
	/*INSERTAR CONCEPTOS DESDE ASIGNACION*/
	
	

	delete from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period

	delete from PR_EmployeePayRoll where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period

	delete from PR_LOG_CALCULO_PLANILLAS where Company = @company and PayRollType = @payrolltype and Person = @person
	and process = @processtype and period = @period

	set @cesado = case when isnull((select convert(varchar(6),CeaseDate,112) from PR_Employee where Person	 = @person and Company = @company),'') = '' then 0 else
						case when isnull((select convert(varchar(6),CeaseDate,112) from PR_Employee where Person	 = @person and Company = @company),'') < left(@period,6) then 1 else 0 end end

	insert into PR_EmployeePayRoll (PayRollType,Person,Company,ProcessType,PRPeriod,CalculationCurrency,ExchangeRate,ReplicationUnit,XLastUser,XLastDate,entrydate,ceasedate,liquidationdate,ceasereason,
	pensiontype,AFP,pensionpercentaje,variablepercentage,insuredpercentage,AFPCard,Position,Costcenter,Costcentername,salarybank,salaryaccounttype,salaryaccount,salarycurrency,collectionform,
	ctsbank,ctscurrency,ctsaccount,pensioninscriptiondate,accountprofile)
	select 
		PayRollType,PR_Employee.Person,PR_Employee.Company, @processtype,@period,'LO', @tc,SY_Person.ReplicationUnit,@UserID,GETDATE(),
		isnull(ReEntryDate,EntryDate), CeaseDate,LiquidationDate,CeaseReason,PensionType,PR_Employee.AFP,PensionPercentage,variablepercentage,insuredpercentage,PR_Employee.AFPCard,
		PR_Employee.Position,PR_Employee.CostCenter, PR_Employee.Costcentername,salarybank,salaryaccounttype,salaryaccount,salarycurrency,CollectionForm,
		ctsbank,ctscurrency,ctsaccount,pensioninscriptiondate,accountprofile
	from PR_Employee INNER JOIN SY_Person ON (PR_Employee.Person = SY_Person.Person) LEFT JOIN PR_AFP on (PR_Employee.AFP = PR_AFP.AFP)
	where PR_Employee.Person = @person and PR_Employee.Company = @company


	insert into PR_EmployeePayRollConcept (Concept, Person, Company, ProcessType, PayRollType,PRPeriod, ConceptValue, FlagIsMonetary, ConceptCurrency, ConceptValueLo,ConceptValueEx,
	ExchangeRate,ReplicationUnit,XLastUser,XLastDate,flagPayment)
	select distinct
		PR_EmployeeConcept.Concept, PR_EmployeeConcept.Person, PR_EmployeeConcept.Company, @processtype,PR_EmployeeConcept.PayRollType,@period,
		case when PR_Concept.FlagIsMonetary = 'Y' then
			case when PR_EmployeeConcept.ConceptCurrency = 'LO' then isnull(PR_EmployeeConcept.ConceptValue,PR_EmployeeConcept.ConceptValueLo) else PR_EmployeeConcept.ConceptValueEx end
		else PR_EmployeeConcept.ConceptValue end,
		PR_Concept.FlagIsMonetary,PR_EmployeeConcept.ConceptCurrency,
		case when PR_Concept.FlagIsMonetary = 'Y' then
			case when PR_EmployeeConcept.ConceptCurrency = 'LO' then isnull(PR_EmployeeConcept.ConceptValue,PR_EmployeeConcept.ConceptValueLo) else PR_EmployeeConcept.ConceptValueEx end
		else PR_EmployeeConcept.ConceptValue end,
		case when PR_Concept.FlagIsMonetary = 'Y' then
			case when PR_EmployeeConcept.ConceptCurrency = 'LO' then ROUND(isnull(PR_EmployeeConcept.ConceptValue,PR_EmployeeConcept.ConceptValueLo)/(@tc*1.0000),2) else PR_EmployeeConcept.ConceptValueEx end
		else NULL end,
		case when PR_Concept.FlagIsMonetary = 'Y' then @tc else NULL end,
		SY_Person.ReplicationUnit,@UserID,GETDATE(),'N'

	from PR_EmployeeConcept inner join SY_Person on (PR_EmployeeConcept.Person = SY_Person.Person) inner join PR_Concept on (PR_EmployeeConcept.Company = PR_Concept.Company
	and PR_EmployeeConcept.Concept = PR_Concept.Concept
	and @cesado = 0)
	where PR_EmployeeConcept.Company = @company and PayRollType = @payrolltype and PR_EmployeeConcept.Person = @person
	and ((FlagFrecuencyType = 'P' and PRPeriodStart <= @period) or (FlagFrecuencyType = 'T' and @period between PRPeriodStart and PRPeriodEnd))
	and exists (select * from PR_Concept C where C.Company = @company and C.Concept = PR_EmployeeConcept.Concept and isnull(C.flaginsertar, 'N') = 'L')
	and (PR_EmployeeConcept.FlagFrecuencyType = 'T' or (PR_EmployeeConcept.FlagFrecuencyType = 'P' and PR_EmployeeConcept.PRPeriodStart = (select MAX(PRPeriodStart) from PR_EmployeeConcept T where 
	T.Company = PR_EmployeeConcept.Company and T.Person = PR_EmployeeConcept.Person AND T.Concept = PR_EmployeeConcept.Concept AND T.PayRollType = PR_EmployeeConcept.PayRollType)))
	
	
	insert into PR_LOG_CALCULO_PLANILLAS (Company, payrolltype,process,period,person, fecha,concepto,importe,tipo,xlastuser,xlastdate)
	select 
		PR_EmployeeConcept.Company, PR_EmployeeConcept.PayRollType,@processtype, @period, PR_EmployeeConcept.Person,getdate(),PR_Concept.FormulaCode,
		case when PR_Concept.FlagIsMonetary = 'Y' then
			case when PR_EmployeeConcept.ConceptCurrency = 'LO' then PR_EmployeeConcept.ConceptValue else PR_EmployeeConcept.ConceptValueEx end
		else PR_EmployeeConcept.ConceptValue end,'I', 'ADMIN', GETDATE()

	from PR_EmployeeConcept inner join SY_Person on (PR_EmployeeConcept.Person = SY_Person.Person) inner join PR_Concept on (PR_EmployeeConcept.Company = PR_Concept.Company
	and PR_EmployeeConcept.Concept = PR_Concept.Concept)
	where PR_EmployeeConcept.Company = @company and PayRollType = @payrolltype and PR_EmployeeConcept.Person = @person
	and ((FlagFrecuencyType = 'P' and PRPeriodStart <= @period) or (FlagFrecuencyType = 'T' and @period between PRPeriodStart and PRPeriodEnd))
	and exists (select * from PR_Concept C where C.Company = @company and C.Concept = PR_EmployeeConcept.Concept and isnull(C.flaginsertar, 'N') = 'L')
	and (PR_EmployeeConcept.FlagFrecuencyType = 'T' or (PR_EmployeeConcept.FlagFrecuencyType = 'P' and PR_EmployeeConcept.PRPeriodStart = (select MAX(PRPeriodStart) from PR_EmployeeConcept T where 
	T.Company = PR_EmployeeConcept.Company and T.Person = PR_EmployeeConcept.Person AND T.Concept = PR_EmployeeConcept.Concept AND T.PayRollType = PR_EmployeeConcept.PayRollType)))
	
	
	select PR_Concept.formulacode, PR_EmployeeConcept.ConceptValue, FlagApplyFormula into #conceptos 
	from PR_EmployeeConcept inner join PR_Concept on (PR_EmployeeConcept.Concept = PR_Concept.Concept and PR_Concept.Company = @company)
	where PR_EmployeeConcept.Company = @company and PayRollType = @payrolltype and PR_EmployeeConcept.Person = @person
	and ((FlagFrecuencyType = 'P' and PRPeriodStart <= @period) or (FlagFrecuencyType = 'T' and @period between PRPeriodStart and PRPeriodEnd))
	and (PR_EmployeeConcept.FlagFrecuencyType = 'T' or (PR_EmployeeConcept.FlagFrecuencyType = 'P' and PR_EmployeeConcept.PRPeriodStart = (select MAX(PRPeriodStart) from PR_EmployeeConcept T where 
	T.Company = PR_EmployeeConcept.Company and T.Person = PR_EmployeeConcept.Person AND T.Concept = PR_EmployeeConcept.Concept AND T.PayRollType = PR_EmployeeConcept.PayRollType)))


	select PR_Concept.FormulaCode into #formulas from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = @company
	and PR_FormulaHeader.Proccestype = @processtype and PR_FormulaHeader.Payrolltype = @payrolltype)

	--DATOS DEL TRABAJADOR
	select isnull(reentrydate,entrydate) as fechaingreso, PR_PensionType.PDT as pension, PR_AFP.PensionPercentage as porc_aporte, variablepercentage as porc_comision_flu, 
	topafp, insuredpercentage as porc_seguro, PR_Employee.CeaseDate as CeaseDate
	into #empleado 
	from PR_Employee inner join PR_PensionType on (PR_Employee.PensionType = PR_PensionType.PensionType and PR_PensionType.Company = @company) 
	left join PR_AFP on (PR_Employee.AFP = PR_AFP.afp and PR_AFP.Company = @company)
	where Person = @person and PR_Employee.company = @company
	
	/*BUCLE FORMULAS AUXILIARES*/
	declare @importe_formula numeric(19,4)
	declare @nemonico varchar(20)

	Declare BucleAuxiliares Cursor For
	select PR_Concept.FormulaCode from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = @company
	and PR_FormulaHeader.Proccestype = @processtype and PR_FormulaHeader.Payrolltype = @payrolltype)
	INNER JOIN PR_GrupoFormula ON (PR_FormulaHeader.GrupoFormula = PR_GrupoFormula.GrupoFormula and PR_GrupoFormula.grouporder = '1')
	order by PR_FormulaHeader.orden
	
	OPEN BucleAuxiliares 
	FETCH NEXT FROM BucleAuxiliares INTO  @nemonico
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		--PRINT @company + ' '  + @period + ' '  +  @payrolltype + ' '  +  @processtype + ' '  +  @person + ' '  +  @nemonico
		--print @nemonico
		execute SP_PR_EjecutarFormula @company, @period, @payrolltype,  @processtype, @person, @nemonico
	
 		
		set @importe_formula = ISNULL((select valor from xx_valor),0)
		set @importe_formula = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = @nemonico),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = @nemonico),0) else @importe_formula end
		execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, @nemonico, @importe_formula, 'F'
		if isnull(@importe_formula,0) > 0 
		begin
			execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, @nemonico, @importe_formula, 'Y'
		end
			
	
	FETCH NEXT FROM BucleAuxiliares	
	INTO  @nemonico
	END 
		
	CLOSE BucleAuxiliares
	DEALLOCATE BucleAuxiliares

	
	--DIAS GRATI TRUNCA

	declare @dia_grati_trunca numeric(19,4), @cantvac int, @idvac int
	declare @ceasedate datetime, @fechaingreso datetime, @fechaini datetime, @flag28 int
	declare @dayx char(2)
	declare @periodo_inicial datetime

	
	set @ceasedate = (select CeaseDate from #empleado)
	set @fechaingreso = (select fechaingreso from #empleado)

	/*Obtenemos el periodo de inicio para las vacaciones truncas*/
	select line, ControlYear,DateBeginProvision into #vacaciones from PR_Vacation where Person = @person and ControlYear between year(@fechaingreso) and year(@ceasedate)
	order by ControlYear desc

	WHILE EXISTS (SELECT 1 FROM #vacaciones)
	BEGIN

		set @idvac = (select top 1 line from #vacaciones)
		set @cantvac = isnull((select count(*) from PR_VacationDetail where Person = @person and Company  = @company and line = (select top 1 line from #vacaciones where line = PR_VacationDetail.line)),0)

		if @cantvac = 0
		begin
			set @periodo_inicial = (select top 1 DateBeginProvision from #vacaciones)
			break
		end

		-- 5. Eliminar la fila procesada para avanzar
		DELETE FROM #vacaciones WHERE line = @idvac
	END



	set @flag28 = case when SUBSTRING(@period,5,2) = '02' and right(CONVERT(varchar(8),@ceasedate,112),4) = '0228' then 1 else 0 end

	set @dayx = case when @flag28 = 1 then '27' else '29' end
	
		
	set @dia_grati_trunca = case when MONTH (@ceasedate) < 7 then
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0101') then  (case when @fechaingreso > convert(datetime,convert(varchar(6),@fechaingreso,112) + '01') then dbo.f_getDias360(convert(date,convert(varchar(6),dateadd(month,1,@fechaingreso),112) + '01') ,convert(date,@ceasedate) ) else dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) ) end ) else dbo.f_getDias360(convert(date, left(@period,4) +'0101') ,convert(date,@ceasedate) ) end 
							else
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0701') then  (case when @fechaingreso > convert(datetime,convert(varchar(6),@fechaingreso,112) + '01') then dbo.f_getDias360(convert(date,convert(varchar(6),dateadd(month,1,@fechaingreso),112) + '01') ,convert(date,@ceasedate) ) else dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) ) end ) else dbo.f_getDias360(convert(date, left(@period,4) +'0701') ,convert(date,@ceasedate) ) end 
							end
	set @dia_grati_trunca = @dia_grati_trunca + 2*@flag28
	set @dia_grati_trunca = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XDIASGRATI'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'XDIASGRATI'),0) else @dia_grati_trunca end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XDIASGRATI', @dia_grati_trunca, 'F'
	if isnull(@dia_grati_trunca,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XDIASGRATI'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XDIASGRATI', @dia_grati_trunca, 'Y'
	end

	--DIAS CTS TRUNCA

	declare @dia_cts_trunca numeric(19,4)

	
		
	set @dia_cts_trunca = case when @ceasedate >= convert(datetime,left(@period,4)+'0501') and  @ceasedate <= convert(datetime,left(@period,4)+'1031') then
								case when convert(date,@fechaingreso) >= convert(date,left(@period,4)+'0501') and convert(date,@fechaingreso) <= convert(date,left(@period,4)+'1031') then dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) ) else dbo.f_getDias360(convert(date, left(@period,4)+'0501') ,convert(date,@ceasedate) ) end 
							else
								case when @ceasedate > convert(datetime,left(@period,4)+'1031') then
									case when  convert(date,@fechaingreso) > convert(datetime,left(@period,4)+'1031') then dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) ) else dbo.f_getDias360(convert(date, left(@period,4) +'1101') ,convert(date,@ceasedate) ) end 
								else
									case when  convert(date,@fechaingreso) > convert(datetime,convert(char(4),convert(int,left(@period,4)) - 1)+'1031') then dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) ) else dbo.f_getDias360(convert(date,convert(char(4),convert(int,left(@period,4)) - 1)+'1101') ,convert(date,@ceasedate) ) end 
								end
							end

	set @dia_cts_trunca = @dia_cts_trunca + 2*@flag28

	set @dia_cts_trunca = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XDIASCTS'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'XDIASCTS'),0) else @dia_cts_trunca end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XDIASCTS', @dia_cts_trunca, 'F'
	if isnull(@dia_cts_trunca,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XDIASCTS'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XDIASCTS', @dia_cts_trunca, 'Y'
	end

	--DIAS VACACIONES TRUNCA

	declare @dia_vaca_trunca numeric(19,4), @dias_vaca_totales numeric(19,4)
	--set @dia_vaca_trunca = dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) )

	set @dias_vaca_totales = dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) )
	set @dias_vaca_totales = @dias_vaca_totales + 2*@flag28
	--print convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4))
	--print DATEDIFF(year, convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)), @ceasedate) 
	set @dia_vaca_trunca = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XDIASVACA'),'N') = 'Y' then 
		isnull((select ConceptValue from #conceptos where FormulaCode = 'XDIASVACA'),0) 
	else  
		dbo.f_getDias360(
			case when DATEDIFF(day,@fechaingreso,@ceasedate) <= 365 then convert(date,@fechaingreso) else 
				case when DATEDIFF(day, convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)), @ceasedate) <= 365 then convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)) else convert(date,convert(varchar(4),year(@ceasedate)) + right(convert(varchar(8),@fechaingreso,112),4)) end end 
		,convert(date,@ceasedate) ) +
		ISNULL((select count(*) from PR_Vacation where person = @person and ConsumedDays = 0 and left(ControlYear,4) = convert(varchar(4),convert(int,left(@period,4)) - 2)),0)*360
	end

	--case when DATEDIFF(year,@fechaingreso,@ceasedate) <= 1 then convert(date,@fechaingreso) else convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)) end
	set @dia_vaca_trunca = @dia_vaca_trunca + 2*@flag28
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XDIASVACA', @dia_vaca_trunca, 'F'
	if isnull(@dia_vaca_trunca,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XDIASVACA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XDIASVACA', @dia_vaca_trunca, 'Y'
	end


	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XDIAVAC', @dias_vaca_totales, 'F'
	if isnull(@dias_vaca_totales,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XDIAVAC'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XDIAVAC', @dias_vaca_totales, 'Y'
	end

	--DIAS VACACIONES NORMALES

	declare @dia_vacaciones_normal numeric(19,4)
	set @dia_vacaciones_normal = dbo.f_getDiasVACNORMAL(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person )

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'DIASVACPAG', @dia_vacaciones_normal, 'F'
	if isnull(@dia_vacaciones_normal,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'DIASVACPAG'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'DIASVACPAG', @dia_vacaciones_normal, 'Y'
	end


	--DIAS FALTA VACACIONES

	declare @dia_faltas_vaca numeric(19,4)

	set @dia_faltas_vaca = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XFALTASVACA'),'N') = 'Y' then 
			isnull((select ConceptValue from #conceptos where FormulaCode = 'XFALTASVACA'),0) else  
		
	dbo.f_getDiasFalta(convert(date,@periodo_inicial)  ,convert(date,@ceasedate), @company, @person ) +  
	dbo.f_getDiasLSG(convert(date,@periodo_inicial)  ,convert(date,@ceasedate), @company, @person ) + 
	dbo.f_getDiasSUSP(convert(date,@periodo_inicial)  ,convert(date,@ceasedate), @company, @person ) end
	
	
	--set @dia_faltas_vaca = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XFALTASVACA'),'N') = 'Y' then 
	--		isnull((select ConceptValue from #conceptos where FormulaCode = 'XFALTASVACA'),0) else  
	--	--dbo.f_getDiasFalta(case when DATEDIFF(DAY,@fechaingreso,@ceasedate) <= 365 then convert(date,@fechaingreso) else convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)) end ,convert(date,@ceasedate), @company, @person ) +  dbo.f_getDiasLSG(case when DATEDIFF(DAY,@fechaingreso,@ceasedate) <= 365 then convert(date,@fechaingreso) else convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)) end  ,convert(date,@ceasedate), @company, @person ) + dbo.f_getDiasSUSP(case when DATEDIFF(DAY,@fechaingreso,@ceasedate) <= 365 then convert(date,@fechaingreso) else convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)) end  ,convert(date,@ceasedate), @company, @person ) end
	
	--dbo.f_getDiasFalta(case when DATEDIFF(day,@fechaingreso,@ceasedate) <= 365 then convert(date,@fechaingreso) else 
	--			case when DATEDIFF(day, convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)), @ceasedate) <= 365 then convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)) else convert(date,convert(varchar(4),year(@ceasedate)) + right(convert(varchar(8),@fechaingreso,112),4)) end end  ,convert(date,@ceasedate), @company, @person ) +  
	--dbo.f_getDiasLSG(case when DATEDIFF(day,@fechaingreso,@ceasedate) <= 365 then convert(date,@fechaingreso) else 
	--			case when DATEDIFF(day, convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)), @ceasedate) <= 365 then convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)) else convert(date,convert(varchar(4),year(@ceasedate)) + right(convert(varchar(8),@fechaingreso,112),4)) end end  ,convert(date,@ceasedate), @company, @person ) + 
	--dbo.f_getDiasSUSP(case when DATEDIFF(day,@fechaingreso,@ceasedate) <= 365 then convert(date,@fechaingreso) else 
	--			case when DATEDIFF(day, convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)), @ceasedate) <= 365 then convert(date,convert(varchar(4),year(@ceasedate)-1) + right(convert(varchar(8),@fechaingreso,112),4)) else convert(date,convert(varchar(4),year(@ceasedate)) + right(convert(varchar(8),@fechaingreso,112),4)) end end  ,convert(date,@ceasedate), @company, @person ) end
	
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XFALTASVACA', @dia_faltas_vaca, 'F'
	if isnull(@dia_faltas_vaca,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XFALTASVACA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XFALTASVACA', @dia_faltas_vaca, 'Y'
	end

	execute sp_pr_registrar_periodo_inicio @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XFALTASVACA', @periodo_inicial, 'Y'


	
	--DIAS FALTAS GRATI

	declare @dias_faltas_grati numeric(19,4)
	

	set @ceasedate = (select CeaseDate from #empleado)
	set @fechaingreso = (select fechaingreso from #empleado)
		
	set @dias_faltas_grati = case when MONTH (@ceasedate) < 7 then
								--case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0101') then dbo.f_getDiasFalta(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasFalta(convert(date, left(@period,4) +'0101') ,convert(date,@ceasedate), @company, @person ) end 
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0101') then dbo.f_getDiasFalta(convert(date,@fechaingreso) ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+@dayx then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) else dbo.f_getDiasFalta(convert(date, left(@period,4) +'0101') ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+@dayx then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) end 
							else
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0701') then dbo.f_getDiasFalta(convert(date,@fechaingreso) ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+'29' then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) else dbo.f_getDiasFalta(convert(date, left(@period,4) +'0701') ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+'29' then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) end 
							end

	set @dias_faltas_grati = case when convert(date,@fechaingreso) > convert(date, left(@period,6) +'01') then 0 else @dias_faltas_grati end

	
	--DIAS LSG GRATI

	declare @dias_lsg_grati numeric(19,4), @dias_susp_grati numeric(19,4)
	

	set @ceasedate = (select CeaseDate from #empleado)
	set @fechaingreso = (select fechaingreso from #empleado)
		
	set @dias_lsg_grati = case when MONTH (@ceasedate) < 7 then
								--case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0101') then dbo.f_getDiasLSG(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasLSG(convert(date, left(@period,4) +'0101') ,convert(date,@ceasedate), @company, @person ) end 
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0101') then dbo.f_getDiasLSG(convert(date,@fechaingreso) ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+@dayx then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) else dbo.f_getDiasLSG(convert(date, left(@period,4) +'0101') ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+@dayx then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) end 
							else
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0701') then dbo.f_getDiasLSG(convert(date,@fechaingreso) ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+'29' then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) else dbo.f_getDiasLSG(convert(date, left(@period,4) +'0701') ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+'29' then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) end 
							end

	set @dias_lsg_grati = case when convert(date,@fechaingreso) > convert(date, left(@period,6) +'01') then 0 else @dias_lsg_grati end

	set @dias_susp_grati = case when MONTH (@ceasedate) < 7 then
								--case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0101') then dbo.f_getDiasSUSP(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasSUSP(convert(date, left(@period,4) +'0101') ,convert(date,@ceasedate), @company, @person ) end 
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0101') then dbo.f_getDiasSUSP(convert(date,@fechaingreso) ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+@dayx then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) else dbo.f_getDiasSUSP(convert(date, left(@period,4) +'0101') ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+@dayx then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) end 
							else
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0701') then dbo.f_getDiasSUSP(convert(date,@fechaingreso) ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+'29' then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) else dbo.f_getDiasSUSP(convert(date, left(@period,4) +'0701') ,case when convert(varchar(8),@ceasedate,112) > left(@period,6)+'29' then convert(date,@ceasedate) else dateadd(day,-1,convert(date,left(@period,6)+'01')) end, @company, @person ) end 
							end

	set @dias_susp_grati = case when convert(date,@fechaingreso) > convert(date, left(@period,6) +'01') then 0 else @dias_susp_grati end

	set @dias_lsg_grati = ISNULL(@dias_lsg_grati,0) + ISNULL(@dias_faltas_grati,0) + isnull(@dias_susp_grati,0)
	
	set @dias_lsg_grati = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XFALTASGRATI'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'XFALTASGRATI'),0) else  @dias_lsg_grati end

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XFALTASGRATI', @dias_lsg_grati, 'F'
	if isnull(@dias_lsg_grati,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XFALTASGRATI'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XFALTASGRATI', @dias_lsg_grati, 'Y'
	end


	--DIAS FALTA CTS

	declare @dias_faltas_CTS numeric(19,4)
		
	set @dias_faltas_CTS = case when @ceasedate >= convert(datetime,left(@period,4)+'0501') and  @ceasedate <= convert(datetime,left(@period,4)+'1031') then
								case when convert(date,@fechaingreso) >= convert(date,left(@period,4)+'0501') and convert(date,@fechaingreso) <= convert(date,left(@period,4)+'1031') then dbo.f_getDiasFalta(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasFalta(convert(date, left(@period,4)+'0501') ,convert(date,@ceasedate), @company, @person ) end 
							else
								case when @ceasedate > convert(datetime,left(@period,4)+'1031') then
									case when  convert(date,@fechaingreso) > convert(datetime,left(@period,4)+'1031') then dbo.f_getDiasFalta(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasFalta(convert(date, left(@period,4) +'1101') ,convert(date,@ceasedate), @company, @person ) end 
								else
									case when  convert(date,@fechaingreso) > convert(datetime,convert(char(4),convert(int,left(@period,4)) - 1)+'1031') then dbo.f_getDiasFalta(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasFalta(convert(date,convert(char(4),convert(int,left(@period,4)) - 1)+'1101') ,convert(date,@ceasedate), @company, @person ) end 
								end
							end


	--DIAS LSG CTS

	declare @dias_lsg_CTS numeric(19,4), @dias_lsg_susp numeric(19,4)
		
	set @dias_lsg_CTS = case when @ceasedate >= convert(datetime,left(@period,4)+'0501') and  @ceasedate <= convert(datetime,left(@period,4)+'1031') then
								case when convert(date,@fechaingreso) >= convert(date,left(@period,4)+'0501') and convert(date,@fechaingreso) <= convert(date,left(@period,4)+'1031') then dbo.f_getDiasLSG(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasLSG(convert(date, left(@period,4)+'0501') ,convert(date,@ceasedate), @company, @person ) end 
							else
								case when @ceasedate > convert(datetime,left(@period,4)+'1031') then
									case when  convert(date,@fechaingreso) > convert(datetime,left(@period,4)+'1031') then dbo.f_getDiasLSG(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasLSG(convert(date, left(@period,4) +'1101') ,convert(date,@ceasedate), @company, @person ) end 
								else
									case when  convert(date,@fechaingreso) > convert(datetime,convert(char(4),convert(int,left(@period,4)) - 1)+'1031') then dbo.f_getDiasLSG(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasLSG(convert(date,convert(char(4),convert(int,left(@period,4)) - 1)+'1101') ,convert(date,@ceasedate), @company, @person ) end 
								end
							end

	set @dias_lsg_susp = case when @ceasedate >= convert(datetime,left(@period,4)+'0501') and  @ceasedate <= convert(datetime,left(@period,4)+'1031') then
								case when convert(date,@fechaingreso) >= convert(date,left(@period,4)+'0501') and convert(date,@fechaingreso) <= convert(date,left(@period,4)+'1031') then dbo.f_getDiasSUSP(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasSUSP(convert(date, left(@period,4)+'0501') ,convert(date,@ceasedate), @company, @person ) end 
							else
								case when @ceasedate > convert(datetime,left(@period,4)+'1031') then
									case when  convert(date,@fechaingreso) > convert(datetime,left(@period,4)+'1031') then dbo.f_getDiasSUSP(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasSUSP(convert(date, left(@period,4) +'1101') ,convert(date,@ceasedate), @company, @person ) end 
								else
									case when  convert(date,@fechaingreso) > convert(datetime,convert(char(4),convert(int,left(@period,4)) - 1)+'1031') then dbo.f_getDiasSUSP(convert(date,@fechaingreso) ,convert(date,@ceasedate), @company, @person ) else dbo.f_getDiasSUSP(convert(date,convert(char(4),convert(int,left(@period,4)) - 1)+'1101') ,convert(date,@ceasedate), @company, @person ) end 
								end
							end

	set @dias_lsg_CTS = ISNULL(@dias_lsg_CTS,0) + isnull(@dias_faltas_CTS,0) + isnull(@dias_lsg_susp,0)
	 

	set @dias_lsg_CTS = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XFALTASCTS'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'XFALTASCTS'),0) else  @dias_lsg_CTS end

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XFALTASCTS', @dias_lsg_CTS, 'F'
	if isnull(@dias_lsg_CTS,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XFALTASCTS'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XFALTASCTS', @dias_lsg_CTS, 'Y'
	end

	

	/*BUCLE FORMULAS INGRESOS*/
	

	Declare BucleIngresos Cursor For
	select PR_Concept.FormulaCode from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = @company
	and PR_FormulaHeader.Proccestype = @processtype and PR_FormulaHeader.Payrolltype = @payrolltype)
	INNER JOIN PR_GrupoFormula ON (PR_FormulaHeader.GrupoFormula = PR_GrupoFormula.GrupoFormula and PR_GrupoFormula.grouporder = '2')
	order by PR_FormulaHeader.orden
	
	OPEN BucleIngresos 
	FETCH NEXT FROM BucleIngresos INTO  @nemonico
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		execute SP_PR_EjecutarFormula @company, @period, @payrolltype,  @processtype, @person, @nemonico
		--print @nemonico
		set @importe_formula = ISNULL((select valor from xx_valor),0)
		set @importe_formula = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = @nemonico),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = @nemonico),0) else @importe_formula end
		execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, @nemonico, @importe_formula, 'F'
		if isnull(@importe_formula,0) > 0 
		begin
			execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, @nemonico, @importe_formula, 'Y'
		end
			
	
	FETCH NEXT FROM BucleIngresos	
	INTO  @nemonico
	END 
		
	CLOSE BucleIngresos
	DEALLOCATE BucleIngresos


	


	

	--DIAS TRABAJADOS REAL
	declare @DIASTRABAJADOS numeric(19,4)
	set @DIASTRABAJADOS = isnull((select ConceptValue from #conceptos where FormulaCode = 'DIASTRABAJADOS'),0)
	--set @DIASTRABAJADOS = isnull((select ConceptValue from #conceptos where FormulaCode = 'DIAS_PAGADOS'),0) - ( isnull((select ConceptValue from #conceptos where FormulaCode = 'DIAS_PATERNIDAD'),0) + isnull((select ConceptValue from #conceptos where FormulaCode = 'DIASLICSINGOCE'),0) + isnull((select ConceptValue from #conceptos where FormulaCode = 'CANT_DIAS_AUSENCIA'),0)  + isnull((select ConceptValue from #conceptos where FormulaCode = 'DIAS_DESCANSO_EMPRES'),0))
	--execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'DIASTRABAJADOS', @DIASTRABAJADOS, 'F'
	--if isnull(@importe,0) > 0 
	--begin
	--	execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'DIASTRABAJADOS', @DIASTRABAJADOS, 'Y'
	--end

	--DIAS TOTALES
	set @importe = isnull((select ConceptValue from #conceptos where FormulaCode = 'DIASTRABAJADOS'),0) - ( isnull((select ConceptValue from #conceptos where FormulaCode = 'DIAS_PATERNIDAD'),0) )
	set @importe = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'DIAS_TRAB_TOTALES'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'DIAS_TRAB_TOTALES'),0) else @importe end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'DIAS_TRAB_TOTALES', @importe, 'F'
	if isnull(@importe,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'DIAS_TRAB_TOTALES'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'DIAS_TRAB_TOTALES', @importe, 'Y'
	end
	
	declare @dias_pagados numeric(19,4)
	set @dias_pagados = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'DIAS_PAGADOS')),0)


	--ASIGNACION FAMILIAR

	declare @asig_familiar numeric(19,4)
	set @asig_familiar = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'ASIG_FAMILIAR')),0)

	--VACACIONES
	declare @vacaciones numeric(19,4)
	set @vacaciones = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'VACACIONES')),0)


	--PROMEDIO HE
	declare @promediohe numeric(19,4), @period_ini varchar(20), @period_fin varchar(20), @promedio_sobre numeric(19,4)

	set @period_ini =   (select PRPeriod from PR_Period where Company = @company and PayRollType = @payrolltype and PeriodOrder = (
						select PeriodOrder from PR_Period where Company = @company and PayRollType = @payrolltype and PRPeriod = @period) - 6) 

	set @period_fin =   (select PRPeriod from PR_Period where Company = @company and PayRollType = @payrolltype and PeriodOrder = (
						select PeriodOrder from PR_Period where Company = @company and PayRollType = @payrolltype and PRPeriod = @period) - 1) 

	
	set @promediohe = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod between @period_ini and @period_fin and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'C_HORASEXTRAS')),0)/6

	--set @promediohe = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'PROMEDIO_HE'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'PROMEDIO_HE'),0) else @promediohe end
	--execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'PROMEDIO_HE', @promediohe, 'F'
	--if isnull(@promediohe,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'PROMEDIO_HE'),0) = 0
	--begin
	--	execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'PROMEDIO_HE', @promediohe, 'Y'
	--end

	
	DECLARE  @subsidio_inaf numeric(19,4)
	

	--SUBSIDIO INAFECTO
	--set @subsidio_inaf = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'SUBSIDIO_INAFECTO'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'SUBSIDIO_INAFECTO'),0) else (isnull((select ConceptValue from #conceptos where FormulaCode = 'REM_BASICA'),0) / 30) * isnull((select ConceptValue from #conceptos where FormulaCode = 'DIAS_DESC_SUBSI_INAF'),0) end
	--execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'SUBSIDIO_INAFECTO', @subsidio_inaf, 'F'
	--if isnull(@subsidio_inaf,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'SUBSIDIO_INAFECTO'),0) = 0
	--begin
	--	execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'SUBSIDIO_INAFECTO', @subsidio_inaf, 'Y'
	--end



	declare @lic_goce numeric(19,4)
	set @lic_goce = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'LICENCIA_GOCE_HABER')),0)

	declare @desc_medico numeric(19,4)
	set @desc_medico = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'DESCANSO_MEDICO')),0)

	declare @lic_pat numeric(19,4)
	set @lic_pat = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'LICENCIA_PATERNIDAD')),0)

	declare @subsidio_afe numeric(19,4)
	set @subsidio_afe = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'SUBSIDIO_AFECTO')),0)
	
	DECLARE @basico_ria NUMERIC(19,4)
	SET @basico_ria = 0
	--GRATIFICACION
	declare @gratificacion numeric(19,4)
	set @gratificacion = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_RIA'),0) > 0 then 
					(isnull(@basico_ria,0) + isnull(@subsidio_inaf,0) + isnull(@subsidio_afe,0) + isnull(@lic_goce,0) + isnull(@lic_pat,0) + isnull(@desc_medico,0) )* 0.16666666667 
				else 
					0
				end
	set @gratificacion = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'GRATIFICACION'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'GRATIFICACION'),0) else @gratificacion end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'GRATIFICACION', @gratificacion, 'F'
	if isnull(@gratificacion,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'GRATIFICACION'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'GRATIFICACION', @gratificacion, 'Y'
	end
				

	--CTS
	--declare @CTS  numeric(19,4)
	--set @CTS = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_RIA'),0) > 0 then 
	--				(isnull(@basico_ria,0) + isnull(@subsidio_inaf,0) + isnull(@subsidio_afe,0) + isnull(@lic_goce,0) + isnull(@lic_pat,0) + isnull(@desc_medico,0) + isnull(@gratificacion,0) )/12 
	--			else 
	--				isnull((select ConceptValue from #conceptos where FormulaCode = 'CTS'),0) 
	--			end
	--set @CTS = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'CTS'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'CTS'),0) else @CTS end
	--execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'CTS', @CTS, 'F'
	--if isnull(@CTS,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'CTS'),0) = 0
	--begin
	--	execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'CTS', @CTS, 'Y'
	--end

	--BONO 9% DE GRATIFICACION
	declare @bono9grati numeric(19,4)
	set @bono9grati = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'LEY_29714_BONIF_GRAT'),0) > 0 then
							isnull((select ConceptValue from #conceptos where FormulaCode = 'LEY_29714_BONIF_GRAT'),0) 
						else
							case when isnull((select ConceptValue from #conceptos where FormulaCode = 'EPS'),0) > 0 or isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_EPS'),0)  > 1 then ISNULL(@gratificacion,0)* 0.0675 else ISNULL(@gratificacion,0)* 0.09 end
						end
	set @bono9grati = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'LEY_29714_BONIF_GRAT'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'LEY_29714_BONIF_GRAT'),0) else @bono9grati end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'LEY_29714_BONIF_GRAT', @bono9grati, 'F'
	if isnull(@bono9grati,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'LEY_29714_BONIF_GRAT'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'LEY_29714_BONIF_GRAT', @bono9grati, 'Y'
	end



	--TOTAL INGRESOS IMPUESTO A LA RENTA
	set @total_5ta = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and 
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and isnull(flagafecto5ta, 'N') = 'Y')),0)

	set @total_5ta = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'TOTAL_AFECT_5TA'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'TOTAL_AFECT_5TA'),0) else @total_5ta end
	if ISNULL((select count(*) from #formulas where FormulaCode = 'TOTAL_AFECT_5TA'),0) = 0 execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'TOTAL_AFECT_5TA', @total_5ta, 'F'
	if isnull(@total_5ta,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'TOTAL_AFECT_5TA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'TOTAL_AFECT_5TA', @total_5ta, 'Y'
	end

	

	--TOTAL INGRESOS
	set @total_ingreso = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept inner join PR_Concept on (PR_EmployeePayRollConcept.Concept = PR_Concept.Concept) 
	inner join PR_ConceptType on (pr_concept.concepttype = PR_ConceptType.ConceptType and PR_ConceptType.ShortName = 'I')
	where PR_EmployeePayRollConcept.Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period ),0)

	set @total_ingreso = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'TOTALINGRESO'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'TOTALINGRESO'),0) else @total_ingreso end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'TOTALINGRESO', @total_ingreso, 'F'
	if isnull(@total_ingreso,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'TOTALINGRESO', @total_ingreso, 'Y'
	end


	--SUB TOTAL AFP REAL
	declare @total_rem_afp_AUX  numeric(19,4)
	set @total_AFP = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept inner join PR_Concept on (PR_EmployeePayRollConcept.Concept = PR_Concept.Concept) 
	inner join PR_ConceptType on (pr_concept.concepttype = PR_ConceptType.ConceptType and PR_ConceptType.ShortName = 'I') 
	where PR_EmployeePayRollConcept.Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and 
	exists (select * from PR_Concept T where T.Concept = PR_EmployeePayRollConcept.Concept and T.Company = @company and isnull(T.flagafectoAFP, 'N') = 'Y')),0)

	set @total_rem_afp_AUX = @total_AFP 

	IF ISNULL((select count(*) from #formulas where FormulaCode = 'TOTAL_AFECTO_AFP'),0) = 0 execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'TOTAL_AFECTO_AFP', @total_rem_afp_AUX, 'F'
	if isnull(@total_rem_afp_AUX,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'TOTAL_AFECTO_AFP'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'TOTAL_AFECTO_AFP', @total_rem_afp_AUX, 'Y'
	end

	/*BUCLE FORMULAS EGRESOS*/
	

	Declare BucleEgresos Cursor For
	select PR_Concept.FormulaCode from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = @company
	and PR_FormulaHeader.Proccestype = @processtype and PR_FormulaHeader.Payrolltype = @payrolltype)
	INNER JOIN PR_GrupoFormula ON (PR_FormulaHeader.GrupoFormula = PR_GrupoFormula.GrupoFormula and PR_GrupoFormula.grouporder = '3')
	order by PR_FormulaHeader.orden
	
	OPEN BucleEgresos 
	FETCH NEXT FROM BucleEgresos INTO  @nemonico
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		execute SP_PR_EjecutarFormula @company, @period, @payrolltype,  @processtype, @person, @nemonico
		--print @nemonico
		set @importe_formula = ISNULL((select valor from xx_valor),0)
		set @importe_formula = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = @nemonico),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = @nemonico),0) else @importe_formula end
		execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, @nemonico, @importe_formula, 'F'
		if isnull(@importe_formula,0) > 0 
		begin
			execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, @nemonico, @importe_formula, 'Y'
		end
			
	
	FETCH NEXT FROM BucleEgresos	
	INTO  @nemonico
	END 
		
	CLOSE BucleEgresos
	DEALLOCATE BucleEgresos

	

	

	


	declare @total_rem_afp numeric(19,4)
	set @total_rem_afp = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'TOTAL_REM_AFP')),0)
	

	--AFP_PRO_APORTES
	declare @afp_pro numeric(19,4), @afp_pri numeric(19,4), @afp_int numeric(19,4), @afp_hor numeric(19,4)

	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_pro = 0
	end
	else
	begin
		set @afp_pro = 0
		if isnull((select pension from #empleado),'') = '23' set @afp_pro = (@total_rem_afp * isnull((select porc_aporte from #empleado),0))/100
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_PROF_APORTE', @afp_pro, 'F'
	if isnull(@afp_pro,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_PROF_APORTE', @afp_pro, 'Y'
	end

	--AFP_PRI_APORTES
	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_pri = 0
	end
	else
	begin
		set @afp_pri = 0
		if isnull((select pension from #empleado),'') = '24' set @afp_pri = (@total_rem_afp * isnull((select porc_aporte from #empleado),0))/100
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_PRI_APORTE', @afp_pri, 'F'
	if isnull(@afp_pri,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_PRI_APORTE', @afp_pri, 'Y'
	end

	--AFP_INT_APORTES
	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_int = 0
	end
	else
	begin
		set @afp_int = 0
		if isnull((select pension from #empleado),'') = '21' set @afp_int = (@total_rem_afp * isnull((select porc_aporte from #empleado),0))/100
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_INT_APORTES', @afp_int, 'F'
	if isnull(@afp_int,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_INT_APORTES', @afp_int, 'Y'
	end

	--AFP_HOR_APORTE
	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_hor = 0
	end
	else
	begin
		set @afp_hor = 0
		if isnull((select pension from #empleado),'') = '25' set @afp_hor = (@total_rem_afp * isnull((select porc_aporte from #empleado),0))/100
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_HOR_APORTE', @afp_hor, 'F'
	if isnull(@afp_hor,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_HOR_APORTE', @afp_hor, 'Y'
	end

	--AFP_FONDO
	declare @afp_fondo numeric(19,4)
	set @afp_fondo = isnull(@afp_pro,0) + isnull(@afp_pri,0) + isnull(@afp_int,0) + isnull(@afp_hor,0)
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_APORTE_PORC_8', @afp_fondo, 'F'
	if isnull(@afp_fondo,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_APORTE_PORC_8', @afp_fondo, 'Y'
	end
	
	--AFP_PRO_COMISION
	declare @afp_pro_com numeric(19,4), @afp_pri_com numeric(19,4), @afp_int_com numeric(19,4), @afp_hor_com numeric(19,4)

	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_pro_com = 0
	end
	else
	begin
		set @afp_pro_com = 0
		if isnull((select pension from #empleado),'') = '23'
		begin
			set @afp_pro_com = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'AFP_FLUJO'),0) = 1 or  isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_COMSIOM_MIXTA'),0) = 1  then (@total_rem_afp * isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'PROFUTURO_MIXTA'),0))/100 else (@total_rem_afp * isnull((select porc_comision_flu from #empleado),0))/100 end 
		end
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_PROF_COMISION', @afp_pro_com, 'F'
	if isnull(@afp_pro_com,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_PROF_COMISION', @afp_pro_com, 'Y'
	end

	--AFP_PRI_COMISION
	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_pri_com = 0
	end
	else
	begin
		set @afp_pri_com = 0
		if isnull((select pension from #empleado),'') = '24'
		begin
			set @afp_pri_com = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'AFP_FLUJO'),0) = 1 or  isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_COMSIOM_MIXTA'),0) = 1  then (@total_rem_afp * isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'PRIMA_MIXTA'),0))/100 else (@total_rem_afp * isnull((select porc_comision_flu from #empleado),0))/100 end 
		end
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_PRI_COMISION', @afp_pri_com, 'F'
	if isnull(@afp_pri_com,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_PRI_COMISION', @afp_pri_com, 'Y'
	end

	--AFP_INT_COMISION
	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_int_com = 0
	end
	else
	begin
		set @afp_int_com = 0
		if isnull((select pension from #empleado),'') = '21'
		begin
			set @afp_int_com = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'AFP_FLUJO'),0) = 1 or  isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_COMSIOM_MIXTA'),0) = 1  then (@total_rem_afp * isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'INTEGRA_MIXTA'),0))/100 else (@total_rem_afp * isnull((select porc_comision_flu from #empleado),0))/100 end 
		end
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_INT_COMISION', @afp_int_com, 'F'
	if isnull(@afp_int_com,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_INT_COMISION', @afp_int_com, 'Y'
	end

	--AFP_HOR_COMISION
	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_hor_com = 0
	end
	else
	begin
		set @afp_hor_com = 0
		if isnull((select pension from #empleado),'') = '25'
		begin
			set @afp_hor_com = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'AFP_FLUJO'),0) = 1 or  isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_COMSIOM_MIXTA'),0) = 1  then (@total_rem_afp * isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'HORIZONTE_MIXTA'),0))/100 else (@total_rem_afp * isnull((select porc_comision_flu from #empleado),0))/100 end 
		end
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_HOR_COMISION', @afp_hor_com, 'F'
	if isnull(@afp_hor_com,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_HOR_COMISION', @afp_hor_com, 'Y'
	end
		
	--AFP_COMISION
	declare @afp_comision numeric(19,4)
	set @afp_comision = isnull(@afp_pro_com,0) + isnull(@afp_pri_com,0) + isnull(@afp_int_com,0) + isnull(@afp_hor_com,0)
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_COMISION_VARIABL', @afp_comision, 'F'
	if isnull(@afp_comision,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_COMISION_VARIABL', @afp_comision, 'Y'
	end

	declare @afp_pro_seg numeric(19,4), @afp_pri_seg numeric(19,4), @afp_int_seg numeric(19,4), @afp_hor_seg numeric(19,4)

	--AFP_PRO_SEGUROS
	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_pro_seg = 0
	end
	else
	begin
		if isnull((select ConceptValue from #conceptos where FormulaCode = 'NO_AFECTO_PRIMA'),0) = 1
		begin
			set @afp_pro_seg = 0
		end
		else
		begin
			set @afp_pro_seg = 0
			if isnull((select pension from #empleado),'') = '23'
			begin
				set @afp_pro_seg = case when isnull(@total_rem_afp,0) > isnull((select topafp from #empleado),0)  then (isnull((select topafp from #empleado),0) * isnull((select porc_seguro from #empleado),0))/100 else (isnull(@total_rem_afp,0) * isnull((select porc_seguro from #empleado),0))/100 end 
			end
		end
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_PROF_SEGUROS', @afp_pro_seg, 'F'
	if isnull(@afp_pro_seg,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_PROF_SEGUROS', @afp_pro_seg, 'Y'
	end

	--AFP_PRI_SEGUROS

	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_pri_seg = 0
	end
	else
	begin
		if isnull((select ConceptValue from #conceptos where FormulaCode = 'NO_AFECTO_PRIMA'),0) = 1
		begin
			set @afp_pri_seg = 0
		end
		else
		begin
			set @afp_pri_seg = 0
			if isnull((select pension from #empleado),'') = '24'
			begin
				set @afp_pri_seg = case when isnull(@total_rem_afp,0) > isnull((select topafp from #empleado),0)  then (isnull((select topafp from #empleado),0) * isnull((select porc_seguro from #empleado),0))/100 else (isnull(@total_rem_afp,0) * isnull((select porc_seguro from #empleado),0))/100 end 
			end
		end
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_PRI_SEGUROS', @afp_pri_seg, 'F'
	if isnull(@afp_pri_seg,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_PRI_SEGUROS', @afp_pri_seg, 'Y'
	end

	--AFP_INT_SEGUROS

	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_int_seg = 0
	end
	else
	begin
		if isnull((select ConceptValue from #conceptos where FormulaCode = 'NO_AFECTO_PRIMA'),0) = 1
		begin
			set @afp_int_seg = 0
		end
		else
		begin
			set @afp_int_seg = 0
			if isnull((select pension from #empleado),'') = '21'
			begin
				set @afp_int_seg = case when isnull(@total_rem_afp,0) > isnull((select topafp from #empleado),0)  then (isnull((select topafp from #empleado),0) * isnull((select porc_seguro from #empleado),0))/100 else (isnull(@total_rem_afp,0) * isnull((select porc_seguro from #empleado),0))/100 end 
			end
		end
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_INT_SEGUROS', @afp_int_seg, 'F'
	if isnull(@afp_int_seg,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_INT_SEGUROS', @afp_int_seg, 'Y'
	end

	--AFP_HOR_SEGUROS

	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @afp_hor_seg = 0
	end
	else
	begin
		if isnull((select ConceptValue from #conceptos where FormulaCode = 'NO_AFECTO_PRIMA'),0) = 1
		begin
			set @afp_hor_seg = 0
		end
		else
		begin
			set @afp_hor_seg = 0
			if isnull((select pension from #empleado),'') = '25'
			begin
				set @afp_hor_seg = case when isnull(@total_rem_afp,0) > isnull((select topafp from #empleado),0)  then (isnull((select topafp from #empleado),0) * isnull((select porc_seguro from #empleado),0))/100 else (isnull(@total_rem_afp,0) * isnull((select porc_seguro from #empleado),0))/100 end 
			end
		end
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_HOR_SEGUROS', @afp_hor_seg, 'F'
	if isnull(@afp_hor_seg,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_HOR_SEGUROS', @afp_hor_seg, 'Y'
	end

	--AFP_COMISION
	declare @afp_seguros numeric(19,4)
	set @afp_seguros = isnull(@afp_pro_seg,0) + isnull(@afp_pri_seg,0) + isnull(@afp_int_seg,0) + isnull(@afp_hor_seg,0)
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_SEGUROS', @afp_seguros, 'F'
	if isnull(@afp_seguros,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_SEGUROS', @afp_seguros, 'Y'
	end

	--AFP_HORIZONTE
	declare @afp_horizonte numeric(19,4)
	set @afp_horizonte = round(isnull(@afp_hor,0),2) + round(isnull(@afp_hor_com,0),2) + round(isnull(@afp_hor_seg,0),2)
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_HORIZONTE', @afp_horizonte, 'F'
	if isnull(@afp_horizonte,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_HORIZONTE', @afp_horizonte, 'Y'
	end

	--AFP_INTEGRA
	declare @afp_integra numeric(19,4)
	set @afp_integra= round(isnull(@afp_int,0),2) + round(isnull(@afp_int_com,0),2) + round(isnull(@afp_int_seg,0),2)
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_INTEGRA', @afp_integra, 'F'
	if isnull(@afp_integra,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_INTEGRA', @afp_integra, 'Y'
	end


	--AFP PRIMA
	declare @afp_prima numeric(19,4)
	set @afp_prima= round(isnull(@afp_pri,0),2) + round(isnull(@afp_pri_com,0),2) + round(isnull(@afp_pri_seg,0),2)
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_PRIMA', @afp_prima, 'F'
	if isnull(@afp_prima,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_PRIMA', @afp_prima, 'Y'
	end

	--AFP PROFUTURO
	declare @afp_profuturo numeric(19,4)
	set @afp_profuturo= round(isnull(@afp_pro,0),2) + round(isnull(@afp_pro_com,0),2) + round(isnull(@afp_pro_seg,0),2) 
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'AFP_PROFUTURO', @afp_profuturo, 'F'
	if isnull(@afp_profuturo,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'AFP_PROFUTURO', @afp_profuturo, 'Y'
	end

	--ONP
	declare @onp numeric(19,4)
	if isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_JUBILADO'),0) = 1
	begin
		set @onp = 0
	end
	else
	begin
		set @onp = 0
		if isnull((select pension from #empleado),'') = '02'
		begin
			set @onp = ((isnull(@total_rem_afp,0) - (isnull(@subsidio_afe,0) + isnull(@subsidio_inaf,0))) * isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'PORC_ONP'),0))/100
		end
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'ONP', @onp, 'F'
	if isnull(@onp,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'ONP'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'ONP', @onp, 'Y'
	end

	
	
	--MESES
	declare @meses numeric(19,4)
	set @meses = case when convert(int, substring(@period,5,2)) in (1,2,3) then 12 else
					case when convert(int, substring(@period,5,2)) = 4 then 9 else
						case when convert(int, substring(@period,5,2)) in (5,6,7) then 8 else
							case when convert(int, substring(@period,5,2)) = 8 then 5 else
								case when convert(int, substring(@period,5,2)) in (1,2,3) then 12 else
									case when convert(int, substring(@period,5,2)) in (9,10,11) then 4 else 1 end end end end end end

	
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'MESES', @meses, 'F'
	if isnull(@meses,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'MESES'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'MESES', @meses, 'Y'
	end
	
	--PROYECCION RENTA
	declare @proy_renta numeric(19,4), @xproyectado numeric(19,4)

	set @xproyectado = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'XPROYECTADO')),0)

	--set @proy_renta = ((isnull((select ConceptValue from #conceptos where FormulaCode = 'REM_BASICA'),0) + CASE WHEN isnull(@asig_familiar,0) = 0 THEN 0 ELSE ((isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'RMV'),0)) * 0.10) END) * (12  - convert(int, substring(@period,5,2))))
	set @proy_renta = ISNULL(@xproyectado,0) * (12  - convert(int, substring(@period,5,2)))
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'PROYECCION_RENTA', @proy_renta, 'F'
	if isnull(@proy_renta,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'PROYECCION_RENTA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'PROYECCION_RENTA', @proy_renta, 'Y'
	end

	--REMUNERACION ACUMULADA
	declare @rem_acumulada numeric(19,4), @period_ant varchar(20),  @liquidacion numeric(19,4) 

	set @liquidacion = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = (select ProcessType from PR_ProcessType where ShortName = 'LIQUIDACION' and Company = PR_EmployeePayRollConcept.Company) 
	and PRPeriod between left(@period,4) + '0101' and @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode in( 'BONIF_EXTRA_ESSALUD', 'GRATI_TRUNCA', 'VAC_TRUNCAS'))),0)

	
	set @period_ant = case when SUBSTRING(@period,5,2) = '01' then left(@period,4) + '0101' else  
	(select PRPeriod from PR_Period where Company = @company and PayRollType = @payrolltype and PeriodOrder = (
	select PeriodOrder from PR_Period where Company = @company and PayRollType = @payrolltype and PRPeriod = @period) - 1) end
	
	set @rem_acumulada = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod between left(@period,4) + '0101' and @period_ant and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'TOTAL_REM_IMP_RENTA')),0)

	set @rem_acumulada = @rem_acumulada + ISNULL(@liquidacion,0)

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'REM_ACUMULADA', @rem_acumulada, 'F'
	if isnull(@rem_acumulada,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'REM_ACUMULADA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'REM_ACUMULADA', @rem_acumulada, 'Y'
	end


	--CANTIDAD MES
	declare @cantidad_mes numeric(19,4)

	set @cantidad_mes = case when convert(varchar(6),isnull((select fechaingreso from #empleado),''),112) >= left(isnull((select ParameterTextValue from PR_Parameter where Company = @company and ShortName = 'PERIODO_INICIO'),''),6) then
							case when DATEPART(DAY,(select fechaingreso from #empleado)) > 1 then 6 - DATEPART(MONTH,(select fechaingreso from #empleado)) else 6 - DATEPART(MONTH,(select fechaingreso from #empleado)) + 1 end
						else
							6
						end
 
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'CANTIDAD_MES', @cantidad_mes, 'F'
	if isnull(@cantidad_mes,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'CANTIDAD_MES'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'CANTIDAD_MES', @cantidad_mes, 'Y'
	end
	
	--PROY_GRATIF_JUL
	declare @proy_grati_julio numeric(19,4), @proy_grati_dic numeric(19,4), @xproyjulio numeric(19,4)

	set @xproyjulio = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'XPROYJULIO')),0)

	if convert(integer, substring(@period,5,2)) < 8
	begin
		set @proy_grati_julio = ISNULL(@xproyjulio,0) +
		case when isnull((select ConceptValue from #conceptos where FormulaCode = 'EPS'),0) > 0 then 
			ISNULL(@xproyjulio,0) * 0.0675 
		else 
			ISNULL(@xproyjulio,0) * 0.09 
		end
		set @proy_grati_julio = (@proy_grati_julio / 6) * isnull(@cantidad_mes,0)
	end
	else
	begin
		set @proy_grati_julio = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
								and PRPeriod between left(@period,4) + '0101' and left(@period,4) + '1111' and
								exists (select * from PR_ProcessType where ProcessType = PR_EmployeePayRollConcept.ProcessType and ShortName = 'GRATIFICACION') and
								exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'TOTALINGRESO')),0)
	end
	set @proy_grati_julio = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_RIA'),0) > 0 then 0 else @proy_grati_julio end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'PROY_GRATI_JULIO', @proy_grati_julio, 'F'
	if isnull(@proy_grati_julio,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'PROY_GRATI_JULIO'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'PROY_GRATI_JULIO', @proy_grati_julio, 'Y'
	end

		
	--PROYECCION GRATI DICIEMBRE
	declare @period_act varchar(20), @xproydiciembre numeric(19,4)

	set @xproydiciembre = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'XPROYDICIEMBRE')),0)

	set @period_act =   
	(select PRPeriod from PR_Period where Company = @company and PayRollType = @payrolltype and PeriodOrder = (
	select PeriodOrder from PR_Period where Company = @company and PayRollType = @payrolltype and left(PRPeriod,6) = (left(isnull((select ParameterTextValue from PR_Parameter where Company = @company and ShortName = 'PERIODO_INICIO'),''),6))) + 6) 

	set @cantidad_mes = case when convert(varchar(6),isnull((select fechaingreso from #empleado),''),112) >= left(@period_act,6) then
							case when DATEPART(DAY,(select fechaingreso from #empleado)) > 1 then 
								12 - DATEPART(MONTH,(select fechaingreso from #empleado)) 
							else 
								12 - DATEPART(MONTH,(select fechaingreso from #empleado)) + 1 
							end
						else
							6
						end



	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'CANTIDAD_MES_DIC', @cantidad_mes, 'F'
	if isnull(@cantidad_mes,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'CANTIDAD_MES_DIC', @cantidad_mes, 'Y'
	end
						

	if convert(integer, substring(@period,5,2)) < 12
	begin
		set @proy_grati_dic = ISNULL(@xproydiciembre,0) +
			case when isnull((select ConceptValue from #conceptos where FormulaCode = 'EPS'),0) > 0 then 
				ISNULL(@xproydiciembre,0) * 0.0675 
			else 
				ISNULL(@xproydiciembre,0) * 0.09 
			end

		set @proy_grati_dic =  case when isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_RIA'),0) > 0 then 0 else @proy_grati_dic end

		set @proy_grati_dic = (@proy_grati_dic / 6) * isnull(@cantidad_mes,0)

	end
	else
	begin
		set @proy_grati_dic = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
								and PRPeriod = @period and
								exists (select * from PR_ProcessType where ProcessType = PR_EmployeePayRollConcept.ProcessType and ShortName = 'GRATIFICACION') and
								exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'TOTALINGRESO')),0)
	end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'PROY_GRATI_DICIEMBRE', @proy_grati_dic, 'F'
	if isnull(@proy_grati_dic,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'PROY_GRATI_DICIEMBRE'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'PROY_GRATI_DICIEMBRE', @proy_grati_dic, 'Y'
	end

	--RENTA NETA
	declare @renta_neta numeric(19,4)
	set @renta_neta = isnull(@proy_renta,0) + isnull((select ConceptValue from #conceptos where FormulaCode = 'REM_ACUM_OTRA_EM'),0) + isnull(@rem_acumulada,0) + isnull(@proy_grati_julio,0) + isnull(@proy_grati_dic,0) + isnull(@total_5ta,0)
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'RENTA_NETA', @renta_neta, 'F'
	if isnull(@renta_neta,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'RENTA_NETA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'RENTA_NETA', @renta_neta, 'Y'
	end

	--DEDUCIBLE
	declare @deducible numeric(19,4)
	set @deducible = isnull(@renta_neta,0) - (isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'UIT'),0) * 7)
	set @deducible = case when isnull(@deducible,0) < 0 then 0 else @deducible end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'TOTAL_AUXILIAR', @deducible, 'F'
	if isnull(@deducible,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'TOTAL_AUXILIAR', @deducible, 'Y'
	end

	--IMPUESTO ANUAL
	declare @impuesto_anual numeric(19,4)

	exec SP_PR_ReporteTotalQuintaPERSONA @company, @period, @payrolltype, @processtype, @person, @impuesto_anual output

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'SUB_IMPUESTO', @impuesto_anual, 'F'
	if isnull(@impuesto_anual,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'SUB_IMPUESTO'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'SUB_IMPUESTO', @impuesto_anual, 'Y'
	end

	--RENTA DE QUINTA ACUMULADA
	declare @5ta_acum numeric(19,4)



	set @period_ant = case when convert(integer, SUBSTRING(@period,5,2)) = 4 then left(@period,4) + '0303' else
						case when convert(integer, SUBSTRING(@period,5,2)) in (5,6,7) then left(@period,4) + '0404' else
							case when convert(integer, SUBSTRING(@period,5,2)) = 8 then left(@period,4) + '0707' else
								case when convert(integer, SUBSTRING(@period,5,2)) in (9,10,11) then left(@period,4) + '0808' else
									case when convert(integer, SUBSTRING(@period,5,2)) = 12 then left(@period,4) + '1111' end end end end  end

	set @5ta_acum = case when convert(integer, SUBSTRING(@period,5,2)) in (1,2,3) then 0 else 
		isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
		and ProcessType = @processtype and PRPeriod between left(@period,4) + '0101' and @period_ant and
		exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'RET_5TA_CATEGORIA')),0) 
	end

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'RET_5TA_ACUMULADA', @5ta_acum, 'F'
	if isnull(@5ta_acum,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'RET_5TA_ACUMULADA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'RET_5TA_ACUMULADA', @5ta_acum, 'Y'
	end
	
	--IMPUESTO DE RENTA ANUAL
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'IMPUESTOANUAL', @impuesto_anual, 'F'
	if isnull(@impuesto_anual,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'IMPUESTOANUAL'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'IMPUESTOANUAL', @impuesto_anual, 'Y'
	end

	--DIFERENCIA ANUAL-RTA ACUMULADA
	declare @diferencia numeric(19,4)

	set @diferencia = isnull(@impuesto_anual,0)  - isnull(@5ta_acum,0)
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'DIFERENCIA', @diferencia, 'F'
	if isnull(@diferencia,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'DIFERENCIA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'DIFERENCIA', @diferencia, 'Y'
	end
	

	--RENTA DE QUINTA MENSUAL
	declare @renta_5ta_mensual numeric(19,4)

	set @renta_5ta_mensual = isnull(@diferencia,0) / @meses
	set @renta_5ta_mensual = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'RET_5TA_CATEGORIA'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'RET_5TA_CATEGORIA'),0) else @renta_5ta_mensual end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'RET_5TA_CATEGORIA', @renta_5ta_mensual, 'F'

	set @renta_5ta_mensual = case when @cesado = 1 then 0 else @renta_5ta_mensual end 

	if isnull(@renta_5ta_mensual,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'RET_5TA_CATEGORIA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'RET_5TA_CATEGORIA', @renta_5ta_mensual, 'Y'
	end

	--RETENCION JUDICIAL
	declare @retencion_judicial numeric(19,4)

	set @retencion_judicial = (isnull((select ConceptValue from #conceptos where FormulaCode = 'REM_BASICA'),0) + isnull(@asig_familiar,0) + isnull(@horas25,0) + isnull(@horas35,0) + isnull(@horas100,0) + isnull(@vacaciones,0) - (isnull(@onp,0) + case when isnull(@renta_5ta_mensual,0) <= 0 then 0 else isnull(@renta_5ta_mensual,0) end + isnull(@afp_profuturo,0) + isnull(@afp_horizonte,0) + isnull(@afp_prima,0) + isnull(@afp_integra,0) )) * isnull((select ConceptValue from #conceptos where FormulaCode = 'PORC_RET_JUD'),0) / 100

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'RET_JUDICIAL', @retencion_judicial, 'F'
	if isnull(@retencion_judicial,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'RET_JUDICIAL'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'RET_JUDICIAL', @retencion_judicial, 'Y'
	end

	--ESSALUD VIDA
	declare @essalud_vida numeric(19,4)
	set @essalud_vida =  case when isnull(@dias_pagados,0) > 0 then isnull((select ConceptValue from #conceptos where FormulaCode = 'ESSALUD_VIDA'),0) else 0 end
	
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'ESSALUD_VIDA', @essalud_vida, 'F'
	if isnull(@essalud_vida,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'ESSALUD_VIDA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'ESSALUD_VIDA', @essalud_vida, 'Y'
	end

	--QUINCENA
	declare @quincena numeric(19,4)
	set @quincena = 0
	set @quincena = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
		and PRPeriod = @period and exists(select * from PR_ProcessType where ProcessType = PR_EmployeePayRollConcept.ProcessType and ShortName = 'QUINCENA') and
		exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'ADELANTO_DE_QUINCENA')),0)

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'QUINCENA', @quincena, 'F'
	if isnull(@quincena,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'QUINCENA'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'QUINCENA', @quincena, 'Y'
	end

	--TOTAL_EGRESOS
	declare @total_egreso numeric(19,4)
	set @total_egreso = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept inner join PR_Concept on (PR_EmployeePayRollConcept.Concept = PR_Concept.Concept) 
	inner join PR_ConceptType on (pr_concept.concepttype = PR_ConceptType.ConceptType and PR_ConceptType.ShortName = 'D')
	where PR_EmployeePayRollConcept.Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period ),0)

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'TOTALEGRESOS', @total_egreso, 'F'
	if isnull(@total_egreso,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'TOTALEGRESOS', @total_egreso, 'Y'
	end

	/*BUCLE FORMULAS APORTES*/
	

	Declare BucleAportes Cursor For
	select PR_Concept.FormulaCode from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = @company
	and PR_FormulaHeader.Proccestype = @processtype and PR_FormulaHeader.Payrolltype = @payrolltype)
	INNER JOIN PR_GrupoFormula ON (PR_FormulaHeader.GrupoFormula = PR_GrupoFormula.GrupoFormula and PR_GrupoFormula.grouporder = '4')
	order by PR_FormulaHeader.orden
	
	OPEN BucleAportes 
	FETCH NEXT FROM BucleAportes INTO  @nemonico
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		execute SP_PR_EjecutarFormula @company, @period, @payrolltype,  @processtype, @person, @nemonico

		set @importe_formula = ISNULL((select valor from xx_valor),0)
		set @importe_formula = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = @nemonico),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = @nemonico),0) else @importe_formula end
		execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, @nemonico, @importe_formula, 'F'
		if isnull(@importe_formula,0) > 0 
		begin
			execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, @nemonico, @importe_formula, 'Y'
		end
			
	
	FETCH NEXT FROM BucleAportes	
	INTO  @nemonico
	END 
		
	CLOSE BucleAportes
	DEALLOCATE BucleAportes

	

	

	--ESSALUD_T
	declare @var_monto numeric(19,4), @essalud_t numeric(19,4), @total_rem_vaca numeric(19,4), @var_montominimo numeric(19,4), @porc_eps numeric(19,4)

	
	--ESSALUD
	declare @essalud numeric(19,4), @total_remu_afp numeric(19,4), @rmv numeric(19,4), @essalud_fdm numeric(9,4), @subsidio_mes numeric(9,4)

	set @total_remu_afp = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
								and PRPeriod = @period and
								exists (select * from PR_ProcessType where ProcessType = PR_EmployeePayRollConcept.ProcessType and ShortName = 'FIN_DE_MES') and
								exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'TOTAL_REM_AFP')),0) +
							isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
								and PRPeriod = @period and
								exists (select * from PR_ProcessType where ProcessType = PR_EmployeePayRollConcept.ProcessType and ShortName = 'LIQUIDACION') and
								exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'TOTAL_REM_AFP')),0)
	--print @total_remu_afp
	set @rmv = isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'RMV'),0)
	
	set @essalud_fdm = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
								and PRPeriod = @period and
								exists (select * from PR_ProcessType where ProcessType = PR_EmployeePayRollConcept.ProcessType and ShortName = 'FIN_DE_MES') and
								exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'ESSALUD')),0) 

	set @subsidio_mes = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
								and PRPeriod = @period and
								exists (select * from PR_ProcessType where ProcessType = PR_EmployeePayRollConcept.ProcessType and ShortName = 'FIN_DE_MES') and
								exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'SUBSIDIO_INAFECTO')),0) 

	--print @essalud_fdm
	set @porc_eps = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'EPS'),0) > 0 or isnull((select ConceptValue from #conceptos where FormulaCode = 'FLAG_EPS'),0) > 0 then 6.75 else 9.0 end
	--print @porc_eps
	set @essalud = case when @subsidio_mes > 0 then
							 (@total_remu_afp - @subsidio_mes) * (@porc_eps/100) - @essalud_fdm
					else
							case when @total_remu_afp > @rmv then @total_remu_afp * (@porc_eps/100) - @essalud_fdm else case when @rmv * (@porc_eps/100) - @essalud_fdm > 0 then @rmv * (@porc_eps/100) - @essalud_fdm else 0 end end
					end 
	
	set @essalud = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'ESSALUD'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'ESSALUD'),0) else  @essalud end

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'ESSALUD', @essalud, 'F'
	if isnull(@essalud,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'ESSALUD'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'ESSALUD', @essalud, 'Y'
	end

	declare @aporte_eps numeric(19,4)
	set @aporte_eps = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'EPS '),0) > 0 then
							isnull(@total_remu_afp,0) * (isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'PORC_EPS'),0)/100.00)
						else
							0
						end
	set @aporte_eps = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'APORTE_EPS'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'APORTE_EPS'),0) else @aporte_eps end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'APORTE_EPS', @aporte_eps, 'F'
	if isnull(@aporte_eps,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'APORTE_EPS'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'APORTE_EPS', @aporte_eps, 'Y'
	end


	declare @porc_essalud numeric(19,4)
	set @porc_essalud = case when isnull((select ConceptValue from #conceptos where FormulaCode = 'EPS '),0) > 0 then
							isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'PORC_SEG_SOCIAL'),0) -  isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'PORC_EPS'),0)
						else
							isnull((select ParameterNumberValue from PR_Parameter where Company = @company and ShortName = 'PORC_SEG_SOCIAL'),0)
						end
	set @porc_essalud = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'PORCENTAJE_ESSALUD'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'PORCENTAJE_ESSALUD'),0) else @porc_essalud end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'PORCENTAJE_ESSALUD', @porc_essalud, 'F'
	if isnull(@porc_essalud,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'PORCENTAJE_ESSALUD'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'PORCENTAJE_ESSALUD', @porc_essalud, 'Y'
	end


	--TOTAL_AFECTO_ESSALUD
	declare @total_afecto_essalud numeric(19,4)
	set @total_afecto_essalud = 0

	set @total_afecto_essalud = (@total_rem_afp + @total_rem_vaca) - (@subsidio_afe + @subsidio_inaf)

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'TOTAL_AFECTO_ESSALUD', @total_afecto_essalud, 'F'
	if isnull(@total_afecto_essalud,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'TOTAL_AFECTO_ESSALUD'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'TOTAL_AFECTO_ESSALUD', @total_afecto_essalud, 'Y'
	end

	--TOTAL_APORTES
	declare @total_aportes numeric(19,4)
	set @total_aportes = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept inner join PR_Concept on (PR_EmployeePayRollConcept.Concept = PR_Concept.Concept) 
	inner join PR_ConceptType on (pr_concept.concepttype = PR_ConceptType.ConceptType and PR_ConceptType.ShortName = 'A')
	where PR_EmployeePayRollConcept.Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period ),0)

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'TOTALPATRONAL', @total_aportes, 'F'
	if isnull(@total_aportes,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'TOTALPATRONAL', @total_aportes, 'Y'
	end

	declare @rem_basica_mes numeric(19,4)
	set @rem_basica_mes = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period and
	exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'REM_BASICA_MES')),0)

	--NETO
	declare @neto numeric(19,4)
	set @neto = @total_ingreso - @total_egreso

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'NETO', @neto, 'F'
	if isnull(@neto,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'NETO', @neto, 'Y'
	end

	declare @liq_total_ing numeric(19,4),@liq_total_egreso numeric(19,4), @liq_total_neto numeric(19,4)

	set @liq_total_ing = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
								and PRPeriod = @period and ProcessType = @processtype and
								exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'TOTALINGRESO')),0)

	set @liq_total_egreso = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
								and PRPeriod = @period and ProcessType = @processtype and
								exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'TOTALEGRESOS')),0)

	set @liq_total_neto = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person
								and PRPeriod = @period and ProcessType = @processtype and
								exists (select * from PR_Concept where Concept = PR_EmployeePayRollConcept.Concept and Company = @company and FormulaCode = 'NETO')),0)

	set @liq_total_ing = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'LIQ_TOTAL_ING'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'LIQ_TOTAL_ING'),0) else  @liq_total_ing end

	set @liq_total_egreso = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'LIQ_TOTAL_EGR'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'LIQ_TOTAL_EGR'),0) else  @liq_total_egreso end

	set @liq_total_neto = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'LIQ_NETO'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'LIQ_NETO'),0) else  @liq_total_neto end
	
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'LIQ_TOTAL_ING', @liq_total_ing, 'F'
	if isnull(@liq_total_ing,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'LIQ_TOTAL_ING'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'LIQ_TOTAL_ING', @liq_total_ing, 'Y'
	end

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'LIQ_TOTAL_EGR', @liq_total_egreso, 'F'
	if isnull(@liq_total_egreso,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'LIQ_TOTAL_EGR'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'LIQ_TOTAL_EGR', @liq_total_egreso, 'Y'
	end

	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'LIQ_NETO', @liq_total_neto, 'F'
	if isnull(@liq_total_neto,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'LIQ_NETO'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'LIQ_NETO', @liq_total_neto, 'Y'
	end


	update PR_EmployeePayRoll set Salary = @rem_basica_mes, SalaryLo = @rem_basica_mes, SalaryEx = round(@rem_basica_mes/@tc,4), WorkingDays = @DIASTRABAJADOS, WorkingHours = @DIASTRABAJADOS * 30,
	TotalIncome = @total_ingreso, TotalIncomeLo = @total_ingreso, TotalIncomeEx = round(@total_ingreso/@tc, 4),
	TotalDebits = @total_egreso, TotalDebitsLo = @total_egreso, TotalDebitsEx = round(@total_egreso/@tc, 4),
	TotalPatronal = @total_aportes, TotalPatronalLo = @total_aportes, TotalPatronalEx = round(@total_aportes/@tc, 4),
	Net = @neto, NetLo = @neto, NetEx = round(@neto/@tc,4)
	where Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period

	if isnull((select sum(AmountLo) from PR_EmployeeLoanAmortization where Company = @company and PRperiod = @period and Person = @person),0) > 0 
	begin
		update PR_EmployeeLoanAmortization set Status = 'A' where Company = @company and PRperiod = @period and Person = @person
	end

	drop table #vacaciones
	
end
GO
