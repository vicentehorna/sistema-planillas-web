

/*
select * from PR_FormulaHeader	order by XLastDate
select * from PR_FormulaDetail where FormulaHeader = 'LIMABGT 000000000722'
*/
--SP_PR_EjecutarFormula 'BGT', '20260404', 'LIMABGT 000000000005', 'BGT 000000000011', '72789691', 'LIQ_REM_BASICA'
--SElect * from xx_valor
--select * from PR_Concept where Concept = 'LIMABGT 000000000421' 
--select * from PR_ProcessType WHERE COMPANY = 'SB01'
--select * from PR_PAYROLLTYPE WHERE COMPANY = 'SB01'
--select * from PR_EmployeePayRollConcept where Concept = 'LIMABGT 000000000421' and ProcessType = 'BGT 000000000011' and Person = '08888197' 


--SP_PR_EjecutarFormula 'BGT', '20250808', 'LIMABGT 000000000005', 'BGT 000000000004', '71913986', 'Y'
--SELECT * from xx_valor
--SP_PR_EjecutarFormula 'SB01', '20250505',  'LIMASB01000000000005', 'SB01000000000011', '47551566', 'LIQ_REM_BASICA'

--select PR_FormulaDetail.Tipo,Operador,PR_FormulaDetail.Concept,grupo, valor, parameter,PR_FormulaDetail.process, periodoini, periodofin,numberini, numberfin, PR_FormulaDetail.TipoLiq
--		from PR_FormulaHeader inner join PR_FormulaDetail on (PR_FormulaHeader.FormulaHeader = PR_FormulaDetail.FormulaHeader) 
--		where PR_FormulaHeader.Concept = 'SB01000000000179' and PR_FormulaHeader.Payrolltype = 'LIMASB01000000000005' and PR_FormulaHeader.Proccestype = 'SB01000000000011'
--		and ((0 > 0 and PR_FormulaDetail.line <= 0) or (0 = 0))
--		order by line

--		select PR_FormulaDetail.Tipo,Operador,PR_FormulaDetail.Concept,grupo, valor, parameter,PR_FormulaDetail.process, periodoini, periodofin,numberini, numberfin, PR_FormulaDetail.TipoLiq
--		from PR_FormulaHeader inner join PR_FormulaDetail on (PR_FormulaHeader.FormulaHeader = PR_FormulaDetail.FormulaHeader) 
--		where PR_FormulaHeader.Concept = 'SB01000000000179' and PR_FormulaHeader.Payrolltype = 'LIMASB01000000000005' and PR_FormulaHeader.Proccestype = 'SB01000000000011'
--		and ((0 > 0 and PR_FormulaDetail.line <= 0) or (0 = 0))
--		order by line

--		select * from PR_Concept where FormulaCode = 'LIQ_REM_BASICA'
--		select * from PR_Concept where Concept = 'SB01000000000002'
		
