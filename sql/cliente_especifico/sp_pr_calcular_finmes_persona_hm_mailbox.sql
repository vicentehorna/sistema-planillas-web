

--sp_pr_calcular_finmes_persona 'BGT', 'LIMABGT 000000000005', 'BGT 000000000011', '20250707', '03888662', 'ADMIN', 3.14



--select * FROM PR_PROCESSTYPE

--select * FROM PR_PAYROLLTYPE

--select PR_Concept.FormulaCode  from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = 'BGT'
--	and PR_FormulaHeader.Proccestype = 'BGT 000000000002' and PR_FormulaHeader.Payrolltype = 'LIMABGT 000000000001')

	--select PR_FormulaHeader.FormulaHeader, PR_Concept.FormulaCode  from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = 'BGT'
	--and PR_FormulaHeader.Proccestype = 'BGT 000000000002' and PR_FormulaHeader.Payrolltype = 'LIMABGT 000000000001')

--	select * from PR_Concept where FormulaCode = 'HRS_EXTRAS_PORC_35'
--	select * from PR_FormulaDetail where FormulaHeader = 'LIMABGT 000000000031'

CREATE PROCEDURE [dbo].[sp_pr_calcular_finmes_persona]
@company varchar(4), @payrolltype varchar(20),  @processtype varchar(20), @period varchar(20), @person varchar(20), @UserID varchar(20), @tc numeric(19,4)
as
begin	
	declare @importe numeric(19,4), @horas25 numeric(19,4), @horas35 numeric(19,4), @horas100 numeric(19,4), @total_5ta numeric(19,4), @total_ingreso numeric(19,4), @total_AFP numeric(19,4)
	declare @tardanza numeric(19,4), @faltas numeric(19,4), @cesado int
	/* PDT pensión: 02=ONP, 21=Integra, 23=Profuturo, 24=Prima, 25=Habitat (fórmulas AFP_HOR_*) */
	declare @pension_pdt varchar(10)
	declare @skip_formula bit

	set @pension_pdt = ''
	select @pension_pdt = ltrim(rtrim(isnull(pt.PDT, '')))
	from PR_Employee e
	inner join PR_PensionType pt
		on pt.PensionType = e.PensionType and pt.Company = e.Company
	where e.Person = @person and e.Company = @company

	if @pension_pdt in ('2', '02') set @pension_pdt = '02'

	/*INGRESAR EN ASIGNACION DE CONCEPTOS*/


	execute sp_pr_asignar_conceptos_persona @company, @payrolltype,  @period, @person, @UserID
	
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
	and exists (select * from PR_Concept C where C.Company = @company and C.Concept = PR_EmployeeConcept.Concept and isnull(C.flaginsertar, 'N') = 'M')
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
	and exists (select * from PR_Concept C where C.Company = @company and C.Concept = PR_EmployeeConcept.Concept and isnull(C.flaginsertar, 'N') = 'M')
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
	--	print @nemonico
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


	--DATOS DEL TRABAJADOR
	select isnull(reentrydate,entrydate) as fechaingreso, PR_PensionType.PDT as pension, PR_AFP.PensionPercentage as porc_aporte, variablepercentage as porc_comision_flu, topafp, insuredpercentage as porc_seguro 
	into #empleado from PR_Employee inner join PR_PensionType on (PR_Employee.PensionType = PR_PensionType.PensionType and PR_PensionType.Company = @company) 
	left join PR_AFP on (PR_Employee.AFP = PR_AFP.afp and PR_AFP.Company = @company)
	where Person = @person and PR_Employee.company = @company

	
	--MESES
	declare @meses numeric(19,4),  @cantidad_mes numeric(19,4), @fechaingreso datetime, @period_act varchar(20)

	set @meses = 12 - convert(int, substring(@period,5,2))
	set @fechaingreso = (select fechaingreso from #empleado)
	
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'MESES', @meses, 'F'
	if isnull(@meses,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'MESES'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'MESES', @meses, 'Y'
	end

	--CANTIDAD MES JULIO
	
	set @cantidad_mes = case when @fechaingreso >= convert(datetime,isnull((left(@period,4) + '0701'),'')) then 0 else 
							case when convert(varchar(6),isnull(@fechaingreso,''),112) >= left(isnull((left(@period,4) + '0101'),''),6) then
								case when DATEPART(DAY,@fechaingreso) > 1 then 6 - DATEPART(MONTH,@fechaingreso) else 6 - DATEPART(MONTH,@fechaingreso) + 1 end
							else
								6
							end 
						end
 
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'CANTIDAD_MES', @cantidad_mes, 'F'
	if isnull(@cantidad_mes,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'CANTIDAD_MES'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'CANTIDAD_MES', @cantidad_mes, 'Y'
	end


	--CANTIDAD MES DICIEMBRE
	set @period_act =   
	(select PRPeriod from PR_Period where Company = @company and PayRollType = @payrolltype and PeriodOrder = (
	select PeriodOrder from PR_Period where Company = @company and PayRollType = @payrolltype and left(PRPeriod,6) = (left(isnull((left(@period,4) + '0101'),''),6))) + 6) 

	set @cantidad_mes = case when convert(varchar(6),isnull(@fechaingreso,''),112) >= left(@period_act,6) then
							case when DATEPART(DAY,@fechaingreso) > 1 then 
								12 - DATEPART(MONTH,@fechaingreso) 
							else 
								12 - DATEPART(MONTH,@fechaingreso) + 1 
							end
						else
							6
						end



	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'CANTIDAD_MES_DIC', @cantidad_mes, 'F'
	if isnull(@cantidad_mes,0) > 0 
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'CANTIDAD_MES_DIC', @cantidad_mes, 'Y'
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
		/* Skip fórmulas AFP/ONP de otras AFP: solo ejecuta la del PDT del trabajador.
		   Agregadores (AFP_SEGUROS, AFP_APORTE_PORC_8, AFP_COMISION_VARIABL, TOTAL_REM_AFP) no se saltan.
		   Si PDT no es 02/21/23/24/25 se mantiene comportamiento anterior (ejecuta todas). */
		set @skip_formula = 0
		if @pension_pdt in ('02', '21', '23', '24', '25')
		begin
			if (
				((@nemonico like 'AFP_INT_%' or @nemonico = 'AFP_INTEGRA') and @pension_pdt <> '21')
				or ((@nemonico like 'AFP_PROF_%' or @nemonico = 'AFP_PROFUTURO') and @pension_pdt <> '23')
				or ((@nemonico like 'AFP_PRI_%' or @nemonico = 'AFP_PRIMA') and @pension_pdt <> '24')
				or ((@nemonico like 'AFP_HOR_%' or @nemonico = 'AFP_HORIZONTE') and @pension_pdt <> '25')
				or (@nemonico = 'ONP' and @pension_pdt <> '02')
			)
				set @skip_formula = 1
		end

		if @skip_formula = 0
		begin
			execute SP_PR_EjecutarFormula @company, @period, @payrolltype,  @processtype, @person, @nemonico
			--print @nemonico
			set @importe_formula = ISNULL((select valor from xx_valor),0)
			set @importe_formula = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = @nemonico),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = @nemonico),0) else @importe_formula end
			execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, @nemonico, @importe_formula, 'F'
			if isnull(@importe_formula,0) > 0 
			begin
				execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, @nemonico, @importe_formula, 'Y'
			end
			
	
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

		--DIAS TRABAJADOS REAL
	declare @DIASTRABAJADOS numeric(19,4)
	set @DIASTRABAJADOS = isnull((select ConceptValue from #conceptos where FormulaCode = 'DIASTRABAJADOS'),0)


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

