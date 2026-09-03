

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
	declare @query varchar(max), @query1 varchar(max), @query2 varchar(max), @process varchar(20), @period_ini varchar(20), @period_begin varchar(20), @period_end varchar(20)
	declare @concept varchar(20), @conceptcond varchar(20), @tipocond char(1), @periodoini varchar(20), @periodofin varchar(20), @formulaid varchar(20)
	declare @ceasedate datetime, @fechaingreso datetime
	declare @conceptcode varchar(50), @flag_cts char(1), @conceptlist varchar(500), @divisor numeric(19,4)
	declare @compiledexpr nvarchar(max), @expr_k nvarchar(max), @ph nvarchar(200), @code_k varchar(80), @p1 int, @p2 int
	declare @sp_name varchar(128), @sp_nargs int, @sp_arg1 numeric(19,4), @sp_arg2 numeric(19,4), @sp_arg3 numeric(19,4)
	declare @sp_out numeric(19,4), @sp_seg nvarchar(max), @sp_pend int, @p1_start int

	set @flag_cts = case when isnull((select ShortName from pr_processtype where ProcessType = @processtype),'') = 'CTS' then 'Y' else 'N' end 
	

	set @concept = (select  Concept from PR_Concept where Company = @cia and FormulaCode = @formulacode)
	set @pos = 0
	SET @tipocond = 'N'

	/* Una sola cabecera: si hay duplicados por Concept/planilla/proceso, usa la más reciente. */
	select TOP 1
		@tipocond = ISNULL(Tipo, 'N'),
		@conceptcond = ISNULL(Conceptcond,''),
		@flagtruncate = isnull(flagtruncate, 'N'),
		@formulaid = FormulaHeader
	from PR_FormulaHeader
	where PR_FormulaHeader.Concept = @concept
	  and Payrolltype = @payrolltype
	  and Proccestype = @processtype
	order by ISNULL(XLastDate, '19000101') DESC, FormulaHeader DESC

	if @formulaid is null
	begin
		/* Sin fórmula: xx_valor queda vacío (comportamiento previo al no encontrar cabecera). */
		return
	end

	/*
	  #empleado suele existir ya en sp_pr_calcular_*_persona (mismos campos AFP).
	  Si se recrea aquí con SELECT INTO, falla al anidar o choca con columnas
	  distintas (p.ej. CeaseDate). Reutilizar si existe; crear solo si falta.
	*/
	IF OBJECT_ID('tempdb..#empleado') IS NULL
	BEGIN
		SELECT
			ISNULL(reentrydate, entrydate) AS fechaingreso,
			PR_PensionType.PDT AS pension,
			PR_AFP.PensionPercentage AS porc_aporte,
			variablepercentage AS porc_comision_flu,
			topafp,
			insuredpercentage AS porc_seguro,
			PR_Employee.CeaseDate AS CeaseDate
		INTO #empleado
		FROM PR_Employee
		INNER JOIN PR_PensionType
			ON PR_Employee.PensionType = PR_PensionType.PensionType
			AND PR_PensionType.Company = @cia
		LEFT JOIN PR_AFP
			ON PR_Employee.AFP = PR_AFP.afp
			AND PR_AFP.Company = @cia
		WHERE Person = @person
		  AND PR_Employee.company = @cia
	END

	/* CeaseDate no siempre está en #empleado del SP de cálculo */
	SET @ceasedate = (
		SELECT CeaseDate
		FROM PR_Employee
		WHERE Person = @person AND Company = @cia
	)
	SET @fechaingreso = (SELECT fechaingreso FROM #empleado)
	

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
					T.Company = P.Company and T.Person = P.Person AND T.Concept = P.Concept AND T.PayRollType = P.PayRollType AND T.FlagFrecuencyType = 'P')
					and not exists (select 1 from PR_EmployeeConcept TT where TT.Company = P.Company and TT.Person = P.Person and TT.Concept = P.Concept and TT.PayRollType = P.PayRollType and TT.FlagFrecuencyType = 'T' and @period between TT.PRPeriodStart and TT.PRPeriodEnd)))
					
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
		select PR_FormulaDetail.Tipo,Operador,PR_FormulaDetail.Concept,grupo, valor, parameter,PR_FormulaDetail.process, periodoini, periodofin,numberini, numberfin, PR_FormulaDetail.TipoLiq, PR_FormulaDetail.ConceptList, PR_FormulaDetail.Divisor, PR_FormulaDetail.CompiledExpr
		from PR_FormulaHeader inner join PR_FormulaDetail on (PR_FormulaHeader.FormulaHeader = PR_FormulaDetail.FormulaHeader) 
		where PR_FormulaHeader.FormulaHeader = @formulaid
		and ((@pos > 0 and PR_FormulaDetail.line <= @pos) or (@pos = 0))
		order by line

		OPEN formula 
		FETCH NEXT FROM formula INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin, @TipoLiq, @conceptlist, @divisor, @compiledexpr
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			
			set @op = case when @opera = 'M' then ' - ' else case when @opera = 'P' then ' + ' else case when @opera = 'X' then ' * ' else case when @opera = 'D' then ' / ' else case when @opera = 'T' then '' else '' end end end end end
			IF @tipo = 'K' /* Código condicional compilado al guardar */
			BEGIN
				SET @expr_k = ISNULL(@compiledexpr, N'')
				WHILE CHARINDEX(N'#C:', @expr_k) > 0
				BEGIN
					SET @p1 = CHARINDEX(N'#C:', @expr_k)
					SET @p2 = CHARINDEX(N'#', @expr_k, @p1 + 3)
					IF @p2 <= 0 BREAK
					SET @code_k = UPPER(LTRIM(RTRIM(SUBSTRING(@expr_k, @p1 + 3, @p2 - @p1 - 3))))
					SET @importe = ISNULL((
						SELECT TOP 1 ISNULL(EC.ConceptValueLo, EC.ConceptValue)
						FROM PR_EmployeePayRollConcept EC
						INNER JOIN PR_Concept C ON C.Concept = EC.Concept AND C.Company = @cia
						WHERE EC.Company = @cia AND EC.PRPeriod = @period AND EC.Person = @person
						  AND EC.PayRollType = @payrolltype AND EC.ProcessType = @processtype
						  AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = @code_k
					), 0)
					SET @ph = SUBSTRING(@expr_k, @p1, @p2 - @p1 + 1)
					SET @expr_k = STUFF(@expr_k, @p1, LEN(@ph), CONVERT(NVARCHAR(40), @importe))
				END
				WHILE CHARINDEX(N'#P:', @expr_k) > 0
				BEGIN
					SET @p1 = CHARINDEX(N'#P:', @expr_k)
					SET @p2 = CHARINDEX(N'#', @expr_k, @p1 + 3)
					IF @p2 <= 0 BREAK
					SET @code_k = UPPER(LTRIM(RTRIM(SUBSTRING(@expr_k, @p1 + 3, @p2 - @p1 - 3))))
					SET @importe = ISNULL((
						SELECT TOP 1 CASE
							WHEN ParameterTypeValue = 'N' THEN ParameterNumberValue
							WHEN ISNUMERIC(ParameterTextValue) = 1 THEN CONVERT(NUMERIC(19,4), ParameterTextValue)
							ELSE 0
						END
						FROM PR_Parameter
						WHERE Company = @cia AND UPPER(LTRIM(RTRIM(ISNULL(ShortName, '')))) = @code_k
					), 0)
					SET @ph = SUBSTRING(@expr_k, @p1, @p2 - @p1 + 1)
					SET @expr_k = STUFF(@expr_k, @p1, LEN(@ph), CONVERT(NVARCHAR(40), ISNULL(@importe, 0)))
				END
				WHILE CHARINDEX(N'#A:', @expr_k) > 0
				BEGIN
					SET @p1 = CHARINDEX(N'#A:', @expr_k)
					SET @p2 = CHARINDEX(N'#', @expr_k, @p1 + 3)
					IF @p2 <= 0 BREAK
					SET @code_k = UPPER(LTRIM(RTRIM(SUBSTRING(@expr_k, @p1 + 3, @p2 - @p1 - 3))))
					SET @importe = ISNULL((
						SELECT TOP 1 P.ConceptValue
						FROM PR_EmployeeConcept P
						INNER JOIN PR_Concept C ON C.Concept = P.Concept AND C.Company = @cia
						WHERE P.Company = @cia AND P.PayRollType = @payrolltype AND P.Person = @person
						  AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = @code_k
						  AND ((FlagFrecuencyType = 'P' AND PRPeriodStart <= @period) OR (FlagFrecuencyType = 'T' AND @period BETWEEN PRPeriodStart AND PRPeriodEnd))
						  AND (P.FlagFrecuencyType = 'T' OR (P.FlagFrecuencyType = 'P' AND P.PRPeriodStart = (
								SELECT MAX(T.PRPeriodStart) FROM PR_EmployeeConcept T
								WHERE T.Company = P.Company AND T.Person = P.Person AND T.Concept = P.Concept
								  AND T.PayRollType = P.PayRollType AND T.FlagFrecuencyType = 'P')))
					), 0)
					SET @ph = SUBSTRING(@expr_k, @p1, @p2 - @p1 + 1)
					SET @expr_k = STUFF(@expr_k, @p1, LEN(@ph), CONVERT(NVARCHAR(40), ISNULL(@importe, 0)))
				END
				/* Datos del trabajador (#empleado): EMPLOYEE("PENSION"|"TOPAFP"|"PORC_SEGURO"|...) */
				WHILE CHARINDEX(N'#E:', @expr_k) > 0
				BEGIN
					SET @p1 = CHARINDEX(N'#E:', @expr_k)
					SET @p2 = CHARINDEX(N'#', @expr_k, @p1 + 3)
					IF @p2 <= 0 BREAK
					SET @code_k = UPPER(LTRIM(RTRIM(SUBSTRING(@expr_k, @p1 + 3, @p2 - @p1 - 3))))
					SET @importe = ISNULL((
						SELECT TOP 1 CASE @code_k
							WHEN 'TOPAFP' THEN CONVERT(NUMERIC(19,4), ISNULL(topafp, 0))
							WHEN 'PORC_SEGURO' THEN CONVERT(NUMERIC(19,4), ISNULL(porc_seguro, 0))
							WHEN 'PORC_APORTE' THEN CONVERT(NUMERIC(19,4), ISNULL(porc_aporte, 0))
							WHEN 'PORC_COMISION_FLU' THEN CONVERT(NUMERIC(19,4), ISNULL(porc_comision_flu, 0))
							WHEN 'PENSION' THEN CASE
								WHEN ISNUMERIC(LTRIM(RTRIM(ISNULL(pension, '')))) = 1
								THEN CONVERT(NUMERIC(19,4), LTRIM(RTRIM(pension)))
								ELSE 0 END
							ELSE 0
						END
						FROM #empleado
					), 0)
					SET @ph = SUBSTRING(@expr_k, @p1, @p2 - @p1 + 1)
					SET @expr_k = STUFF(@expr_k, @p1, LEN(@ph), CONVERT(NVARCHAR(40), ISNULL(@importe, 0)))
				END
				/* PROC("SP...") compilado como #S:NOMBRE|N|args|# */
				WHILE CHARINDEX(N'#S:', @expr_k) > 0
				BEGIN
					SET @p1_start = CHARINDEX(N'#S:', @expr_k)
					SET @p1 = @p1_start + 3
					SET @p2 = CHARINDEX(N'|', @expr_k, @p1)
					IF @p2 <= 0 BREAK
					SET @sp_name = SUBSTRING(@expr_k, @p1, @p2 - @p1)
					SET @p1 = @p2 + 1
					SET @p2 = CHARINDEX(N'|', @expr_k, @p1)
					IF @p2 <= 0 BREAK
					SET @sp_nargs = CONVERT(int, SUBSTRING(@expr_k, @p1, @p2 - @p1))
					SET @sp_arg1 = 0
					SET @sp_arg2 = 0
					SET @sp_arg3 = 0
					SET @p1 = @p2 + 1
					IF @sp_nargs >= 1
					BEGIN
						SET @p2 = CHARINDEX(N'|', @expr_k, @p1)
						IF @p2 <= 0 BREAK
						SET @sp_seg = SUBSTRING(@expr_k, @p1, @p2 - @p1)
						SET @sp_arg1 = CONVERT(NUMERIC(19,4), @sp_seg)
						SET @p1 = @p2 + 1
					END
					IF @sp_nargs >= 2
					BEGIN
						SET @p2 = CHARINDEX(N'|', @expr_k, @p1)
						IF @p2 <= 0 BREAK
						SET @sp_seg = SUBSTRING(@expr_k, @p1, @p2 - @p1)
						SET @sp_arg2 = CONVERT(NUMERIC(19,4), @sp_seg)
						SET @p1 = @p2 + 1
					END
					IF @sp_nargs >= 3
					BEGIN
						SET @p2 = CHARINDEX(N'|#', @expr_k, @p1)
						IF @p2 <= 0 BREAK
						SET @sp_seg = SUBSTRING(@expr_k, @p1, @p2 - @p1)
						SET @sp_arg3 = CONVERT(NUMERIC(19,4), @sp_seg)
					END
					SET @sp_pend = CHARINDEX(N'|#', @expr_k, @p1_start)
					IF @sp_pend <= 0 BREAK
					SET @ph = SUBSTRING(@expr_k, @p1_start, @sp_pend + 2 - @p1_start)
					SET @sp_out = 0
					IF OBJECT_ID('dbo.sp_pr_formula_exec_proc_web', 'P') IS NOT NULL
					BEGIN
						EXEC dbo.sp_pr_formula_exec_proc_web
							@procname = @sp_name,
							@nargs = @sp_nargs,
							@arg1 = @sp_arg1,
							@arg2 = @sp_arg2,
							@arg3 = @sp_arg3,
							@cia = @cia,
							@period = @period,
							@payrolltype = @payrolltype,
							@processtype = @processtype,
							@person = @person,
							@result = @sp_out OUTPUT
					END
					SET @expr_k = STUFF(@expr_k, @p1_start, LEN(@ph), CONVERT(NVARCHAR(40), ISNULL(@sp_out, 0)))
				END
				SET @query = @query + CONVERT(VARCHAR(MAX), @expr_k) + @op
			END
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
					T.Company = P.Company and T.Person = P.Person AND T.Concept = P.Concept AND T.PayRollType = P.PayRollType AND T.FlagFrecuencyType = 'P')
					and not exists (select 1 from PR_EmployeeConcept TT where TT.Company = P.Company and TT.Person = P.Person and TT.Concept = P.Concept and TT.PayRollType = P.PayRollType and TT.FlagFrecuencyType = 'T' and @period between TT.PRPeriodStart and TT.PRPeriodEnd)))
					
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
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodoini = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberini, 0)) 

				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @conceptlist = case
					when isnull(ltrim(rtrim(@conceptlist)), '') <> '' then ltrim(rtrim(@conceptlist))
					else @conceptid
				end
			
				set @importe = dbo.f_getSumaConceptosProceso(
					@cia, @person, @payrolltype, @process, @period_begin, @period_end, @conceptlist)
				
				set @query =  @query + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'I'
			Begin
				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getSumaConceptosIngreso(
					@cia, @person, @payrolltype, @process, @period_end, @conceptid, @fechaingreso)

				set @query =  @query + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'B'
			Begin
				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getSumaConceptosCTS(
					@cia, @person, @payrolltype, @process, @period, @period_end, @conceptid)

				set @query =  @query + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'R'
			Begin
				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getSumaConceptosGrati(
					@cia, @person, @payrolltype, @process, @period, @period_end, @conceptid)

				set @query =  @query + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'M'
			Begin
				set @period_begin =   
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodoini = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberini, 0)) 

				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getPromedioVac(
					@cia, @person, @payrolltype, @process, @period_begin, @period_end, @conceptid, @numero, @divisor, @fechaingreso)

				set @query =  @query + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'H'
			Begin
				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getPromedioGrati(
					@cia, @person, @payrolltype, @process, @period, @period_end, @conceptid, @numero, @divisor, @fechaingreso)

				set @query =  @query + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'U'
			Begin
				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getPromedioCts(
					@cia, @person, @payrolltype, @process, @period, @period_end, @conceptid, @numero, @divisor, @fechaingreso)

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
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodoini = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberini, 0)) 

				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = ISNULL((select count(*) from ((select distinct PRPeriod from PR_EmployeePayRollConcept where Company = @cia and PayRollType = @payrolltype and Person = @person
								and PRPeriod between @period_begin and @period_end 
								and ProcessType = @process and Concept = @conceptid)) T),0)

				set @query =  @query + convert(varchar(20),@importe) + @op 
			End


			
		FETCH NEXT FROM formula
	
		INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin, @TipoLiq, @conceptlist, @divisor, @compiledexpr
		END 
		
		CLOSE formula
		DEALLOCATE formula
	
		

		/*SOLO EN CASO DE CONDICION ELSE*/
		set @query2 = ''

		Declare formula2 Cursor For
		select PR_FormulaDetail.Tipo,Operador,PR_FormulaDetail.Concept,grupo, valor, parameter,PR_FormulaDetail.process, periodoini, periodofin,numberini, numberfin, PR_FormulaDetail.ConceptList, PR_FormulaDetail.Divisor, PR_FormulaDetail.CompiledExpr
		from PR_FormulaHeader inner join PR_FormulaDetail on (PR_FormulaHeader.FormulaHeader = PR_FormulaDetail.FormulaHeader) 
		where PR_FormulaHeader.Concept = @concept and PR_FormulaHeader.Payrolltype = @payrolltype and PR_FormulaHeader.Proccestype = @processtype
		and (@pos > 0 and PR_FormulaDetail.line > @pos)
		order by line
	
	
		OPEN formula2 
		FETCH NEXT FROM formula2 INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin, @conceptlist, @divisor, @compiledexpr
		WHILE @@FETCH_STATUS = 0 
		BEGIN 
			
			set @op = case when @opera = 'M' then ' - ' else case when @opera = 'P' then ' + ' else case when @opera = 'X' then ' * ' else case when @opera = 'D' then ' / ' else '' end end end end
			IF @tipo = 'K'
			BEGIN
				SET @expr_k = ISNULL(@compiledexpr, N'')
				WHILE CHARINDEX(N'#C:', @expr_k) > 0
				BEGIN
					SET @p1 = CHARINDEX(N'#C:', @expr_k)
					SET @p2 = CHARINDEX(N'#', @expr_k, @p1 + 3)
					IF @p2 <= 0 BREAK
					SET @code_k = UPPER(LTRIM(RTRIM(SUBSTRING(@expr_k, @p1 + 3, @p2 - @p1 - 3))))
					SET @importe = ISNULL((
						SELECT TOP 1 ISNULL(EC.ConceptValueLo, EC.ConceptValue)
						FROM PR_EmployeePayRollConcept EC
						INNER JOIN PR_Concept C ON C.Concept = EC.Concept AND C.Company = @cia
						WHERE EC.Company = @cia AND EC.PRPeriod = @period AND EC.Person = @person
						  AND EC.PayRollType = @payrolltype AND EC.ProcessType = @processtype
						  AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = @code_k
					), 0)
					SET @ph = SUBSTRING(@expr_k, @p1, @p2 - @p1 + 1)
					SET @expr_k = STUFF(@expr_k, @p1, LEN(@ph), CONVERT(NVARCHAR(40), @importe))
				END
				WHILE CHARINDEX(N'#P:', @expr_k) > 0
				BEGIN
					SET @p1 = CHARINDEX(N'#P:', @expr_k)
					SET @p2 = CHARINDEX(N'#', @expr_k, @p1 + 3)
					IF @p2 <= 0 BREAK
					SET @code_k = UPPER(LTRIM(RTRIM(ISNULL(SUBSTRING(@expr_k, @p1 + 3, @p2 - @p1 - 3), ''))))
					SET @importe = ISNULL((
						SELECT TOP 1 CASE
							WHEN ParameterTypeValue = 'N' THEN ParameterNumberValue
							WHEN ISNUMERIC(ParameterTextValue) = 1 THEN CONVERT(NUMERIC(19,4), ParameterTextValue)
							ELSE 0
						END
						FROM PR_Parameter
						WHERE Company = @cia AND UPPER(LTRIM(RTRIM(ISNULL(ShortName, '')))) = @code_k
					), 0)
					SET @ph = SUBSTRING(@expr_k, @p1, @p2 - @p1 + 1)
					SET @expr_k = STUFF(@expr_k, @p1, LEN(@ph), CONVERT(NVARCHAR(40), ISNULL(@importe, 0)))
				END
				WHILE CHARINDEX(N'#A:', @expr_k) > 0
				BEGIN
					SET @p1 = CHARINDEX(N'#A:', @expr_k)
					SET @p2 = CHARINDEX(N'#', @expr_k, @p1 + 3)
					IF @p2 <= 0 BREAK
					SET @code_k = UPPER(LTRIM(RTRIM(SUBSTRING(@expr_k, @p1 + 3, @p2 - @p1 - 3))))
					SET @importe = ISNULL((
						SELECT TOP 1 P.ConceptValue
						FROM PR_EmployeeConcept P
						INNER JOIN PR_Concept C ON C.Concept = P.Concept AND C.Company = @cia
						WHERE P.Company = @cia AND P.PayRollType = @payrolltype AND P.Person = @person
						  AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = @code_k
						  AND ((FlagFrecuencyType = 'P' AND PRPeriodStart <= @period) OR (FlagFrecuencyType = 'T' AND @period BETWEEN PRPeriodStart AND PRPeriodEnd))
						  AND (P.FlagFrecuencyType = 'T' OR (P.FlagFrecuencyType = 'P' AND P.PRPeriodStart = (
								SELECT MAX(T.PRPeriodStart) FROM PR_EmployeeConcept T
								WHERE T.Company = P.Company AND T.Person = P.Person AND T.Concept = P.Concept
								  AND T.PayRollType = P.PayRollType AND T.FlagFrecuencyType = 'P')))
					), 0)
					SET @ph = SUBSTRING(@expr_k, @p1, @p2 - @p1 + 1)
					SET @expr_k = STUFF(@expr_k, @p1, LEN(@ph), CONVERT(NVARCHAR(40), ISNULL(@importe, 0)))
				END
				/* Datos del trabajador (#empleado): EMPLOYEE("PENSION"|"TOPAFP"|"PORC_SEGURO"|...) */
				WHILE CHARINDEX(N'#E:', @expr_k) > 0
				BEGIN
					SET @p1 = CHARINDEX(N'#E:', @expr_k)
					SET @p2 = CHARINDEX(N'#', @expr_k, @p1 + 3)
					IF @p2 <= 0 BREAK
					SET @code_k = UPPER(LTRIM(RTRIM(SUBSTRING(@expr_k, @p1 + 3, @p2 - @p1 - 3))))
					SET @importe = ISNULL((
						SELECT TOP 1 CASE @code_k
							WHEN 'TOPAFP' THEN CONVERT(NUMERIC(19,4), ISNULL(topafp, 0))
							WHEN 'PORC_SEGURO' THEN CONVERT(NUMERIC(19,4), ISNULL(porc_seguro, 0))
							WHEN 'PORC_APORTE' THEN CONVERT(NUMERIC(19,4), ISNULL(porc_aporte, 0))
							WHEN 'PORC_COMISION_FLU' THEN CONVERT(NUMERIC(19,4), ISNULL(porc_comision_flu, 0))
							WHEN 'PENSION' THEN CASE
								WHEN ISNUMERIC(LTRIM(RTRIM(ISNULL(pension, '')))) = 1
								THEN CONVERT(NUMERIC(19,4), LTRIM(RTRIM(pension)))
								ELSE 0 END
							ELSE 0
						END
						FROM #empleado
					), 0)
					SET @ph = SUBSTRING(@expr_k, @p1, @p2 - @p1 + 1)
					SET @expr_k = STUFF(@expr_k, @p1, LEN(@ph), CONVERT(NVARCHAR(40), ISNULL(@importe, 0)))
				END
				/* PROC("SP...") compilado como #S:NOMBRE|N|args|# */
				WHILE CHARINDEX(N'#S:', @expr_k) > 0
				BEGIN
					SET @p1_start = CHARINDEX(N'#S:', @expr_k)
					SET @p1 = @p1_start + 3
					SET @p2 = CHARINDEX(N'|', @expr_k, @p1)
					IF @p2 <= 0 BREAK
					SET @sp_name = SUBSTRING(@expr_k, @p1, @p2 - @p1)
					SET @p1 = @p2 + 1
					SET @p2 = CHARINDEX(N'|', @expr_k, @p1)
					IF @p2 <= 0 BREAK
					SET @sp_nargs = CONVERT(int, SUBSTRING(@expr_k, @p1, @p2 - @p1))
					SET @sp_arg1 = 0
					SET @sp_arg2 = 0
					SET @sp_arg3 = 0
					SET @p1 = @p2 + 1
					IF @sp_nargs >= 1
					BEGIN
						SET @p2 = CHARINDEX(N'|', @expr_k, @p1)
						IF @p2 <= 0 BREAK
						SET @sp_seg = SUBSTRING(@expr_k, @p1, @p2 - @p1)
						SET @sp_arg1 = CONVERT(NUMERIC(19,4), @sp_seg)
						SET @p1 = @p2 + 1
					END
					IF @sp_nargs >= 2
					BEGIN
						SET @p2 = CHARINDEX(N'|', @expr_k, @p1)
						IF @p2 <= 0 BREAK
						SET @sp_seg = SUBSTRING(@expr_k, @p1, @p2 - @p1)
						SET @sp_arg2 = CONVERT(NUMERIC(19,4), @sp_seg)
						SET @p1 = @p2 + 1
					END
					IF @sp_nargs >= 3
					BEGIN
						SET @p2 = CHARINDEX(N'|#', @expr_k, @p1)
						IF @p2 <= 0 BREAK
						SET @sp_seg = SUBSTRING(@expr_k, @p1, @p2 - @p1)
						SET @sp_arg3 = CONVERT(NUMERIC(19,4), @sp_seg)
					END
					SET @sp_pend = CHARINDEX(N'|#', @expr_k, @p1_start)
					IF @sp_pend <= 0 BREAK
					SET @ph = SUBSTRING(@expr_k, @p1_start, @sp_pend + 2 - @p1_start)
					SET @sp_out = 0
					IF OBJECT_ID('dbo.sp_pr_formula_exec_proc_web', 'P') IS NOT NULL
					BEGIN
						EXEC dbo.sp_pr_formula_exec_proc_web
							@procname = @sp_name,
							@nargs = @sp_nargs,
							@arg1 = @sp_arg1,
							@arg2 = @sp_arg2,
							@arg3 = @sp_arg3,
							@cia = @cia,
							@period = @period,
							@payrolltype = @payrolltype,
							@processtype = @processtype,
							@person = @person,
							@result = @sp_out OUTPUT
					END
					SET @expr_k = STUFF(@expr_k, @p1_start, LEN(@ph), CONVERT(NVARCHAR(40), ISNULL(@sp_out, 0)))
				END
				SET @query2 = @query2 + CONVERT(VARCHAR(MAX), @expr_k) + @op
			END
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
					T.Company = P.Company and T.Person = P.Person AND T.Concept = P.Concept AND T.PayRollType = P.PayRollType AND T.FlagFrecuencyType = 'P')
					and not exists (select 1 from PR_EmployeeConcept TT where TT.Company = P.Company and TT.Person = P.Person and TT.Concept = P.Concept and TT.PayRollType = P.PayRollType and TT.FlagFrecuencyType = 'T' and @period between TT.PRPeriodStart and TT.PRPeriodEnd)))
					
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
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodoini = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberini, 0)) 

				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @conceptlist = case
					when isnull(ltrim(rtrim(@conceptlist)), '') <> '' then ltrim(rtrim(@conceptlist))
					else @conceptid
				end

				set @importe = dbo.f_getSumaConceptosProceso(
					@cia, @person, @payrolltype, @process, @period_begin, @period_end, @conceptlist)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'I'
			Begin
				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getSumaConceptosIngreso(
					@cia, @person, @payrolltype, @process, @period_end, @conceptid, @fechaingreso)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'B'
			Begin
				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getSumaConceptosCTS(
					@cia, @person, @payrolltype, @process, @period, @period_end, @conceptid)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'R'
			Begin
				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getSumaConceptosGrati(
					@cia, @person, @payrolltype, @process, @period, @period_end, @conceptid)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'M'
			Begin
				set @period_begin =   
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodoini = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberini, 0)) 

				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getPromedioVac(
					@cia, @person, @payrolltype, @process, @period_begin, @period_end, @conceptid, @numero, @divisor, @fechaingreso)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'H'
			Begin
				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getPromedioGrati(
					@cia, @person, @payrolltype, @process, @period, @period_end, @conceptid, @numero, @divisor, @fechaingreso)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'U'
			Begin
				set @period_end = 
					(select PRPeriod from PR_Period where Company = @cia and PayRollType = @payrolltype and PeriodOrder = (
					select PeriodOrder from PR_Period where Company = @cia and PayRollType = @payrolltype and PRPeriod = (case when @periodofin = 'A' then @period else left(@period,4) + '0101' end)) + ISNULL(@numberfin, 0))

				set @importe = dbo.f_getPromedioCts(
					@cia, @person, @payrolltype, @process, @period, @period_end, @conceptid, @numero, @divisor, @fechaingreso)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'G' set @query2 = @query2 + case when @grupo = 'O' then '(' else convert(varchar(20),0) + ')' end + @op

			IF @tipo = 'V' set @query2 = @query2 + convert(varchar(20),@numero) + @op

			
		FETCH NEXT FROM formula2
	
		INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin, @conceptlist, @divisor, @compiledexpr
		END 
		
		CLOSE formula2
		DEALLOCATE formula2
		/*FIN SOLO EN CASO DE CONDICION ELSE*/
		

		IF LEN(ISNULL(@query, '')) >= 3 AND RIGHT(@query, 3) IN (' + ', ' - ', ' * ', ' / ')
			SET @query = LEFT(@query, LEN(@query) - 3)

		IF LEN(ISNULL(@query2, '')) >= 3 AND RIGHT(@query2, 3) IN (' + ', ' - ', ' * ', ' / ')
			SET @query2 = LEFT(@query2, LEN(@query2) - 3)

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