


CREATE OR ALTER PROCEDURE [dbo].[sp_pr_asignar_conceptos_persona]
@company varchar(4), @payrolltype varchar(20), @period varchar(20), @person varchar(20), @UserID varchar(20)
as
begin	
	declare @dias_vacaciones int, @dias_descanso int, @dias_subsidio int, @dias_lsg int, @dias_falta int
	declare @vac_normal int, @vac_venta int, @dias_enf int, @dias_mat int, @dias_pat int, @dias_susp int, @dias_lcg int, @dias_fallece int
	declare @prestamo numeric(19,4), @flag28 int
	set @flag28  = 0
	set @flag28 = case when right((select convert(varchar(8), CeaseDate, 112) from PR_Employee where Person = @person and Company = @company),4) = '0228' then 1 else 0 end

	


	set @prestamo = isnull((select sum(AmountLo) from PR_EmployeeLoanAmortization where Company = @company and PRperiod = @period and Person = @person),0)

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

	--DIAS TRABAJADOS

	insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
	ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
	select PR_Employee.Person,PR_Employee.Company, 
	(select Concept from PR_Concept where FormulaCode = 'DIASTRABAJADOS' and Company = @company),
	PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
	case when convert(varchar(6), CeaseDate, 112) = left(@period,6) and convert(varchar(6), ISNULL(Reentrydate, entrydate), 112) = left(@period,6) then case when @flag28 = 1 then 30 else case when datepart(day, CeaseDate) - DATEPART(day, ISNULL(Reentrydate, entrydate)) + 1 = 31 then 30 else datepart(day, CeaseDate) - DATEPART(day, ISNULL(Reentrydate, entrydate)) + 1 end end else 
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

	if @prestamo > 0 
	begin
		delete from PR_EmployeeConcept where company = @company and PayRollType = @payrolltype and  Person = @person and PRPeriodStart = @period
		and exists (select * from PR_Concept where Concept = PR_EmployeeConcept.Concept and FormulaCode = 'DSCTO_DE_PRESTAMO')

		insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart, CostCenter, PRPeriodEnd, ConceptValue, Application,ConceptCurrency,
		ConceptValueLo,ConceptValueEx,ExchangeRate,Comments,FlagApplyFormula,FlagFrecuencyType, ReplicationUnit,XLastUser,XLastDate,CostCenterCode,PercentageDistribution)
		select 
			PR_Employee.Person,PR_Employee.Company, 
			(select Concept from PR_Concept where FormulaCode = 'DSCTO_DE_PRESTAMO' and Company = @company),
			PR_Employee.PayRollType,@period,PR_Employee.CostCenter,@period,
			@prestamo, 'PR', 'LO',NULL,NULL,NULL,NULL,'N', 'T', SY_Person.ReplicationUnit,@UserID,getdate(),PR_Employee.Costcentername,'A'
		from PR_Employee inner join SY_Person on (PR_Employee.Person = SY_Person.Person) 
		where PR_Employee.Status = 'N' and PR_Employee.Company = @company and PR_Employee.PayRollType = @payrolltype and PR_Employee.Person = @person
	end

end