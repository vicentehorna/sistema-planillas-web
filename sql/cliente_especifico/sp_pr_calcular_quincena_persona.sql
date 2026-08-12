





CREATE OR ALTER PROCEDURE [dbo].[sp_pr_calcular_quincena_persona]

@company varchar(4), @payrolltype varchar(20),  @processtype varchar(20), @period varchar(20), @person varchar(20), @UserID varchar(20), @tc numeric(19,4)

as

begin	

	declare @importe numeric(19,4), @horas25 numeric(19,4), @horas35 numeric(19,4), @horas100 numeric(19,4), @total_5ta numeric(19,4), @total_ingreso numeric(19,4), @total_AFP numeric(19,4)

	declare @tardanza numeric(19,4), @faltas numeric(19,4), @cesado int



	/*INGRESAR EN ASIGNACION DE CONCEPTOS*/





	--execute sp_pr_asignar_conceptos_persona @company, @payrolltype,  @period, @person, @UserID





	

	/*INSERTAR CONCEPTOS DESDE ASIGNACION*/

	set @cesado = case when isnull((select convert(varchar(6),CeaseDate,112) from PR_Employee where Person	 = @person and Company = @company),'') = '' then 0 else

						case when isnull((select convert(varchar(6),CeaseDate,112) from PR_Employee where Person	 = @person and Company = @company),'') < left(@period,6) then 1 else 0 end end



	declare @15na int

	set @15na = ISNULL(NULLIF((SELECT ParameterNumberValue FROM PR_Parameter WHERE Company = @company AND ShortName = 'DIAQUINCENA'), 0), 15)

	--print @15na

	--print @cesado

	--IF @15na > 0 AND datepart(day,(select isnull(ReEntryDate,EntryDate) from PR_Employee where person = @person and Company = @company)) <= @15na and @cesado = 0

	IF @15na > 0 AND  @cesado = 0 and 

	(convert(varchar(6),(select isnull(ReEntryDate,EntryDate) from PR_Employee where person = @person and Company = @company),112) < left(@period,6) or (convert(varchar(6),(select isnull(ReEntryDate,EntryDate) from PR_Employee where person = @person and Company = @company),112) = left(@period,6) and datepart(day,(select isnull(ReEntryDate,EntryDate) from PR_Employee where person = @person and Company = @company)) <= @15na))

	begin

	

	

	delete from PR_EmployeePayRollConcept where Company = @company and PayRollType = @payrolltype and Person = @person

	and ProcessType = @processtype and PRPeriod = @period



	delete from PR_EmployeePayRoll where Company = @company and PayRollType = @payrolltype and Person = @person

	and ProcessType = @processtype and PRPeriod = @period



	delete from PR_LOG_CALCULO_PLANILLAS where Company = @company and PayRollType = @payrolltype and Person = @person

	and process = @processtype and period = @period



	



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

	and exists (select * from PR_Concept C where C.Company = @company and C.Concept = PR_EmployeeConcept.Concept and isnull(C.flaginsertar, 'N') = 'Q')

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

	and exists (select * from PR_Concept C where C.Company = @company and C.Concept = PR_EmployeeConcept.Concept and isnull(C.flaginsertar, 'N') = 'Q')

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

	end

end



