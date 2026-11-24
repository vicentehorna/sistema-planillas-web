

CREATE procedure [dbo].[sp_pr_interfazplanillas]
@cia varchar(4), @period varchar(8), @payrolltype varchar(20), @person_all char(1), @person varchar(20), @repunit_all char(1), @repunit varchar(20)
as
begin
	
	declare @horas numeric(19,4), @h25 numeric(19,4), @h35 numeric(19,4), @hnoc  numeric(19,4), @faltas  numeric(19,4), @vacas  numeric(19,4)
	declare @dm  numeric(19,4), @susp  numeric(19,4), @lcg  numeric(19,4), @lsg  numeric(19,4), @lpat  numeric(19,4), @fer  numeric(19,4)
	declare @descanso  numeric(19,4), @diastrab  numeric(19,4)
	declare @inicio datetime, @fin datetime, @orden int
	declare @dni varchar(20), @nombre varchar(100), @concepto1 varchar(20), @concept varchar(20)
	

	select @inicio = convert(varchar(8),CADateBegin, 112), @fin = convert(varchar(8),CADateEnd, 112), @orden = PeriodOrder
	from pr_period where PRPeriod = @period and PayRollType = @payrolltype and Company = @cia

	
	
	Declare listado Cursor For
	select dni,nombre, sum(horas), sum(h25), sum(h35), sum(hnoc), sum(faltas), sum(vacas), sum(dm), sum(suspen), sum(lcg), sum(lsg), 
	sum(lpat), sum(fer), sum(descanso),
	/* Base 30 diastrab: A + D + feriado trabajado (X); topear a 30-ausencias */
	case
		when (sum(normal) + sum(descanso) + sum(fer) + sum(faltas) + sum(vacas) + sum(dm)
			+ sum(suspen) + sum(lcg) + sum(lsg) + sum(lpat)) > 30
		then case
			when 30 - (sum(faltas) + sum(vacas) + sum(dm) + sum(suspen) + sum(lcg) + sum(lsg) + sum(lpat)) < 0 then 0
			else 30 - (sum(faltas) + sum(vacas) + sum(dm) + sum(suspen) + sum(lcg) + sum(lsg) + sum(lpat))
		end
		else sum(normal) + sum(descanso) + sum(fer)
	end
	  from (
	select  
		b.Person as dni,
		b.Name as nombre,
		a.RegisterDate as fecha,
		isnull(a.hourday,0) as horas,
		isnull(a.extrahour25,0) as h25,
		isnull(a.extrahour35,0) as h35,
		isnull(a.extrahour100,0) as hnoc,
		case when a.RegisterType = 'A' then 1 else 0 end as normal,
		case when a.RegisterType = 'F' then 1 else 0 end as faltas,
		case when a.RegisterType = 'V' then 1 else 0 end as vacas,
		case when a.RegisterType = 'M' then 1 else 0 end as dm,
		case when a.RegisterType = 'S' then 1 else 0 end as suspen,
		case when a.RegisterType = 'L' then 1 else 0 end as lcg,
		case when a.RegisterType = 'N' then 1 else 0 end as lsg,
		case when a.RegisterType = 'P' then 1 else 0 end as lpat,
		case when a.RegisterType = 'X' then 1 else 0 end as fer,
		case when a.RegisterType = 'D' then 1 else 0 end as descanso

	
	from PR_REGISTERHOUR a inner join SY_Person b on (a.Person = b.Person)  inner join
	PR_Employee  d on (a.person = d.Person and d.Status = 'N' and d.company = @cia) inner join SY_Company e on (e.Company = d.Company) 
	where 
		a.Company = @cia and
		-- a.Person = '16770179'  and
		( a.Payrolltype = @payrolltype) and
		(convert(varchar(8),a.RegisterDate,112) between @inicio and @fin) and
		(@person_all = 'Y' or b.Person = @person) and
		(@repunit_all = 'Y' or a.ReplicationUnit = @repunit)
	
		)T
	group by dni, nombre

	

	OPEN listado 
	FETCH NEXT FROM listado INTO  @dni,@nombre,@horas,@h25,@h35, @hnoc,@faltas,@vacas, @dm, @susp, @lcg, @lsg, @lpat, @fer, @descanso, @diastrab
	WHILE @@FETCH_STATUS = 0 
	BEGIN 
		
		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'HOR'

		if @horas > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@horas,'PR', 'LO', @horas,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'H25'
		--print convert(varchar(8), @h25)
		if @h25 > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@h25,'PR', 'LO', @h25,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'H35'

		if @h35 > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@h35,'PR', 'LO', @h35,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'NOC'

		if @hnoc > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@hnoc,'PR', 'LO', @hnoc,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'FAL'

		if @faltas > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@faltas,'PR', 'LO', @faltas,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'VAC'

		if @vacas > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@vacas,'PR', 'LO', @vacas,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'MED'

		if @descanso > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@descanso,'PR', 'LO', @descanso,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'RIE'

		if @susp > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@susp,'PR', 'LO', @susp,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'LCG'

		if @lcg > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@lcg,'PR', 'LO', @lcg,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'LSG'

		if @lsg > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@lsg,'PR', 'LO', @lsg,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'LPT'

		if @lpat > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@lpat,'PR', 'LO', @lpat,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'FER'

		if @fer > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@fer,'PR', 'LO', @fer,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'SUB'

		if @dm > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@dm,'PR', 'LO', @dm,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end
		
		--select * from PR_CostCenterConcept where Company = 'BGT' and Type = 'PAG'


		select @concept = Concept from PR_CostCenterConcept where Company = @cia and Type = 'PAG'
		--select * from PR_Concept where Concept = 'BGT 000000000081'

		if @diastrab > 0 
		begin
			delete from PR_EmployeeConcept where Company = @cia and Person = @dni and Concept = @concept and PRPeriodStart = @period
			and PayRollType = @payrolltype

			insert into PR_EmployeeConcept (Person, Company,Concept,PayRollType,PRPeriodStart,CostCenter, PRPeriodEnd,ConceptValue,Application,ConceptCurrency,
			ConceptValueLo,ConceptValueEx,ExchangeRate,FlagApplyFormula,FlagFrecuencyType,ReplicationUnit,XLastUser,xlastdate,costcentercode,PercentageDistribution)
			select 
				Person,Company,@concept,PayRollType,@period,CostCenter,@period,@diastrab,'PR', 'LO', @diastrab,0,3.00,'N', 'T',
				'LIMA','TAREO', GETDATE(),Costcentername,'D'
			from PR_Employee where Person = @dni and Company = @cia

			set @concept = NULL
		end

	FETCH NEXT FROM listado
	INTO  @dni,@nombre,@horas,@h25,@h35, @hnoc,@faltas,@vacas, @dm, @susp, @lcg, @lsg, @lpat, @fer, @descanso, @diastrab
	END 
	
	CLOSE listado
	DEALLOCATE listado
	

	
end

