--sp_pr_calcular_liquidacion_persona 'BGT', 'LIMABGT 000000000001', 'BGT 000000000011', '20241111', '45177754', 'ADMIN', 3.14

--select * FROM PR_PROCESSTYPE

--select * FROM PR_PAYROLLTYPE

--select PR_Concept.FormulaCode  from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = 'BGT'
--	and PR_FormulaHeader.Proccestype = 'BGT 000000000002' and PR_FormulaHeader.Payrolltype = 'LIMABGT 000000000001')

	--select PR_FormulaHeader.FormulaHeader, PR_Concept.FormulaCode  from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = 'BGT'
	--and PR_FormulaHeader.Proccestype = 'BGT 000000000002' and PR_FormulaHeader.Payrolltype = 'LIMABGT 000000000001')
	
--	select * from PR_Concept where FormulaCode = 'HRS_EXTRAS_PORC_35'
--	select * from PR_FormulaDetail where FormulaHeader = 'LIMABGT 000000000031'

CREATE procedure [dbo].[sp_pr_calcular_provvac_persona]
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


	--insert into PR_EmployeePayRollConcept (Concept, Person, Company, ProcessType, PayRollType,PRPeriod, ConceptValue, FlagIsMonetary, ConceptCurrency, ConceptValueLo,ConceptValueEx,
	--ExchangeRate,ReplicationUnit,XLastUser,XLastDate,flagPayment)
	--select distinct
	--	PR_EmployeeConcept.Concept, PR_EmployeeConcept.Person, PR_EmployeeConcept.Company, @processtype,PR_EmployeeConcept.PayRollType,@period,
	--	case when PR_Concept.FlagIsMonetary = 'Y' then
	--		case when PR_EmployeeConcept.ConceptCurrency = 'LO' then isnull(PR_EmployeeConcept.ConceptValue,PR_EmployeeConcept.ConceptValueLo) else PR_EmployeeConcept.ConceptValueEx end
	--	else PR_EmployeeConcept.ConceptValue end,
	--	PR_Concept.FlagIsMonetary,PR_EmployeeConcept.ConceptCurrency,
	--	case when PR_Concept.FlagIsMonetary = 'Y' then
	--		case when PR_EmployeeConcept.ConceptCurrency = 'LO' then isnull(PR_EmployeeConcept.ConceptValue,PR_EmployeeConcept.ConceptValueLo) else PR_EmployeeConcept.ConceptValueEx end
	--	else PR_EmployeeConcept.ConceptValue end,
	--	case when PR_Concept.FlagIsMonetary = 'Y' then
	--		case when PR_EmployeeConcept.ConceptCurrency = 'LO' then ROUND(isnull(PR_EmployeeConcept.ConceptValue,PR_EmployeeConcept.ConceptValueLo)/(@tc*1.0000),2) else PR_EmployeeConcept.ConceptValueEx end
	--	else NULL end,
	--	case when PR_Concept.FlagIsMonetary = 'Y' then @tc else NULL end,
	--	SY_Person.ReplicationUnit,@UserID,GETDATE(),'N'

	--from PR_EmployeeConcept inner join SY_Person on (PR_EmployeeConcept.Person = SY_Person.Person) inner join PR_Concept on (PR_EmployeeConcept.Company = PR_Concept.Company
	--and PR_EmployeeConcept.Concept = PR_Concept.Concept
	--and @cesado = 0)
	--where PR_EmployeeConcept.Company = @company and PayRollType = @payrolltype and PR_EmployeeConcept.Person = @person
	--and ((FlagFrecuencyType = 'P' and PRPeriodStart <= @period) or (FlagFrecuencyType = 'T' and @period between PRPeriodStart and PRPeriodEnd))
	--and exists (select * from PR_Concept C where C.Company = @company and C.Concept = PR_EmployeeConcept.Concept and isnull(C.flaginsertar, 'N') = 'L')
	--and (PR_EmployeeConcept.FlagFrecuencyType = 'T' or (PR_EmployeeConcept.FlagFrecuencyType = 'P' and PR_EmployeeConcept.PRPeriodStart = (select MAX(PRPeriodStart) from PR_EmployeeConcept T where 
	--T.Company = PR_EmployeeConcept.Company and T.Person = PR_EmployeeConcept.Person AND T.Concept = PR_EmployeeConcept.Concept AND T.PayRollType = PR_EmployeeConcept.PayRollType)))

	
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


	
	
	----DIAS GRATI TRUNCA

	declare @dia_grati_trunca numeric(19,4)
	declare @ceasedate datetime, @fechaingreso datetime, @fechaini datetime

	set @ceasedate = (select CeaseDate from #empleado)
	set @fechaingreso = (select fechaingreso from #empleado)
		


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

	set @dia_cts_trunca = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XDIASCTS'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'XDIASCTS'),0) else @dia_cts_trunca end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XDIASCTS', @dia_cts_trunca, 'F'
	if isnull(@dia_cts_trunca,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XDIASCTS'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XDIASCTS', @dia_cts_trunca, 'Y'
	end



	declare @dia_vac_trunca numeric(19,4)
	declare @fechafinPeriodo datetime
	
	set @fechafinPeriodo = convert(datetime,left(@period,6)+'30')

	--	set @dias_vaca_totales = dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) )
	--set @dias_vaca_totales = @dias_vaca_totales + 2*@flag28
		
	set @dia_vac_trunca = case when @ceasedate IS NOT NULL then dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) ) else dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@fechafinPeriodo) ) end
		
	set @dia_vac_trunca = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XDIAVAC'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'XDIAVAC'),0) else @dia_vac_trunca end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XDIAVAC', @dia_vac_trunca, 'F'
	if isnull(@dia_vac_trunca,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XDIAVAC'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XDIAVAC', @dia_vac_trunca, 'Y'
	end

	--DIAS TOTAL DE DIAS CTS 

	declare @dia_total_cts numeric(19,4)
	

	set @dia_total_cts = case when @fechafinPeriodo >= convert(datetime,left(@period,4)+'0501') and  @fechafinPeriodo <= convert(datetime,left(@period,4)+'1031') then
								case when convert(date,@fechaingreso) >= convert(date,left(@period,4)+'0501') and convert(date,@fechaingreso) <= convert(date,left(@period,4)+'1031') then dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@fechafinPeriodo) ) else dbo.f_getDias360(convert(date, left(@period,4)+'0501') ,convert(date,@fechafinPeriodo) ) end 
							else
								case when @fechafinPeriodo > convert(datetime,left(@period,4)+'1031') then
									case when  convert(date,@fechaingreso) > convert(datetime,left(@period,4)+'1031') then dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@fechafinPeriodo) ) else dbo.f_getDias360(convert(date, left(@period,4) +'1101') ,convert(date,@fechafinPeriodo) ) end 
								else
									case when  convert(date,@fechaingreso) > convert(datetime,convert(char(4),convert(int,left(@period,4)) - 1)+'1031') then dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@fechafinPeriodo) ) else dbo.f_getDias360(convert(date,convert(char(4),convert(int,left(@period,4)) - 1)+'1101') ,convert(date,@fechafinPeriodo) ) end 
								end
							end

	set @dia_total_cts = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XTOTALDIASCTS'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'XTOTALDIASCTS'),0) else @dia_total_cts end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XTOTALDIASCTS', @dia_total_cts, 'F'
	if isnull(@dia_total_cts,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XTOTALDIASCTS'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XTOTALDIASCTS', @dia_total_cts, 'Y'
	end



	
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
		execute SP_PR_EjecutarFormula @company, @period, @payrolltype,  @processtype, @person, @nemonico
		--print @nemonico
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
	
	

	--TOTAL INGRESOS
	set @total_ingreso = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept inner join PR_Concept on (PR_EmployeePayRollConcept.Concept = PR_Concept.Concept) 
	inner join PR_ConceptType on (pr_concept.concepttype = PR_ConceptType.ConceptType and PR_ConceptType.ShortName = 'I')
	where PR_EmployeePayRollConcept.Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period ),0)

	--set @total_ingreso = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'TOTALINGRESO'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'TOTALINGRESO'),0) else @total_ingreso end
	--execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'TOTALINGRESO', @total_ingreso, 'F'
	--if isnull(@total_ingreso,0) > 0 
	--begin
	--	execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'TOTALINGRESO', @total_ingreso, 'Y'
	--end



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

	

	

	--TOTAL_EGRESOS
	declare @total_egreso numeric(19,4)
	set @total_egreso = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept inner join PR_Concept on (PR_EmployeePayRollConcept.Concept = PR_Concept.Concept) 
	inner join PR_ConceptType on (pr_concept.concepttype = PR_ConceptType.ConceptType and PR_ConceptType.ShortName = 'D')
	where PR_EmployeePayRollConcept.Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period ),0)

	--execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'TOTALEGRESOS', @total_egreso, 'F'
	--if isnull(@total_egreso,0) > 0 
	--begin
	--	execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'TOTALEGRESOS', @total_egreso, 'Y'
	--end

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

	

	

	--TOTAL_APORTES
	declare @total_aportes numeric(19,4)
	set @total_aportes = isnull((select sum(ConceptValueLo) from PR_EmployeePayRollConcept inner join PR_Concept on (PR_EmployeePayRollConcept.Concept = PR_Concept.Concept) 
	inner join PR_ConceptType on (pr_concept.concepttype = PR_ConceptType.ConceptType and PR_ConceptType.ShortName = 'A')
	where PR_EmployeePayRollConcept.Company = @company and PayRollType = @payrolltype and Person = @person
	and ProcessType = @processtype and PRPeriod = @period ),0)

	--execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'TOTALPATRONAL', @total_aportes, 'F'
	--if isnull(@total_aportes,0) > 0 
	--begin
	--	execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'TOTALPATRONAL', @total_aportes, 'Y'
	--end

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
	
end
GO