CREATE OR ALTER PROCEDURE [dbo].[SP_PR_EjecutarFormula]
@cia varchar(20), @period varchar(20), @payrolltype varchar(20), @processtype varchar(20), @person varchar(20), @formulacode varchar(50)
as
Begin
	declare @tipo varchar(20), @opera varchar(20), @conceptid varchar(20), @grupo varchar(20), @parameter varchar(20), @flagtruncate char(1), @TipoLiq char(1)
	declare @num numeric(19,4), @num2 numeric(19,4), @importe numeric(19,4), @importecond numeric(19,4), @pos int, @cuenta_total int
	declare @valor numeric(19,4), @numero numeric(19,4),@numberini numeric(9,0), @numberfin numeric(9,0), @suma_total numeric(19,4)
	declare @query varchar(1024), @query1 varchar(1024), @query2 varchar(1024), @process varchar(20), @period_ini varchar(20), @period_begin varchar(20), @period_end varchar(20)
	declare @concept varchar(20), @conceptcond varchar(20), @tipocond char(1), @periodoini varchar(20), @periodofin varchar(20), @formulaid varchar(20)
	declare @ceasedate datetime, @fechaingreso datetime
	declare @conceptcode varchar(50), @flag_cts char(1), @conceptlist varchar(500)

	set @flag_cts = case when isnull((select ShortName from pr_processtype where ProcessType = @processtype),'') = 'CTS' then 'Y' else 'N' end 
	

	set @concept = (select  Concept from PR_Concept where Company = @cia and FormulaCode = @formulacode)
	set @pos = 0
	SET @tipocond = 'N'

	select @tipocond = ISNULL(Tipo, 'N'), @conceptcond = ISNULL(Conceptcond,''), @flagtruncate = isnull(flagtruncate, 'N'), @formulaid = FormulaHeader  from PR_FormulaHeader 
	where PR_FormulaHeader.Concept = @concept and Payrolltype = @payrolltype and Proccestype = @processtype

	select isnull(reentrydate,entrydate) as fechaingreso, PR_PensionType.PDT as pension, PR_AFP.PensionPercentage as porc_aporte, variablepercentage as porc_comision_flu, 
	topafp, insuredpercentage as porc_seguro, PR_Employee.CeaseDate as CeaseDate
	into #empleado 
	from PR_Employee inner join PR_PensionType on (PR_Employee.PensionType = PR_PensionType.PensionType and PR_PensionType.Company = @cia) 
	left join PR_AFP on (PR_Employee.AFP = PR_AFP.afp and PR_AFP.Company = @cia)
	where Person = @person and PR_Employee.company = @cia
	
	set @ceasedate = (select CeaseDate from #empleado)
	set @fechaingreso = (select fechaingreso from #empleado)
	

	if ISNULL(@tipocond, 'N') = 'N' set @importecond = 0

	if ISNULL(@conceptcond, '') <> '' AND ISNULL(@tipocond, 'N') IN ('A', 'C')
	BEGIN
		
		set @pos = ISNULL((select line from PR_FormulaDetail where FormulaHeader = @formulaid and Operador = 'T'),0)
		
		IF @tipocond = 'A'
		BEGIN
			
			--set @importecond = ISNULL((select ISNULL(P.ConceptValue, P.ConceptValueLo) from
			--	PR_EmployeeConcept P INNER JOIN PR_Concept C  ON (P.Concept = C.Concept and P.Company = @cia and P.PayRollType = @payrolltype and P.Person = @person 
			--	and P.Concept = @conceptcond)
			--where
			--	((FlagFrecuencyType = 'P' and PRPeriodStart <= @period) or (FlagFrecuencyType = 'T' and @period between PRPeriodStart and PRPeriodEnd))),0)	
				
			
			set @importecond = ISNULL((select ISNULL(P.ConceptValue, P.ConceptValueLo) from
				PR_EmployeeConcept P INNER JOIN PR_Concept C  ON (P.Concept = C.Concept and P.Company = @cia and P.PayRollType = @payrolltype and P.Person = @person 
				and P.Concept = @conceptcond)
			where
				((FlagFrecuencyType = 'P' and PRPeriodStart <= @period) or (FlagFrecuencyType = 'T' and @period between PRPeriodStart and PRPeriodEnd))
					and (P.FlagFrecuencyType = 'T' or (P.FlagFrecuencyType = 'P' and P.PRPeriodStart = (select MAX(PRPeriodStart) from PR_EmployeeConcept T where 
					T.Company = P.Company and T.Person = P.Person AND T.Concept = P.Concept AND T.PayRollType = P.PayRollType)))
					
					),0)


				
		END

		IF @tipocond = 'C'
		Begin
			set @importecond = ISNULL((SELECT 
				isnull(ConceptValueLo,conceptvalue)
			FROM
				PR_EmployeePayRollConcept EC
			WHERE
				Company = @cia and PRPeriod = @period and Person = @person and PayRollType = @payrolltype and ProcessType = @processtype and Concept = @conceptcond),0)

		End

	END
	
	delete from xx_valor
	
	set @query = ''
	
	declare @op varchar(10)




	Declare formula Cursor For
		select PR_FormulaDetail.Tipo,Operador,PR_FormulaDetail.Concept,grupo, valor, parameter,PR_FormulaDetail.process, periodoini, periodofin,numberini, numberfin, PR_FormulaDetail.TipoLiq, PR_FormulaDetail.ConceptList
		from PR_FormulaHeader inner join PR_FormulaDetail on (PR_FormulaHeader.FormulaHeader = PR_FormulaDetail.FormulaHeader) 
		where PR_FormulaHeader.Concept = @concept and PR_FormulaHeader.Payrolltype = @payrolltype and PR_FormulaHeader.Proccestype = @processtype
		and ((@pos > 0 and PR_FormulaDetail.line <= @pos) or (@pos = 0))
		order by line

		OPEN formula 
		FETCH NEXT FROM formula INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin, @TipoLiq, @conceptlist
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			
			set @op = case when @opera = 'M' then ' - ' else case when @opera = 'P' then ' + ' else case when @opera = 'X' then ' * ' else case when @opera = 'D' then ' / ' else case when @opera = 'T' then '' else '' end end end end end
			IF @tipo = 'A'
			BEGIN
				--print @conceptid
				--set @importe = ISNULL((select P.ConceptValue from
				--	PR_EmployeeConcept P INNER JOIN PR_Concept C  ON (P.Concept = C.Concept and P.Company = @cia and P.PayRollType = @payrolltype and P.Person = @person 
				--	and P.Concept = @conceptid)
				--where
				--	((FlagFrecuencyType = 'P' and PRPeriodStart <= @period) or (FlagFrecuencyType = 'T' and @period between PRPeriodStart and PRPeriodEnd))),0)

				set @importe = ISNULL((select P.ConceptValue from
					PR_EmployeeConcept P INNER JOIN PR_Concept C  ON (P.Concept = C.Concept and P.Company = @cia and P.PayRollType = @payrolltype and P.Person = @person 
					and P.Concept = @conceptid)
				where
					((FlagFrecuencyType = 'P' and PRPeriodStart <= @period) or (FlagFrecuencyType = 'T' and @period between PRPeriodStart and PRPeriodEnd))
					and (P.FlagFrecuencyType = 'T' or (P.FlagFrecuencyType = 'P' and P.PRPeriodStart = (select MAX(PRPeriodStart) from PR_EmployeeConcept T where 
					T.Company = P.Company and T.Person = P.Person AND T.Concept = P.Concept AND T.PayRollType = P.PayRollType)))
					
					),0)

					

				set @query =  @query + convert(varchar(20),@importe) + @op 

				
			END

			IF @tipo = 'P' /*PARAMETROS*/
			Begin
				set @importe = ISNULL((select case when ParameterTypeValue = 'N' then ParameterNumberValue else ParameterTextValue end from PR_Parameter where Company = @cia and Parameter = @parameter),0)
				

				set @query =  @query + convert(varchar(20),@importe) + @op 

			End

			IF @tipo = 'C'
			Begin
				
				set @importe = ISNULL((SELECT 
					isnull(ConceptValueLo,conceptvalue)
				FROM
				 PR_EmployeePayRollConcept EC
				WHERE
					Company = @cia and PRPeriod = @period and Person = @person and PayRollType = @payrolltype and ProcessType = @processtype and Concept = @conceptid),0)

				set @query =  @query + convert(varchar(20),@importe) + @op 
				
			End

			IF @tipo = 'S'
			Begin
			
				set @period_begin =   
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodoini = 'A' then @period else left(@period,4) + '0101' end)) + @numberini) 

				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + @numberfin)

				set @conceptlist = case
					when isnull(ltrim(rtrim(@conceptlist)), '') <> '' then ltrim(rtrim(@conceptlist))
					else @conceptid
				end
			
				set @importe = dbo.f_getSumaConceptosProceso(
					@cia, @person, @payrolltype, @process, @period_begin, @period_end, @conceptlist)
				
				set @query =  @query + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'G' set @query = @query + case when @grupo = 'O' then '(' else convert(varchar(20),0) + ')' end + @op

			IF @tipo = 'V' set @query = @query + convert(varchar(20),@numero) + @op

			IF @tipo = 'T'/*caso de las PROVISIONES*/ 
			BEGIN
				
				declare @fecanterior datetime
				declare @period_ant varchar(20)
				declare @process2 varchar(20)

				set @conceptcode = (select FormulaCode from PR_Concept where Company = @cia and Concept = @conceptid)
			
				set @period_ant = case when SUBSTRING(@period,5,2) = '01' then left(@period,4) + '0101' else  
									(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
									select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = @period) - 1) end

				set @fecanterior = case when @flag_cts = 'Y' then convert(datetime,left(@period,4)+'1031') else
									case when SUBSTRING(@period_ant,5,2) in ('04', '06', '09', '11') then convert(datetime,left(@period_ant,6)+'30') else convert(datetime,left(@period_ant,6)+'31') end end
				set @process2 = case when @flag_cts = 'Y' then (select ProcessType from PR_ProcessType where ShortName = 'FIN_DE_MES' and Company = @cia) else @processtype end
				if @TipoLiq = 'C' 
				begin
					if @flag_cts = 'Y'
					begin
						/* Pago CTS: lógica histórica por semestre may-oct / nov-abr */
						set @suma_total = case when @fecanterior >= convert(datetime,left(@period,4)+'0501') and  @fecanterior <= convert(datetime,left(@period,4)+'1031') then
										case when convert(date,@fechaingreso) >= convert(date,left(@period,4)+'0501') and convert(date,@fechaingreso) <= convert(date,left(@period,4)+'1031') then dbo.f_getSumaConceptoProceso(convert(date,@fechaingreso) ,convert(date,@fecanterior), @cia, @person, @conceptcode, @process2 ) else dbo.f_getSumaConceptoProceso(convert(date, left(@period,4)+'0501') ,convert(date,@fecanterior), @cia, @person, @conceptcode, @process2 ) end 
									else
										case when @fecanterior > convert(datetime,left(@period,4)+'1031') then
											case when  convert(date,@fechaingreso) > convert(datetime,left(@period,4)+'1031') then dbo.f_getSumaConceptoProceso(convert(date,@fechaingreso) ,convert(date,@fecanterior), @cia, @person, @conceptcode, @process2 ) else dbo.f_getSumaConceptoProceso(convert(date, left(@period,4) +'1101') ,convert(date,@fecanterior), @cia, @person, @conceptcode, @process2 ) end 
										else
											case when  convert(date,@fechaingreso) > convert(datetime,convert(char(4),convert(int,left(@period,4)) - 1)+'1031') then dbo.f_getSumaConceptoProceso(convert(date,@fechaingreso) ,convert(date,@fecanterior), @cia, @person, @conceptcode, @process2 ) else dbo.f_getSumaConceptoProceso(convert(date,convert(char(4),convert(int,left(@period,4)) - 1)+'1101') ,convert(date,@fecanterior), @cia, @person, @conceptcode, @process2 ) end 
										end
									end
					end
					else
					begin
						/*
							Provisión CTS mensual (SumaProv / TipoLiq C):
							- Ciclos: may-oct (inicio 01/05) y nov-abr (inicio 01/11).
							- Mayo o noviembre: provisión anterior = 0.
							- Meses siguientes: suma solo provisiones del ciclo hasta el mes anterior.
						*/
						declare @inicio_ciclo_cts date
						declare @fecha_fin_prov date
						declare @fecha_ini_prov date
						declare @mes_periodo int

						set @mes_periodo = convert(int, substring(@period, 5, 2))

						set @inicio_ciclo_cts = case
							when @mes_periodo between 5 and 10 then convert(date, left(@period, 4) + '0501')
							when @mes_periodo between 11 and 12 then convert(date, left(@period, 4) + '1101')
							else convert(date, convert(char(4), convert(int, left(@period, 4)) - 1) + '1101')
						end

						set @fecha_fin_prov = convert(date, @fecanterior)

						if @fecha_fin_prov < @inicio_ciclo_cts
							set @suma_total = 0
						else
						begin
							set @fecha_ini_prov = case
								when convert(date, @fechaingreso) > @inicio_ciclo_cts then convert(date, @fechaingreso)
								else @inicio_ciclo_cts
							end
							set @suma_total = dbo.f_getSumaConceptoProceso(
								@fecha_ini_prov, @fecha_fin_prov, @cia, @person, @conceptcode, @process2)
						end
					end
				end 
				if @TipoLiq = 'G'
				begin
					set @suma_total = case when MONTH (@fecanterior) < 7 then
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0101') then dbo.f_getSumaConceptoProceso(convert(date,@fechaingreso) ,convert(date,@fecanterior), @cia, @person, @conceptcode,@processtype ) else dbo.f_getSumaConceptoProceso(convert(date, left(@period,4) +'0101') ,convert(date,@fecanterior), @cia, @person, @conceptcode,@processtype ) end 
							else
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0701') then dbo.f_getSumaConceptoProceso(convert(date,@fechaingreso) ,convert(date,@fecanterior), @cia, @person, @conceptcode,@processtype ) else dbo.f_getSumaConceptoProceso(convert(date, left(@period,4) +'0701') ,convert(date,@fecanterior), @cia, @person, @conceptcode, @processtype ) end 
							end
				end
				if @TipoLiq = 'V'
				begin
					set @suma_total = dbo.f_getSumaConceptoProceso(convert(date,@fechaingreso) ,convert(date,@fecanterior), @cia, @person, @conceptcode,@processtype )
				end
		
				set @query =  @query + convert(varchar(20),@suma_total) + @op 
			END

			IF @tipo = 'X' 
			BEGIN
				set @conceptcode = (select FormulaCode from PR_Concept where Company = @cia and Concept = @conceptid)
			
				if @TipoLiq = 'C' 
				begin
				
					set @suma_total = case when @ceasedate >= convert(datetime,left(@period,4)+'0501') and  @ceasedate <= convert(datetime,left(@period,4)+'1031') then
									case when convert(date,@fechaingreso) >= convert(date,left(@period,4)+'0501') and convert(date,@fechaingreso) <= convert(date,left(@period,4)+'1031') then dbo.f_getSumaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate), @cia, @person, @conceptcode ) else dbo.f_getSumaConcepto(convert(date, left(@period,4)+'0501') ,convert(date,@ceasedate), @cia, @person, @conceptcode ) end 
								else
									case when @ceasedate > convert(datetime,left(@period,4)+'1031') then
										case when  convert(date,@fechaingreso) > convert(datetime,left(@period,4)+'1031') then dbo.f_getSumaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate), @cia, @person, @conceptcode ) else dbo.f_getSumaConcepto(convert(date, left(@period,4) +'1101') ,convert(date,@ceasedate), @cia, @person, @conceptcode ) end 
									else
										case when  convert(date,@fechaingreso) > convert(datetime,convert(char(4),convert(int,left(@period,4)) - 1)+'1031') then dbo.f_getSumaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate), @cia, @person, @conceptcode ) else dbo.f_getSumaConcepto(convert(date,convert(char(4),convert(int,left(@period,4)) - 1)+'1101') ,convert(date,@ceasedate), @cia, @person, @conceptcode ) end 
									end
								end
				end 
				if @TipoLiq = 'G'
				begin
					set @suma_total = case when MONTH (@ceasedate) < 7 then
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0101') then dbo.f_getSumaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate), @cia, @person, @conceptcode ) else dbo.f_getSumaConcepto(convert(date, left(@period,4) +'0101') ,convert(date,@ceasedate), @cia, @person, @conceptcode ) end 
							else
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0701') then dbo.f_getSumaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate), @cia, @person, @conceptcode ) else dbo.f_getSumaConcepto(convert(date, left(@period,4) +'0701') ,convert(date,@ceasedate), @cia, @person, @conceptcode ) end 
							end
				end
				if @TipoLiq = 'V'
				begin
					set @suma_total = dbo.f_getSumaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate), @cia, @person, @conceptcode )
				end
				set @query =  @query + convert(varchar(20),@suma_total) + @op 
			END

			IF @tipo = 'Y' 
			BEGIN
				declare @ceasedate3 datetime
				set @ceasedate3 = case when @flag_cts = 'Y' then convert(datetime,left(@period,4)+'1031') else @ceasedate end

				set @conceptcode = (select FormulaCode from PR_Concept where Company = @cia and Concept = @conceptid)
			
				if @TipoLiq = 'C' 
				begin
				
					set @cuenta_total = case when @ceasedate3 >= convert(datetime,left(@period,4)+'0501') and  @ceasedate3 <= convert(datetime,left(@period,4)+'1031') then
									case when convert(date,@fechaingreso) >= convert(date,left(@period,4)+'0501') and convert(date,@fechaingreso) <= convert(date,left(@period,4)+'1031') then dbo.f_getCuentaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate3), @cia, @person, @conceptcode ) else dbo.f_getCuentaConcepto(convert(date, left(@period,4)+'0501') ,convert(date,@ceasedate3), @cia, @person, @conceptcode ) end 
								else
									case when @ceasedate3 > convert(datetime,left(@period,4)+'1031') then
										case when  convert(date,@fechaingreso) > convert(datetime,left(@period,4)+'1031') then dbo.f_getCuentaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate3), @cia, @person, @conceptcode ) else dbo.f_getCuentaConcepto(convert(date, left(@period,4) +'1101') ,convert(date,@ceasedate3), @cia, @person, @conceptcode ) end 
									else
										case when  convert(date,@fechaingreso) > convert(datetime,convert(char(4),convert(int,left(@period,4)) - 1)+'1031') then dbo.f_getCuentaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate3), @cia, @person, @conceptcode ) else dbo.f_getCuentaConcepto(convert(date,convert(char(4),convert(int,left(@period,4)) - 1)+'1101') ,convert(date,@ceasedate3), @cia, @person, @conceptcode ) end 
									end
								end
				end 
				if @TipoLiq = 'G'
				begin
					set @cuenta_total = case when MONTH (@ceasedate) < 7 then
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0101') then dbo.f_getCuentaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate), @cia, @person, @conceptcode ) else dbo.f_getCuentaConcepto(convert(date, left(@period,4) +'0101') ,convert(date,@ceasedate), @cia, @person, @conceptcode ) end 
							else
								case when convert(date,@fechaingreso) > convert(date, left(@period,4) +'0701') then dbo.f_getCuentaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate), @cia, @person, @conceptcode ) else dbo.f_getCuentaConcepto(convert(date, left(@period,4) +'0701') ,convert(date,@ceasedate), @cia, @person, @conceptcode ) end 
							end
				end
				if @TipoLiq = 'V'
				begin
					set @cuenta_total = dbo.f_getCuentaConcepto(convert(date,@fechaingreso) ,convert(date,@ceasedate), @cia, @person, @conceptcode )
				end
				set @query =  @query + convert(varchar(20),@cuenta_total) + @op 
			END

			IF @tipo = 'Z'
			Begin

				set @period_begin =   
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodoini = 'A' then @period else left(@period,4) + '0101' end)) + @numberini) 

				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + @numberfin)

				set @importe = ISNULL((select count(*) from ((select distinct PRPeriod from PR_EmployeePayRollConcept where Company = @cia and PayRollType = @payrolltype and Person = @person
								and PRPeriod between @period_begin and @period_end 
								and ProcessType = @process and Concept = @conceptid)) T),0)

				set @query =  @query + convert(varchar(20),@importe) + @op 
			End


			
		FETCH NEXT FROM formula
	
		INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin, @TipoLiq, @conceptlist
		END 
		
		CLOSE formula
		DEALLOCATE formula
	
		

		/*SOLO EN CASO DE CONDICION ELSE*/
		set @query2 = ''

		Declare formula2 Cursor For
		select PR_FormulaDetail.Tipo,Operador,PR_FormulaDetail.Concept,grupo, valor, parameter,PR_FormulaDetail.process, periodoini, periodofin,numberini, numberfin, PR_FormulaDetail.ConceptList
		from PR_FormulaHeader inner join PR_FormulaDetail on (PR_FormulaHeader.FormulaHeader = PR_FormulaDetail.FormulaHeader) 
		where PR_FormulaHeader.Concept = @concept and PR_FormulaHeader.Payrolltype = @payrolltype and PR_FormulaHeader.Proccestype = @processtype
		and (@pos > 0 and PR_FormulaDetail.line > @pos)
		order by line
	
	
		OPEN formula2 
		FETCH NEXT FROM formula2 INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin, @conceptlist
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			
			set @op = case when @opera = 'M' then ' - ' else case when @opera = 'P' then ' + ' else case when @opera = 'X' then ' * ' else case when @opera = 'D' then ' / ' else '' end end end end
			IF @tipo = 'A'
			BEGIN
				--set @importe = ISNULL((select P.ConceptValue from
				--	PR_EmployeeConcept P INNER JOIN PR_Concept C  ON (P.Concept = C.Concept and P.Company = @cia and P.PayRollType = @payrolltype and P.Person = @person 
				--	and P.Concept = @conceptid)
				--where
				--	((FlagFrecuencyType = 'P' and PRPeriodStart <= @period) or (FlagFrecuencyType = 'T' and @period between PRPeriodStart and PRPeriodEnd))),0)

				set @importe = ISNULL((select P.ConceptValue from
					PR_EmployeeConcept P INNER JOIN PR_Concept C  ON (P.Concept = C.Concept and P.Company = @cia and P.PayRollType = @payrolltype and P.Person = @person 
					and P.Concept = @conceptid)
				where
					((FlagFrecuencyType = 'P' and PRPeriodStart <= @period) or (FlagFrecuencyType = 'T' and @period between PRPeriodStart and PRPeriodEnd))
					and (P.FlagFrecuencyType = 'T' or (P.FlagFrecuencyType = 'P' and P.PRPeriodStart = (select MAX(PRPeriodStart) from PR_EmployeeConcept T where 
					T.Company = P.Company and T.Person = P.Person AND T.Concept = P.Concept AND T.PayRollType = P.PayRollType)))
					
					),0)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 

				
			END

			IF @tipo = 'P' /*PARAMETROS*/
			Begin
				set @importe = ISNULL((select case when ParameterTypeValue = 'N' then ParameterNumberValue else ParameterTextValue end from PR_Parameter where Company = @cia and Parameter = @parameter),0)
				

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 

			End

			IF @tipo = 'C'
			Begin
				
				set @importe = ISNULL((SELECT 
					isnull(ConceptValueLo,conceptvalue)
				FROM
				 PR_EmployeePayRollConcept EC
				WHERE
					Company = @cia and PRPeriod = @period and Person = @person and PayRollType = @payrolltype and ProcessType = @processtype and Concept = @conceptid),0)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 
				
			End

			IF @tipo = 'S'
			Begin

				set @period_begin =   
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodoini = 'A' then @period else left(@period,4) + '0101' end)) + @numberini) 

				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + @numberfin)

				set @conceptlist = case
					when isnull(ltrim(rtrim(@conceptlist)), '') <> '' then ltrim(rtrim(@conceptlist))
					else @conceptid
				end

				set @importe = dbo.f_getSumaConceptosProceso(
					@cia, @person, @payrolltype, @process, @period_begin, @period_end, @conceptlist)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'G' set @query2 = @query2 + case when @grupo = 'O' then '(' else convert(varchar(20),0) + ')' end + @op

			IF @tipo = 'V' set @query2 = @query2 + convert(varchar(20),@numero) + @op

			
		FETCH NEXT FROM formula2
	
		INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin, @conceptlist
		END 
		
		CLOSE formula2
		DEALLOCATE formula2
		/*FIN SOLO EN CASO DE CONDICION ELSE*/
		

		IF LEN(ISNULL(@query,'')) > 0  set @query1  = 'insert into xx_valor(valor) select '  + @query 
	
		--if (ISNULL(@tipocond, 'N') = 'N') or (ISNULL(@tipocond, 'N') IN ('A', 'C') and ISNULL(@importecond,0) > 0) execute( @query1 )

		if (ISNULL(@tipocond, 'N') = 'N')
		begin
	
			execute( @query1 )
		end
		else
		begin
			if ISNULL(@importecond,0) >= 1
			begin
				execute( @query1 )
			end
			else
			begin
				set @query1  = 'insert into xx_valor(valor) select '  + @query2 
				if len(@query2) > 0 execute( @query1 )
			end
		end

		--print @query1
		if @flagtruncate = 'Y' update xx_valor set valor = round(valor,0,1)
END


--SELECT * FROM PR_PAYROLLTYPE

--select PRPeriod from PR_Period where Company = 'BGT' and PayRollType = 'LIMABGT 000000000005' and PeriodOrder = (
--					select PeriodOrder from PR_Period where Company = 'BGT' and PayRollType = 'LIMABGT 000000000005' and PRPeriod = (case when 'A' = 'A' then '20250808' else '2025' + '0101' end)) -2


--select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
--					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then '20250808' else left('2025',4) + '0101' end)) - 2

--					SELECT * from PR_FormulaHeader WHERE Concept = 'LIMABGT 000000000428'
--					select * FROM PR_Concept WHERE FormulaCode = 'Y'
--					SELect * from PR_ProcessType
--					select * from PR_FormulaDetail where FormulaHeader = 'LIMABGT 000000000811'