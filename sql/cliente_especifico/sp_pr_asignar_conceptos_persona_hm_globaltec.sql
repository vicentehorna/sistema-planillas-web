/*
    hm_globaltec: sp_pr_asignar_conceptos_persona
    Misma lógica base (sin WorkingDaysType S/R de garc).
    Incluye bloque LIMPIEZA (como hm_garc) para borrar DIAS_VACAC_NORMAL/VENTA
    y otros conceptos auto-generados cuando el origen (vacaciones, etc.) ya no existe.

    Préstamos: separa cuotas por flagliquidation (F/V/U/G) y asigna el concepto
    configurado en PR_Mapping2 (LoanConceptFinMes / Vacaciones / Utilidades / Gratificacion).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_asignar_conceptos_persona]
@company varchar(4), @payrolltype varchar(20), @period varchar(20), @person varchar(20), @UserID varchar(20)
as
begin	
	declare @dias_vacaciones int, @dias_descanso int, @dias_subsidio int, @dias_lsg int, @dias_falta int
	declare @vac_normal int, @vac_venta int, @dias_enf int, @dias_mat int, @dias_pat int, @dias_susp int, @dias_lcg int, @dias_fallece int
	declare @prestamo numeric(19,4), @prestamo_finmes numeric(19,4), @prestamo_vacaciones numeric(19,4)
	declare @prestamo_utilidades numeric(19,4), @prestamo_grati numeric(19,4), @flag28 int
	declare @concept_prestamo_finmes varchar(20), @concept_prestamo_vacaciones varchar(20)
	declare @concept_prestamo_utilidades varchar(20), @concept_prestamo_grati varchar(20)
	set @flag28  = 0
	set @flag28 = case when right((select convert(varchar(8), CeaseDate, 112) from PR_Employee where Person = @person and Company = @company),4) = '0228' then 1 else 0 end

	/* Cuotas de préstamo por proceso (flagliquidation: F/V/U/G). */
	set @prestamo_finmes = isnull((select sum(AmountLo) from PR_EmployeeLoanAmortization
		where Company = @company and PRperiod = @period and Person = @person
		  and UPPER(LTRIM(RTRIM(ISNULL(flagliquidation, 'F')))) = 'F'), 0)
	set @prestamo_vacaciones = isnull((select sum(AmountLo) from PR_EmployeeLoanAmortization
		where Company = @company and PRperiod = @period and Person = @person
		  and UPPER(LTRIM(RTRIM(ISNULL(flagliquidation, '')))) = 'V'), 0)
	set @prestamo_utilidades = isnull((select sum(AmountLo) from PR_EmployeeLoanAmortization
		where Company = @company and PRperiod = @period and Person = @person
		  and UPPER(LTRIM(RTRIM(ISNULL(flagliquidation, '')))) = 'U'), 0)
	set @prestamo_grati = isnull((select sum(AmountLo) from PR_EmployeeLoanAmortization
		where Company = @company and PRperiod = @period and Person = @person
		  and UPPER(LTRIM(RTRIM(ISNULL(flagliquidation, '')))) = 'G'), 0)
	set @prestamo = isnull(@prestamo_finmes,0) + isnull(@prestamo_vacaciones,0)
		+ isnull(@prestamo_utilidades,0) + isnull(@prestamo_grati,0)

	/* Conceptos configurados en PR_Mapping2 (fallback FormulaCode legado). */
	select
		@concept_prestamo_finmes = nullif(ltrim(rtrim(isnull(LoanConceptFinMes, ''))), ''),
		@concept_prestamo_vacaciones = nullif(ltrim(rtrim(isnull(LoanConceptVacaciones, ''))), ''),
		@concept_prestamo_utilidades = nullif(ltrim(rtrim(isnull(LoanConceptUtilidades, ''))), ''),
		@concept_prestamo_grati = nullif(ltrim(rtrim(isnull(LoanConceptGratificacion, ''))), '')
	from PR_Mapping2
	where Company = @company

	if @concept_prestamo_finmes is null
		select top 1 @concept_prestamo_finmes = Concept
		from PR_Concept where Company = @company and FormulaCode = 'DSCTO_DE_PRESTAMO'
		order by Concept

	if @concept_prestamo_vacaciones is null
		select top 1 @concept_prestamo_vacaciones = Concept
		from PR_Concept
		where Company = @company
		  and (FormulaCode = 'PRESTAMOVAC'
		       or upper(ltrim(rtrim(Description))) = 'DESCUENTO DE PRESTAMO VACACIONES')
		order by case when FormulaCode = 'PRESTAMOVAC' then 0 else 1 end, Concept

	set @dias_susp = 	isnull((select sum(Days) from PR_EmployeeMedicalRest inner join PR_MedicalRestType on  (PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
							and PR_MedicalRestType.pdt = '01') where PR_EmployeeMedicalRest.Company = @company and PRPeriod = @period and Person = @person),0)

	set @dias_pat = 	isnull((select sum(Days) from PR_EmployeeMedicalRest inner join PR_MedicalRestType on  (PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
							and PR_MedicalRestType.pdt = '28') where PR_EmployeeMedicalRest.Company = @company and PRPeriod = @period and Person = @person),0)

	set @dias_enf = 	isnull((select sum(Days) from PR_EmployeeMedicalRest inner join PR_MedicalRestType on  (PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
							and PR_MedicalRestType.pdt = '21') where PR_EmployeeMedicalRest.Company = @company and PRPeriod = @period and Person = @person),0)

	set @dias_mat = 	isnull((select sum(Days) from PR_EmployeeMedicalRest inner join PR_MedicalRestType on  (PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
							and PR_MedicalRestType.pdt = '22') where PR_EmployeeMedicalRest.Company = @company and PRPeriod = @period and Person = @person),0)

	set @dias_fallece = 	isnull((select sum(Days) from PR_EmployeeMedicalRest inner join PR_MedicalRestType on  (PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
							and PR_MedicalRestType.pdt = '32') where PR_EmployeeMedicalRest.Company = @company and PRPeriod = @period and Person = @person),0)

	set @vac_normal = isnull((select SUM(Days) from PR_VacationPay where Company = @company and PRPeriod = @period and Person = @person and VacationType = 'D'),0)

	set @vac_venta = isnull((select SUM(Days) from PR_VacationPay where Company = @company and PRPeriod = @period and Person = @person and VacationType = 'V'),0)

	set @dias_vacaciones = isnull((select SUM(Days) from PR_VacationPay where Company = @company and PRPeriod = @period and Person = @person),0)
	
	set @dias_descanso = 	isnull((select sum(Days) from PR_EmployeeMedicalRest inner join PR_MedicalRestType on  (PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
							and PR_MedicalRestType.pdt = '20') where PR_EmployeeMedicalRest.Company = @company and PRPeriod = @period and Person = @person),0)

	set @dias_subsidio = 	isnull((select sum(Days) from PR_EmployeeMedicalRest inner join PR_MedicalRestType on  (PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
							and PR_MedicalRestType.pdt in( '21', '22')) where PR_EmployeeMedicalRest.Company = @company and PRPeriod = @period and Person = @person),0)

	set @dias_lsg = 	isnull((select sum(Days) from PR_EmployeeMedicalRest inner join PR_MedicalRestType on  (PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
							and PR_MedicalRestType.pdt = '05') where PR_EmployeeMedicalRest.Company = @company and PRPeriod = @period and Person = @person),0)

	set @dias_lcg = 	isnull((select sum(Days) from PR_EmployeeMedicalRest inner join PR_MedicalRestType on  (PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
							and PR_MedicalRestType.pdt = '26') where PR_EmployeeMedicalRest.Company = @company and PRPeriod = @period and Person = @person),0)

	set @dias_falta = 	isnull((select sum(Days) from PR_EmployeeMedicalRest inner join PR_MedicalRestType on  (PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
							and PR_MedicalRestType.pdt = '07') where PR_EmployeeMedicalRest.Company = @company and PRPeriod = @period and Person = @person),0)


	delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
	and exists (select * from PR_Concept where Concept = PR_EmployeeConcept.Concept and FormulaCode = 'DIASTRABAJADOS')

	--LIMPIEZA: conceptos generados por este SP en el periodo cuyo origen ya no existe
	--(vacaciones, descansos, subsidios o préstamos eliminados). No toca asignaciones manuales ni TAREO.
	delete EC
	from PR_EmployeeConcept EC
	where EC.Company = @company and EC.PayRollType = @payrolltype and EC.Person = @person
	  and EC.PRPeriodStart = @period and EC.PRPeriodEnd = @period
	  and EC.Application = 'PR' and isnull(EC.XLastUser,'') <> 'TAREO'
	  and EC.Concept in (
			select C.Concept from PR_Concept C
			where C.Company = @company
			  and C.FormulaCode in ('DIAS_VACAC_NORMAL','DIAS_VACAC_VENTA','DIAFALLECIMIENTO','DSCTO_DE_PRESTAMO','PRESTAMOVAC')
			union
			select V.Concept from PR_Mapping2 M
			cross apply (values (M.absencesdaysconcept), (M.mrcompanydaysconcept),
								(M.mrallowancedaysnotaxconcept), (M.mrallowancedaystaxconcept),
								(M.mrbenefitsdaystaxconcept), (M.mrbenefitsdaysnotaxconcept),
								(M.mrvacationdaystaxconcept), (M.mrvacationdaysnotaxconcept),
								(M.LoanConceptFinMes), (M.LoanConceptVacaciones),
								(M.LoanConceptUtilidades), (M.LoanConceptGratificacion)) V(Concept)
			where M.Company = @company and isnull(V.Concept,'') <> ''
	  )

	--DIAS TRABAJADOS

	insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
	ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
	select PR_Employee.Person,PR_Employee.Company, 
	(select Concept from PR_Concept where FormulaCode = 'DIASTRABAJADOS' and Company = @company),
	PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
	case when convert(varchar(6), CeaseDate, 112) = left(@period,6) and convert(varchar(6), ISNULL(Reentrydate, entrydate), 112) = left(@period,6) then case when @flag28 = 1 then  30 else datepart(day, CeaseDate) end - DATEPART(day, ISNULL(Reentrydate, entrydate)) + 1 else 
	case when (
	case when convert(varchar(6), CeaseDate, 112) < left(@period,6) then 0 else
	case when convert(varchar(6), CeaseDate, 112) = left(@period,6) then case when @flag28 = 1 then  30 else datepart(day, CeaseDate) end else
	(case when convert(varchar(6), ISNULL(Reentrydate, entrydate), 112) < left(@period,6) then 30 else 
		case when convert(varchar(6), ISNULL(Reentrydate, entrydate), 112) = left(@period,6) then 30 - DATEPART(day, ISNULL(Reentrydate, entrydate)) + 1 else 0 end end) end end) = 31 then 30 else 
		(
	case when convert(varchar(6), CeaseDate, 112) < left(@period,6) then 0 else
	case when convert(varchar(6), CeaseDate, 112) = left(@period,6) then case when @flag28 = 1 then  30 else datepart(day, CeaseDate) end else
	(case when convert(varchar(6), ISNULL(Reentrydate, entrydate), 112) < left(@period,6) then 30 else 
		case when convert(varchar(6), ISNULL(Reentrydate, entrydate), 112) = left(@period,6) then 30 - DATEPART(day, ISNULL(Reentrydate, entrydate)) + 1 else 0 end end) end end) end end
	- (@vac_normal + @dias_descanso + @dias_subsidio + @dias_lsg + @dias_falta + @dias_lcg + @dias_fallece),
	'PR', 'LO',NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
	from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
	where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	and 
	(case when convert(varchar(6), CeaseDate, 112) < left(@period,6) then 0 else
	case when convert(varchar(6), CeaseDate, 112) = left(@period,6) then case when @flag28 = 1 then  30 else datepart(day, CeaseDate) end else
	(case when convert(varchar(6), ISNULL(Reentrydate, entrydate), 112) < left(@period,6) then 30 else 
		case when convert(varchar(6), ISNULL(Reentrydate, entrydate), 112) = left(@period,6) then 30 - DATEPART(day, ISNULL(Reentrydate, entrydate)) + 1 else 0 end end) end end
	- (@vac_normal + @dias_descanso + @dias_subsidio + @dias_lsg + @dias_falta + @dias_fallece)) > 0

	if @vac_normal > 0 
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and exists (select * from PR_Concept where Concept = PR_EmployeeConcept.Concept and FormulaCode = 'DIAS_VACAC_NORMAL')

		set @vac_normal = case when SUBSTRING(@period,5,2) = '02' and @vac_normal = 28 then 30 else @vac_normal end
		if SUBSTRING(@period,5,2) = '02' and @vac_normal = 30
		begin
			delete from PR_EmployeeConcept where Person = @person and PRPeriodStart = @period and Concept = 
			(select Concept from PR_Concept where FormulaCode = 'DIASTRABAJADOS' and Company = @company) and Company = @company
			and PRPeriodEnd = @period
		end
		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select Concept from PR_Concept where FormulaCode = 'DIAS_VACAC_NORMAL' and Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@vac_normal, 'PR', 'LO',NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	if @vac_venta > 0 
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and exists (select * from PR_Concept where Concept = PR_EmployeeConcept.Concept and FormulaCode = 'DIAS_VACAC_VENTA')

		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select Concept from PR_Concept where FormulaCode = 'DIAS_VACAC_VENTA' and Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@vac_venta, 'PR', 'LO',NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end


	IF @dias_fallece > 0 
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and Concept = (select Concept from PR_Concept where FormulaCode = 'DIAFALLECIMIENTO' and company = @company)
		
		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select Concept from PR_Concept where FormulaCode = 'DIAFALLECIMIENTO' and company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@dias_fallece, 'PR', NULL,NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end
	


	IF @dias_falta > 0 and isnull((select absencesdaysconcept  from PR_Mapping2 where Company = @company),'') <> ''
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and Concept = (select absencesdaysconcept  from PR_Mapping2 where Company = @company)
		
		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select absencesdaysconcept  from PR_Mapping2 where Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@dias_falta, 'PR', NULL,NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	IF @dias_descanso > 0 and isnull((select mrcompanydaysconcept  from PR_Mapping2 where Company = @company),'') <> ''
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and Concept = (select mrcompanydaysconcept  from PR_Mapping2 where Company = @company)
		
		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select mrcompanydaysconcept  from PR_Mapping2 where Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@dias_descanso, 'PR', NULL,NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end
	
	IF @dias_enf > 0 and isnull((select mrallowancedaysnotaxconcept  from PR_Mapping2 where Company = @company),'') <> ''
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and Concept = (select mrallowancedaysnotaxconcept  from PR_Mapping2 where Company = @company)
		
		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select mrallowancedaysnotaxconcept  from PR_Mapping2 where Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@dias_enf, 'PR', NULL,NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	IF @dias_mat > 0 and isnull((select mrallowancedaystaxconcept  from PR_Mapping2 where Company = @company),'') <> ''
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and Concept = (select mrallowancedaystaxconcept  from PR_Mapping2 where Company = @company)
		
		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select mrallowancedaystaxconcept  from PR_Mapping2 where Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@dias_mat, 'PR', NULL,NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	IF @dias_pat > 0 and isnull((select mrbenefitsdaystaxconcept  from PR_Mapping2 where Company = @company),'') <> ''
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and Concept = (select mrbenefitsdaystaxconcept  from PR_Mapping2 where Company = @company)
		
		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select mrbenefitsdaystaxconcept  from PR_Mapping2 where Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@dias_pat, 'PR', NULL,NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	IF @dias_susp > 0 and isnull((select mrbenefitsdaysnotaxconcept  from PR_Mapping2 where Company = @company),'') <> ''
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and Concept = (select mrbenefitsdaysnotaxconcept  from PR_Mapping2 where Company = @company)
		
		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select mrbenefitsdaysnotaxconcept  from PR_Mapping2 where Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@dias_susp, 'PR', NULL,NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	IF @dias_lsg > 0 and isnull((select mrvacationdaystaxconcept  from PR_Mapping2 where Company = @company),'') <> ''
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and Concept = (select mrvacationdaystaxconcept  from PR_Mapping2 where Company = @company)
		
		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select mrvacationdaystaxconcept  from PR_Mapping2 where Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@dias_lsg, 'PR', NULL,NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	IF @dias_lcg > 0 and isnull((select mrvacationdaysnotaxconcept  from PR_Mapping2 where Company = @company),'') <> ''
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and Concept = (select mrvacationdaysnotaxconcept  from PR_Mapping2 where Company = @company)
		
		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select mrvacationdaysnotaxconcept  from PR_Mapping2 where Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@dias_lcg, 'PR', NULL,NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	/* Descuento de préstamo: un concepto por tipo de proceso de la cuota (flagliquidation). */
	if @prestamo_finmes > 0 and isnull(@concept_prestamo_finmes, '') <> ''
	begin
		delete from PR_EmployeeConcept
		where company = @company and PayRollType = @payrolltype and Person = @person and PRPeriodStart = @period
		  and Concept = @concept_prestamo_finmes

		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			@concept_prestamo_finmes,
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@prestamo_finmes, 'PR', 'LO',NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	if @prestamo_vacaciones > 0 and isnull(@concept_prestamo_vacaciones, '') <> ''
	begin
		delete from PR_EmployeeConcept
		where company = @company and PayRollType = @payrolltype and Person = @person and PRPeriodStart = @period
		  and Concept = @concept_prestamo_vacaciones

		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			@concept_prestamo_vacaciones,
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@prestamo_vacaciones, 'PR', 'LO',NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	if @prestamo_utilidades > 0 and isnull(@concept_prestamo_utilidades, '') <> ''
	begin
		delete from PR_EmployeeConcept
		where company = @company and PayRollType = @payrolltype and Person = @person and PRPeriodStart = @period
		  and Concept = @concept_prestamo_utilidades

		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			@concept_prestamo_utilidades,
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@prestamo_utilidades, 'PR', 'LO',NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

	if @prestamo_grati > 0 and isnull(@concept_prestamo_grati, '') <> ''
	begin
		delete from PR_EmployeeConcept
		where company = @company and PayRollType = @payrolltype and Person = @person and PRPeriodStart = @period
		  and Concept = @concept_prestamo_grati

		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			@concept_prestamo_grati,
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@prestamo_grati, 'PR', 'LO',NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

end
GO
