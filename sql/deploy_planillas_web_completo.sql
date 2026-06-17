/*
  DEPLOY COMPLETO - Sistema Planillas Web
  Generado: 2026-06-17 15:49
  Origen: carpeta sql/ del repositorio sistema-planillas-web

  Uso: ejecutar en SQL Server Management Studio (o sqlcmd) sobre la base destino.
  Requisitos: SQL Server 2016 SP1+ (CREATE OR ALTER PROCEDURE).

  Orden:
    1. Scripts ALTER (columnas/tablas)
    2. SP_PR_EjecutarFormula (motor de formulas legacy, si aplica)
    3. Stored procedures web (_web)

  NOTA: algunos SP usados por app.py no estan en sql/ (ya existen en ERP):
    sp_pr_selectorpersonas_web, sp_pr_selectortipos_dm_web,
    sp_pr_selectorperiodos_asig_web

  Tablas de trabajo requeridas por algunos reportes:
    xx_plamevertical2, xx_reporteplanilla (reporte planilla vertical)

  Archivos incluidos (89):
    - alter_pr_mapping_add_banbifbank.sql
    - alter_pr_processtype_add_procedurename.sql
    - alter_sy_company_add_logoname_signaturename.sql
    - tables_pr_plame_sunat_web.sql
    - SP_PR_EjecutarFormula.sql
    - SP_PR_ReportePromedioLiquidacion.sql
    - sp_pr_actualizar_bancario_trabajador_web.sql
    - sp_pr_actualizar_datos_afp_web.sql
    - sp_pr_actualizar_pensiones_trabajador_web.sql
    - sp_pr_aperturarperiodo_proceso_web.sql
    - sp_pr_calcular_provcts_persona.sql
    - sp_pr_calcularplanillas_web.sql
    - sp_pr_cerrarperiodo_proceso_web.sql
    - sp_pr_control_pagos_afp_web.sql
    - sp_pr_datosusuario_web.sql
    - sp_pr_detalleboletaaportes_web.sql
    - sp_pr_detalleboletadescuentos_web.sql
    - sp_pr_detalleboletaingresos_web.sql
    - sp_pr_eliminar_calculo_planilla_web.sql
    - sp_pr_eliminarasignacionconcepto_web.sql
    - sp_pr_eliminarconcepto_web.sql
    - sp_pr_genera_correlativo_web.sql
    - sp_pr_generar_banbif_web.sql
    - sp_pr_generar_continental_web.sql
    - sp_pr_generar_interbank_web.sql
    - sp_pr_generar_telecredito_web.sql
    - sp_pr_generarboleta_web.sql
    - sp_pr_guardarasignacionconcepto_web.sql
    - sp_pr_guardarconcepto_web.sql
    - sp_pr_listaasignacionconceptos_web.sql
    - sp_pr_listabanbif_web.sql
    - sp_pr_listacontinental_web.sql
    - sp_pr_listado_declaracion_afp_web.sql
    - sp_pr_listado_plame14_web.sql
    - sp_pr_listado_plame15_web.sql
    - sp_pr_listado_plame18_web.sql
    - sp_pr_listado_plame26_web.sql
    - sp_pr_listadogenerarboletas_web.sql
    - sp_pr_listainterbank_web.sql
    - sp_pr_listaprocesscontrol_apertura_web.sql
    - sp_pr_listarconceptos_web.sql
    - sp_pr_listatelecredito_web.sql
    - sp_pr_listatrabajadores_web.sql
    - sp_pr_obtener_bancario_trabajador_web.sql
    - sp_pr_obtener_pensiones_trabajador_web.sql
    - sp_pr_obtenerasignacionconcepto_web.sql
    - sp_pr_obtenerconcepto_web.sql
    - sp_pr_plame_sunat_eliminar_carga_web.sql
    - sp_pr_plame_sunat_obtener_carga_web.sql
    - sp_pr_plame_validar_archivo14_web.sql
    - sp_pr_plame_validar_archivo18_web.sql
    - sp_pr_plame_validar_neto_r01_web.sql
    - sp_pr_plame_validar_r04_web.sql
    - sp_pr_plame_validar_r05_web.sql
    - sp_pr_r019_vacationdetail_web.sql
    - sp_pr_reportelistadopagos_web.sql
    - sp_pr_reportelog_calculo_web.sql
    - sp_pr_reporteplame_total_web.sql
    - sp_pr_reporteplamevertical_web.sql
    - sp_pr_reportesdescansos_medicos_web.sql
    - sp_pr_resumen_declaracion_afp_web.sql
    - sp_pr_saldovacaciones_web.sql
    - sp_pr_selectorafp_web.sql
    - sp_pr_selectorbancos_web.sql
    - sp_pr_selectorcompanias_web.sql
    - sp_pr_selectorconceptoneto_web.sql
    - sp_pr_selectorconceptos_web.sql
    - sp_pr_selectorconcepttype_web.sql
    - sp_pr_selectorformapago_web.sql
    - sp_pr_selectorpensiontype_web.sql
    - sp_pr_selectorperiodoactivo_planilla_web.sql
    - sp_pr_selectorperiodoactivo_web.sql
    - sp_pr_selectorperiodocalculo_web.sql
    - sp_pr_selectorperiodos_apertura_web.sql
    - sp_pr_selectorperiodos_plame_web.sql
    - sp_pr_selectorperiodos_web.sql
    - sp_pr_selectorplanillas_web.sql
    - sp_pr_selectorprocesos_web.sql
    - sp_pr_selectorprocesoscalculo_web.sql
    - sp_pr_selectorregimehealth_web.sql
    - sp_pr_selectorsctrpension_web.sql
    - sp_pr_selectortipocuenta_web.sql
    - sp_pr_selectorunidades_web.sql
    - sp_pr_trabajadores_sin_regimen_pension_afp_web.sql
    - sp_pr_vacaciones_eliminar_detalle_web.sql
    - sp_pr_vacaciones_guardar_detalle_web.sql
    - sp_pr_vacaciones_listar_trabajadores_web.sql
    - sp_pr_vacaciones_obtener_trabajador_web.sql
    - sp_pr_validar_calculo_web.sql
*/

SET NOCOUNT ON;
GO


-- ============================================================================
-- [01/89] alter_pr_mapping_add_banbifbank.sql
-- ============================================================================

/*
    Agrega la columna BanbifBank en PR_Mapping y la inicializa
    con el código de banco de ERP_Bank (BANCO BANBIF) por compañía.
*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'PR_Mapping'
      AND c.name = 'BanbifBank'
)
BEGIN
    ALTER TABLE dbo.PR_Mapping
        ADD BanbifBank VARCHAR(20) NULL;
END
GO

UPDATE PR_Mapping
SET BanbifBank = (
    SELECT bank
    FROM ERP_Bank
    WHERE name = 'BANCO BANBIF'
      AND Company = PR_Mapping.Company
);
GO



-- ============================================================================
-- [02/89] alter_pr_processtype_add_procedurename.sql
-- ============================================================================

/*
    Agrega la columna ProcedureName en PR_ProcessType y asigna el SP de cálculo
    por persona según la descripción del proceso (Procesar planilla → Calcular).

    ProcedureName NULL: proceso sin SP de cálculo individual configurado.
*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'PR_ProcessType'
      AND c.name = 'ProcedureName'
)
BEGIN
    ALTER TABLE dbo.PR_ProcessType
        ADD ProcedureName VARCHAR(50) NULL;
END
GO

UPDATE PR_ProcessType
SET ProcedureName = NULL
WHERE RTRIM(LTRIM(Description)) = 'PRESTAMOS';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_finmes_persona'
WHERE RTRIM(LTRIM(Description)) = 'MENSUAL';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_pagocts_persona'
WHERE RTRIM(LTRIM(Description)) = 'PAGO DE CTS';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_vacaciones_persona'
WHERE RTRIM(LTRIM(Description)) = 'VACACIONES';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_quincena_persona'
WHERE RTRIM(LTRIM(Description)) = 'QUINCENA';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_provcts_persona'
WHERE RTRIM(LTRIM(Description)) = 'PROVISION CTS';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_provvac_persona'
WHERE RTRIM(LTRIM(Description)) = 'PROVISION VACACIONES';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_provgrati_persona'
WHERE RTRIM(LTRIM(Description)) = 'PROVISION GRATIFICACION';
GO

UPDATE PR_ProcessType
SET ProcedureName = NULL
WHERE RTRIM(LTRIM(Description)) = 'GRATIFICACION';
GO

UPDATE PR_ProcessType
SET ProcedureName = NULL
WHERE RTRIM(LTRIM(Description)) = 'UTILIDADES';
GO

UPDATE PR_ProcessType
SET ProcedureName = 'sp_pr_calcular_liquidacion_persona'
WHERE RTRIM(LTRIM(Description)) = 'LIQUIDACION';
GO

UPDATE PR_ProcessType
SET ProcedureName = NULL
WHERE RTRIM(LTRIM(Description)) = 'PROMEDIO VACACION';
GO

UPDATE PR_ProcessType
SET ProcedureName = NULL
WHERE RTRIM(LTRIM(Description)) = 'REINTEGRO';
GO



-- ============================================================================
-- [03/89] alter_sy_company_add_logoname_signaturename.sql
-- ============================================================================

/*
    Agrega columnas de logo y firma por compañía en SY_Company.
    Usado por: generación de boletas PDF (static/img + logoname / signaturename).
*/
IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'SY_Company'
      AND c.name = 'logoname'
)
BEGIN
    ALTER TABLE dbo.SY_Company
        ADD logoname VARCHAR(100) NULL;
END
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'SY_Company'
      AND c.name = 'signaturename'
)
BEGIN
    ALTER TABLE dbo.SY_Company
        ADD signaturename VARCHAR(100) NULL;
END
GO



-- ============================================================================
-- [04/89] tables_pr_plame_sunat_web.sql
-- ============================================================================

/*
    Tablas para carga de archivos XML SUNAT (R01, R04, R5) — validación PLAME.
    Ejecutar una vez en la base destino antes de usar la pantalla Validar PLAME.
*/
IF OBJECT_ID('dbo.PR_PlameSunatCarga', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PR_PlameSunatCarga (
        CargaId         INT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        Company         VARCHAR(10) NOT NULL,
        Period          VARCHAR(6) NOT NULL,
        Ruc             VARCHAR(11) NOT NULL,
        EmployerName    NVARCHAR(300) NULL,
        PeriodoSunat    VARCHAR(7) NULL,
        FileR01Name     NVARCHAR(260) NULL,
        FileR04Name     NVARCHAR(260) NULL,
        FileR05Name     NVARCHAR(260) NULL,
        RowsR01         INT NOT NULL DEFAULT 0,
        RowsR04         INT NOT NULL DEFAULT 0,
        RowsR05         INT NOT NULL DEFAULT 0,
        UploadedAt      DATETIME NOT NULL DEFAULT GETDATE(),
        UploadedBy      VARCHAR(50) NULL,
        CONSTRAINT UQ_PR_PlameSunatCarga_CompanyPeriod UNIQUE (Company, Period)
    );
END
GO

IF OBJECT_ID('dbo.PR_PlameSunatFila', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PR_PlameSunatFila (
        FilaId          BIGINT IDENTITY(1, 1) NOT NULL PRIMARY KEY,
        CargaId         INT NOT NULL,
        Archivo         CHAR(3) NOT NULL,
        NumFila         INT NOT NULL,
        TipoDoc         VARCHAR(2) NULL,
        DocumentNumber  VARCHAR(20) NULL,
        LastName1       NVARCHAR(100) NULL,
        LastName2       NVARCHAR(100) NULL,
        Names           NVARCHAR(200) NULL,
        Situacion       NVARCHAR(80) NULL,
        MontosJson      NVARCHAR(MAX) NULL,
        CONSTRAINT FK_PR_PlameSunatFila_Carga
            FOREIGN KEY (CargaId) REFERENCES dbo.PR_PlameSunatCarga (CargaId)
            ON DELETE CASCADE
    );
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_PR_PlameSunatFila_CargaArchivo'
      AND object_id = OBJECT_ID('dbo.PR_PlameSunatFila')
)
BEGIN
    CREATE INDEX IX_PR_PlameSunatFila_CargaArchivo
        ON dbo.PR_PlameSunatFila (CargaId, Archivo);
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = 'IX_PR_PlameSunatFila_Document'
      AND object_id = OBJECT_ID('dbo.PR_PlameSunatFila')
)
BEGIN
    CREATE INDEX IX_PR_PlameSunatFila_Document
        ON dbo.PR_PlameSunatFila (CargaId, DocumentNumber);
END
GO



-- ============================================================================
-- [05/89] SP_PR_EjecutarFormula.sql
-- ============================================================================

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
	declare @conceptcode varchar(50), @flag_cts char(1)

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
		select PR_FormulaDetail.Tipo,Operador,PR_FormulaDetail.Concept,grupo, valor, parameter,PR_FormulaDetail.process, periodoini, periodofin,numberini, numberfin, PR_FormulaDetail.TipoLiq
		from PR_FormulaHeader inner join PR_FormulaDetail on (PR_FormulaHeader.FormulaHeader = PR_FormulaDetail.FormulaHeader) 
		where PR_FormulaHeader.Concept = @concept and PR_FormulaHeader.Payrolltype = @payrolltype and PR_FormulaHeader.Proccestype = @processtype
		and ((@pos > 0 and PR_FormulaDetail.line <= @pos) or (@pos = 0))
		order by line

		OPEN formula 
		FETCH NEXT FROM formula INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin, @TipoLiq
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
			
				set @importe = (select SUM(ISNULL(ConceptValueLo,ConceptValue))  from PR_EmployeePayRollConcept where Company = @cia and PayRollType = @payrolltype and Person = @person
								and PRPeriod between @period_begin and @period_end 
								and ProcessType = @process and Concept = @conceptid)
				
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
	
		INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin, @TipoLiq
		END 
		
		CLOSE formula
		DEALLOCATE formula
	
		

		/*SOLO EN CASO DE CONDICION ELSE*/
		set @query2 = ''

		Declare formula2 Cursor For
		select PR_FormulaDetail.Tipo,Operador,PR_FormulaDetail.Concept,grupo, valor, parameter,PR_FormulaDetail.process, periodoini, periodofin,numberini, numberfin
		from PR_FormulaHeader inner join PR_FormulaDetail on (PR_FormulaHeader.FormulaHeader = PR_FormulaDetail.FormulaHeader) 
		where PR_FormulaHeader.Concept = @concept and PR_FormulaHeader.Payrolltype = @payrolltype and PR_FormulaHeader.Proccestype = @processtype
		and (@pos > 0 and PR_FormulaDetail.line > @pos)
		order by line
	
	
		OPEN formula2 
		FETCH NEXT FROM formula2 INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin
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

				set @importe = isnull((select sum(ISNULL(ConceptValueLo,conceptvalue)) from PR_EmployeePayRollConcept where Company = @cia and PayRollType = @payrolltype and Person = @person
								and PRPeriod between @period_begin and @period_end 
								and ProcessType = @process and Concept = @conceptid),0)

				set @query2 =  @query2 + convert(varchar(20),@importe) + @op 
			End

			IF @tipo = 'G' set @query2 = @query2 + case when @grupo = 'O' then '(' else convert(varchar(20),0) + ')' end + @op

			IF @tipo = 'V' set @query2 = @query2 + convert(varchar(20),@numero) + @op

			
		FETCH NEXT FROM formula2
	
		INTO  @tipo, @opera, @conceptid, @grupo, @numero, @parameter, @process, @periodoini, @periodofin,@numberini, @numberfin
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

GO


-- ============================================================================
-- [06/89] SP_PR_ReportePromedioLiquidacion.sql
-- ============================================================================

/*
    Promedio de liquidaciones por trabajador (últimos 6 meses).
    Usado por: POST /api/reportes/promedio-liquidaciones (reporte_liquidaciones.html).

    Requiere liquidación calculada en el periodo indicado (PR_ProcessType.ShortName = 'LIQUIDACION').
    Usa funciones: f_getSumaConceptoPromedio, f_getSumaConceptoPromedioVAC, f_getMesesDividir.

    Parámetros:
      @cia, @payrolltype, @period, @person — todos obligatorios.

    Salida: 6 filas (meses) con conceptos promedio para vacaciones, CTS y gratificación,
    más meses divisorios (vaccant, ctsCant, gratiCant), nombre y fechas.
*/
CREATE OR ALTER PROCEDURE [dbo].[SP_PR_ReportePromedioLiquidacion]
    @cia          VARCHAR(20),
    @payrolltype  VARCHAR(20),
    @period       VARCHAR(20),
    @person       VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ceasedate    DATETIME;
    DECLARE @fechaingreso DATETIME;
    DECLARE @extras       VARCHAR(50) = 'C_HORASEXTRAS';
    DECLARE @bono         VARCHAR(50) = 'SOBRETASA_NOCHE';
    DECLARE @feriado      VARCHAR(50) = 'FERIADOS';
    DECLARE @comision     VARCHAR(50) = 'COMISION';
    DECLARE @faltas       VARCHAR(50) = 'CANT_DIAS_AUSENCIA';
    DECLARE @lsg          VARCHAR(50) = 'DIASLICSGOCE';
    DECLARE @susp         VARCHAR(50) = 'DIASUSPENSION';
    DECLARE @mes          INT = 0;

    CREATE TABLE #temp_reporte (
        periodo       VARCHAR(20),
        he_vac        NUMERIC(19, 4),
        bono_vac      NUMERIC(19, 4),
        feriado_vac   NUMERIC(19, 4),
        comision_vac  NUMERIC(19, 4),
        faltas_vac    NUMERIC(19, 4),
        he_cts        NUMERIC(19, 4),
        bono_cts      NUMERIC(19, 4),
        feriado_cts   NUMERIC(19, 4),
        comision_cts  NUMERIC(19, 4),
        faltas_cts    NUMERIC(19, 4),
        he_gra        NUMERIC(19, 4),
        bono_gra      NUMERIC(19, 4),
        feriado_gra   NUMERIC(19, 4),
        comision_gra  NUMERIC(19, 4),
        faltas_gra    NUMERIC(19, 4),
        ctsCant       NUMERIC(19, 4),
        gratiCant     NUMERIC(19, 4),
        person        VARCHAR(20)
    );

    SELECT
        @ceasedate = CeaseDate,
        @fechaingreso = EntryDate
    FROM PR_EmployeePayRoll
    WHERE Company = @cia
      AND PRPeriod = @period
      AND Person = @person
      AND EXISTS (
            SELECT 1
            FROM PR_ProcessType
            WHERE ProcessType = PR_EmployeePayRoll.ProcessType
              AND ShortName = 'LIQUIDACION'
      );

    /* Últimos 6 meses respecto al periodo de liquidación. */
    WHILE @mes <= 5
    BEGIN
        INSERT INTO #temp_reporte
        SELECT
            CONVERT(VARCHAR(6), DATEADD(MONTH, -@mes, CONVERT(DATETIME, @period)), 112),
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0, 0, 0, 0,
            0, 0,
            Person
        FROM PR_EmployeePayRoll
        WHERE Company = @cia
          AND PRPeriod = @period
          AND Person = @person
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType
                WHERE ProcessType = PR_EmployeePayRoll.ProcessType
                  AND ShortName = 'LIQUIDACION'
          );

        SET @mes = @mes + 1;
    END;

    UPDATE #temp_reporte
    SET periodo = periodo + SUBSTRING(periodo, 5, 2);

    UPDATE #temp_reporte
    SET
        he_cts = CASE
            WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
             AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                     AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                END
            ELSE
                CASE
                    WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                        END
                    ELSE
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                        END
                END
        END,
        bono_cts = CASE
            WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
             AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                     AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                END
            ELSE
                CASE
                    WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                        END
                    ELSE
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                        END
                END
        END,
        comision_cts = CASE
            WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
             AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                     AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                END
            ELSE
                CASE
                    WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                        END
                    ELSE
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                        END
                END
        END,
        feriado_cts = CASE
            WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
             AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                     AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                END
            ELSE
                CASE
                    WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                        END
                    ELSE
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                            ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                        END
                END
        END,
        faltas_cts =
            CASE
                WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
                 AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                    CASE
                        WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                         AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                            THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                        ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                    END
                ELSE
                    CASE
                        WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                            END
                        ELSE
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                            END
                    END
            END
            + CASE
                WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
                 AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                    CASE
                        WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                         AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                            THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                        ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                    END
                ELSE
                    CASE
                        WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                            END
                        ELSE
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                            END
                    END
            END
            + CASE
                WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
                 AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                    CASE
                        WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                         AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                            THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                        ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                    END
                ELSE
                    CASE
                        WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                            END
                        ELSE
                            CASE
                                WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                    THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                                ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                            END
                    END
            END,
        he_gra = CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0701'), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo)
                END
        END,
        bono_gra = CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0701'), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo)
                END
        END,
        comision_gra = CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0701'), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo)
                END
        END,
        feriado_gra = CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0701'), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo)
                END
        END,
        faltas_gra = CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, @fechaingreso),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @faltas, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, LEFT(@period, 4) + '0701'),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @faltas, periodo)
                END
        END
        + CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, @fechaingreso),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @lsg, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, LEFT(@period, 4) + '0701'),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @lsg, periodo)
                END
        END
        + CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo)
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, @fechaingreso),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @susp, periodo)
                    ELSE dbo.f_getSumaConceptoPromedio(
                            CONVERT(DATE, LEFT(@period, 4) + '0701'),
                            CASE
                                WHEN CONVERT(VARCHAR(8), @ceasedate, 112) > LEFT(@period, 6) + '29'
                                    THEN CONVERT(DATE, @ceasedate)
                                ELSE DATEADD(DAY, -1, CONVERT(DATE, LEFT(@period, 6) + '01'))
                            END,
                            @cia, @person, @susp, periodo)
                END
        END,
        he_vac = dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @extras, periodo),
        bono_vac = dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @bono, periodo),
        comision_vac = dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @comision, periodo),
        feriado_vac = dbo.f_getSumaConceptoPromedio(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate), @cia, @person, @feriado, periodo),
        faltas_vac =
            dbo.f_getSumaConceptoPromedioVAC(
                CASE
                    WHEN DATEDIFF(YEAR, @fechaingreso, @ceasedate) <= 1 THEN CONVERT(DATE, @fechaingreso)
                    ELSE CONVERT(DATE, CONVERT(VARCHAR(4), YEAR(@ceasedate) - 1) + RIGHT(CONVERT(VARCHAR(8), @fechaingreso, 112), 4))
                END,
                CONVERT(DATE, @ceasedate), @cia, @person, @faltas, periodo)
            + dbo.f_getSumaConceptoPromedioVAC(
                CASE
                    WHEN DATEDIFF(YEAR, @fechaingreso, @ceasedate) <= 1 THEN CONVERT(DATE, @fechaingreso)
                    ELSE CONVERT(DATE, CONVERT(VARCHAR(4), YEAR(@ceasedate) - 1) + RIGHT(CONVERT(VARCHAR(8), @fechaingreso, 112), 4))
                END,
                CONVERT(DATE, @ceasedate), @cia, @person, @lsg, periodo)
            + dbo.f_getSumaConceptoPromedioVAC(
                CASE
                    WHEN DATEDIFF(YEAR, @fechaingreso, @ceasedate) <= 1 THEN CONVERT(DATE, @fechaingreso)
                    ELSE CONVERT(DATE, CONVERT(VARCHAR(4), YEAR(@ceasedate) - 1) + RIGHT(CONVERT(VARCHAR(8), @fechaingreso, 112), 4))
                END,
                CONVERT(DATE, @ceasedate), @cia, @person, @susp, periodo);

    SELECT
        LEFT(periodo, 4) + '-' + SUBSTRING(periodo, 5, 2) AS periodo_fmt,
        he_vac,
        bono_vac,
        feriado_vac,
        comision_vac,
        faltas_vac,
        he_cts,
        bono_cts,
        feriado_cts,
        comision_cts,
        faltas_cts,
        he_gra,
        bono_gra,
        feriado_gra,
        comision_gra,
        faltas_gra,
        CASE
            WHEN @ceasedate >= CONVERT(DATETIME, LEFT(@period, 4) + '0501')
             AND @ceasedate <= CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) >= CONVERT(DATE, LEFT(@period, 4) + '0501')
                     AND CONVERT(DATE, @fechaingreso) <= CONVERT(DATE, LEFT(@period, 4) + '1031')
                        THEN dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate))
                    ELSE dbo.f_getMesesDividir(CONVERT(DATE, LEFT(@period, 4) + '0501'), CONVERT(DATE, @ceasedate))
                END
            ELSE
                CASE
                    WHEN @ceasedate > CONVERT(DATETIME, LEFT(@period, 4) + '1031') THEN
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, LEFT(@period, 4) + '1031')
                                THEN dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate))
                            ELSE dbo.f_getMesesDividir(CONVERT(DATE, LEFT(@period, 4) + '1101'), CONVERT(DATE, @ceasedate))
                        END
                    ELSE
                        CASE
                            WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATETIME, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1031')
                                THEN dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate))
                            ELSE dbo.f_getMesesDividir(CONVERT(DATE, CONVERT(CHAR(4), CONVERT(INT, LEFT(@period, 4)) - 1) + '1101'), CONVERT(DATE, @ceasedate))
                        END
                END
        END AS ctsCant,
        CASE
            WHEN MONTH(@ceasedate) < 7 THEN
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0101')
                        THEN dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate))
                    ELSE dbo.f_getMesesDividir(CONVERT(DATE, LEFT(@period, 4) + '0101'), CONVERT(DATE, @ceasedate))
                END
            ELSE
                CASE
                    WHEN CONVERT(DATE, @fechaingreso) > CONVERT(DATE, LEFT(@period, 4) + '0701')
                        THEN dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate))
                    ELSE dbo.f_getMesesDividir(CONVERT(DATE, LEFT(@period, 4) + '0701'), CONVERT(DATE, @ceasedate))
                END
        END AS gratiCant,
        SY_Person.Name,
        CONVERT(VARCHAR(20), @ceasedate, 103) AS fechacese,
        CONVERT(VARCHAR(20), @fechaingreso, 103) AS fechaingreso,
        dbo.f_getMesesDividir(CONVERT(DATE, @fechaingreso), CONVERT(DATE, @ceasedate)) AS vaccant
    FROM #temp_reporte
        INNER JOIN SY_Person
            ON #temp_reporte.person = SY_Person.Person;
END
GO



-- ============================================================================
-- [07/89] sp_pr_actualizar_bancario_trabajador_web.sql
-- ============================================================================

/*
    Actualiza datos bancarios y CTS del trabajador.
    Clave: person + company (@cia).
    CCI → PR_Employee.SocialAssistanceNumber (convención HM).
    Forma de pago → PR_Employee.CollectionForm (TE_CollectionForm).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_bancario_trabajador_web]
    @cia                VARCHAR(10),
    @person             VARCHAR(20),
    @collectionform     VARCHAR(20),
    @salarybank         VARCHAR(20),
    @salaryaccounttype  VARCHAR(20),
    @salaryaccount      VARCHAR(20),
    @cci                VARCHAR(20),
    @ctsbank            VARCHAR(20),
    @ctsaccount         VARCHAR(20),
    @ctscurrency        VARCHAR(2),
    @xlastuser          VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM pr_employee
        WHERE company = @cia AND person = @person
    )
    BEGIN
        RAISERROR('Trabajador no encontrado para la compañía indicada.', 16, 1);
        RETURN;
    END

    IF RTRIM(ISNULL(@ctscurrency, '')) = '' SET @ctscurrency = 'LO';

    UPDATE pr_employee
    SET
        collectionform = NULLIF(LTRIM(RTRIM(@collectionform)), ''),
        salarybank = NULLIF(LTRIM(RTRIM(@salarybank)), ''),
        salaryaccounttype = NULLIF(LTRIM(RTRIM(@salaryaccounttype)), ''),
        salaryaccount = NULLIF(LTRIM(RTRIM(@salaryaccount)), ''),
        socialassistancenumber = NULLIF(LTRIM(RTRIM(@cci)), ''),
        ctsbank = NULLIF(LTRIM(RTRIM(@ctsbank)), ''),
        ctsaccount = NULLIF(LTRIM(RTRIM(@ctsaccount)), ''),
        ctscurrency = @ctscurrency,
        xlastdate = GETDATE(),
        xlastuser = NULLIF(LTRIM(RTRIM(@xlastuser)), '')
    WHERE company = @cia
      AND person = @person;
END
GO



-- ============================================================================
-- [08/89] sp_pr_actualizar_datos_afp_web.sql
-- ============================================================================

/*
    Control de datos AFP — actualiza PR_EmployeeAFP y PR_EmployeeAFPHeader.

    Usado por: POST /api/declaracion-afp/generar-xlsx (antes de generar el Excel AFPnet).

    Basado en: AUXILIARES/control de datos AFP.txt (PowerBuilder w_pr_afp_calc_list).

    Solo procesa combinaciones planilla/proceso que tengan concepto formulacode = TOTAL_REM_AFP
    en PR_EmployeePayRollConcept para el periodo indicado.

    Parámetros:
      @cia         — compañía
      @period      — periodo YYYYMM (6 dígitos)
      @payroll_all — Y = todas las planillas con TOTAL_REM_AFP, N = filtrar por @payroll
      @payroll     — tipo de planilla
      @xlastuser   — usuario que ejecuta el proceso
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_datos_afp_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(20),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL,
    @xlastuser   VARCHAR(20) = 'WEB'
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 6);
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @xlastuser = LTRIM(RTRIM(ISNULL(@xlastuser, 'WEB')));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @payroll_all = 'Y' SET @payroll = '';

    DECLARE
        @AFPAssureableRemConcept VARCHAR(20),
        @AFPFixedAmountConcept VARCHAR(20),
        @AFPVariableAmountConcept VARCHAR(20),
        @AFPInsuredAmountConcept VARCHAR(20),
        @AFPARComisionAmountConcept VARCHAR(20),
        @AFPEmployerContribution VARCHAR(20),
        @LiquidacionProcess VARCHAR(20),
        @DefaultReplicationUnit VARCHAR(4);

    SELECT
        @AFPAssureableRemConcept = LTRIM(RTRIM(AFPAssureableRemConcept)),
        @AFPFixedAmountConcept = LTRIM(RTRIM(AFPFixedAmountConcept)),
        @AFPVariableAmountConcept = LTRIM(RTRIM(AFPVariableAmountConcept)),
        @AFPInsuredAmountConcept = LTRIM(RTRIM(AFPInsuredAmountConcept)),
        @AFPARComisionAmountConcept = LTRIM(RTRIM(AFPARComisionAmountConcept)),
        @AFPEmployerContribution = LTRIM(RTRIM(AfpEmployerContribution)),
        @LiquidacionProcess = LTRIM(RTRIM(LiquidacionProcess))
    FROM pr_mapping (NOLOCK)
    WHERE Company = @cia;

    IF @AFPAssureableRemConcept IS NULL OR @AFPFixedAmountConcept IS NULL
       OR @AFPVariableAmountConcept IS NULL OR @AFPInsuredAmountConcept IS NULL
       OR @AFPARComisionAmountConcept IS NULL
    BEGIN
        RAISERROR('Debe configurarse los conceptos AFP de la compañía en PR_Mapping.', 16, 1);
        RETURN;
    END

    SELECT TOP 1 @DefaultReplicationUnit = LTRIM(RTRIM(ReplicationUnit))
    FROM sy_replicationunit (NOLOCK)
    ORDER BY ReplicationUnit;

    CREATE TABLE #PlanillasProcesar (
        payrolltype VARCHAR(20) NOT NULL,
        processtype VARCHAR(20) NOT NULL,
        PRIMARY KEY (payrolltype, processtype)
    );

    INSERT INTO #PlanillasProcesar (payrolltype, processtype)
    SELECT DISTINCT
        LTRIM(RTRIM(EPC.PayRollType)),
        LTRIM(RTRIM(EPC.ProcessType))
    FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON EPC.Concept = C.Concept
           AND EPC.Company = C.Company
    WHERE EPC.Company = @cia
      AND LEFT(EPC.PRPeriod, 6) = @period
      AND C.FormulaCode = 'TOTAL_REM_AFP'
      AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll);

    IF NOT EXISTS (SELECT 1 FROM #PlanillasProcesar)
    BEGIN
        SELECT
            0 AS actualizado,
            0 AS filas_afp,
            0 AS filas_header,
            'No hay combinaciones planilla/proceso con concepto TOTAL_REM_AFP para el periodo.' AS mensaje;
        RETURN;
    END

    CREATE TABLE #ConceptosAfp (
        person VARCHAR(20) NOT NULL,
        company VARCHAR(4) NOT NULL,
        payrolltype VARCHAR(20) NOT NULL,
        processtype VARCHAR(20) NOT NULL,
        prperiod VARCHAR(20) NOT NULL,
        concept VARCHAR(20) NOT NULL,
        conceptcurrency CHAR(2) NULL,
        exchangerate NUMERIC(18, 4) NULL,
        conceptvalue NUMERIC(18, 4) NOT NULL,
        conceptvaluelo NUMERIC(18, 4) NOT NULL,
        conceptvalueex NUMERIC(18, 4) NOT NULL,
        afpcard VARCHAR(20) NULL,
        ceasedate DATETIME NULL,
        entrydate DATETIME NULL,
        afp VARCHAR(20) NULL,
        costcenter VARCHAR(20) NULL,
        costcentername VARCHAR(20) NULL,
        replicationunit VARCHAR(4) NULL
    );

    INSERT INTO #ConceptosAfp (
        person, company, payrolltype, processtype, prperiod, concept,
        conceptcurrency, exchangerate, conceptvalue, conceptvaluelo, conceptvalueex,
        afpcard, ceasedate, entrydate, afp, costcenter, costcentername, replicationunit
    )
    SELECT
        LTRIM(RTRIM(EPC.Person)),
        LTRIM(RTRIM(EPC.Company)),
        LTRIM(RTRIM(EPC.PayRollType)),
        LTRIM(RTRIM(EPC.ProcessType)),
        LTRIM(RTRIM(EPC.PRPeriod)),
        LTRIM(RTRIM(EPC.Concept)),
        EPC.ConceptCurrency,
        EPC.ExchangeRate,
        ISNULL(EPC.ConceptValue, 0),
        ISNULL(EPC.ConceptValueLo, 0),
        ISNULL(EPC.ConceptValueEx, 0),
        LTRIM(RTRIM(COALESCE(
            NULLIF(LTRIM(RTRIM(ISNULL(EP.AFPCard, ''))), ''),
            NULLIF(LTRIM(RTRIM(ISNULL(EM.AFPCard, ''))), ''),
            ''
        ))),
        EP.CeaseDate,
        EP.EntryDate,
        LTRIM(RTRIM(EP.AFP)),
        LTRIM(RTRIM(EP.CostCenter)),
        LTRIM(RTRIM(EP.CostCenterName)),
        LTRIM(RTRIM(ISNULL(EP.ReplicationUnit, EPC.ReplicationUnit)))
    FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_EmployeePayRoll EP (NOLOCK)
            ON EPC.Company = EP.Company
           AND EPC.PayRollType = EP.PayRollType
           AND EPC.PRPeriod = EP.PRPeriod
           AND EPC.Person = EP.Person
           AND EPC.ProcessType = EP.ProcessType
        INNER JOIN PR_Employee EM (NOLOCK)
            ON EPC.Company = EM.Company
           AND EPC.Person = EM.person
        INNER JOIN #PlanillasProcesar PP
            ON EPC.PayRollType = PP.payrolltype
           AND EPC.ProcessType = PP.processtype
    WHERE EPC.Company = @cia
      AND LEFT(EPC.PRPeriod, 6) = @period
      AND ISNULL(LTRIM(RTRIM(EP.AFP)), '') <> ''
      AND (
            EPC.Concept = @AFPAssureableRemConcept
         OR EPC.Concept = @AFPFixedAmountConcept
         OR EPC.Concept = @AFPVariableAmountConcept
         OR EPC.Concept = @AFPInsuredAmountConcept
         OR EPC.Concept = @AFPARComisionAmountConcept
         OR EPC.Concept = @AFPEmployerContribution
      );

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE H
        FROM PR_EmployeeAFPHeader H
            INNER JOIN (
                SELECT DISTINCT payrolltype FROM #PlanillasProcesar
            ) P ON H.PayRollType = P.payrolltype
        WHERE H.Company = @cia
          AND LEFT(H.PRPeriod, 6) = @period;

        DELETE A
        FROM PR_EmployeeAFP A
            INNER JOIN (
                SELECT DISTINCT payrolltype FROM #PlanillasProcesar
            ) P ON A.PayRollType = P.payrolltype
        WHERE A.Company = @cia
          AND LEFT(A.PRPeriod, 6) = @period;

        INSERT INTO PR_EmployeeAFP (
            Person, Company, PRPeriod, AFP, AFPCurrency, AFPExchangeRate,
            AssureableRemAmount, AssureableRemAmountLo, AssureableRemAmountEx,
            FixedAmount, FixedAmountLo, FixedAmountEx,
            VariableAmount, VariableAmountLo, VariableAmountEx,
            InsuredAmount, InsuredAmountLo, InsuredAmountEx,
            ARComisionAmount, ARComisionAmountLo, ARComisionAmountEx,
            EmployerContribution, EmployerContributionLo, EmployerContributionEx,
            ReplicationUnit, XLastUser, XLastDate,
            Costcenter, Costcentername, payrolltype, ceasedate, afpcard, entrydate
        )
        SELECT
            S.person,
            S.company,
            S.prperiod,
            S.afp,
            S.conceptcurrency,
            S.exchangerate,
            S.AssureableRemAmount,
            S.AssureableRemAmountLo,
            S.AssureableRemAmountEx,
            S.FixedAmount,
            S.FixedAmountLo,
            S.FixedAmountEx,
            S.VariableAmount,
            S.VariableAmountLo,
            S.VariableAmountEx,
            S.InsuredAmount,
            S.InsuredAmountLo,
            S.InsuredAmountEx,
            S.ARComisionAmount,
            S.ARComisionAmountLo,
            S.ARComisionAmountEx,
            S.EmployerContribution,
            S.EmployerContributionLo,
            S.EmployerContributionEx,
            CASE
                WHEN ISNULL(S.replicationunit, '') = '' THEN @DefaultReplicationUnit
                ELSE S.replicationunit
            END,
            @xlastuser,
            GETDATE(),
            S.costcenter,
            S.costcentername,
            S.payrolltype,
            S.ceasedate,
            LTRIM(RTRIM(COALESCE(
                NULLIF(LTRIM(RTRIM(ISNULL(S.afpcard, ''))), ''),
                NULLIF(LTRIM(RTRIM(ISNULL(EM.AFPCard, ''))), ''),
                ''
            ))),
            S.entrydate AS entrydate
        FROM (
            SELECT
                C.person,
                C.company,
                LEFT(C.prperiod, 6) + SUBSTRING(C.prperiod, 5, 2) AS prperiod,
                MAX(C.afp) AS afp,
                MAX(C.conceptcurrency) AS conceptcurrency,
                MAX(C.exchangerate) AS exchangerate,
                SUM(CASE WHEN C.concept = @AFPAssureableRemConcept THEN C.conceptvalue ELSE 0 END) AS AssureableRemAmount,
                SUM(CASE WHEN C.concept = @AFPAssureableRemConcept THEN C.conceptvaluelo ELSE 0 END) AS AssureableRemAmountLo,
                SUM(CASE WHEN C.concept = @AFPAssureableRemConcept THEN C.conceptvalueex ELSE 0 END) AS AssureableRemAmountEx,
                SUM(CASE WHEN C.concept = @AFPFixedAmountConcept THEN C.conceptvalue ELSE 0 END) AS FixedAmount,
                SUM(CASE WHEN C.concept = @AFPFixedAmountConcept THEN C.conceptvaluelo ELSE 0 END) AS FixedAmountLo,
                SUM(CASE WHEN C.concept = @AFPFixedAmountConcept THEN C.conceptvalueex ELSE 0 END) AS FixedAmountEx,
                SUM(CASE WHEN C.concept = @AFPVariableAmountConcept THEN C.conceptvalue ELSE 0 END) AS VariableAmount,
                SUM(CASE WHEN C.concept = @AFPVariableAmountConcept THEN C.conceptvaluelo ELSE 0 END) AS VariableAmountLo,
                SUM(CASE WHEN C.concept = @AFPVariableAmountConcept THEN C.conceptvalueex ELSE 0 END) AS VariableAmountEx,
                SUM(CASE WHEN C.concept = @AFPInsuredAmountConcept THEN C.conceptvalue ELSE 0 END) AS InsuredAmount,
                SUM(CASE WHEN C.concept = @AFPInsuredAmountConcept THEN C.conceptvaluelo ELSE 0 END) AS InsuredAmountLo,
                SUM(CASE WHEN C.concept = @AFPInsuredAmountConcept THEN C.conceptvalueex ELSE 0 END) AS InsuredAmountEx,
                SUM(CASE WHEN C.concept = @AFPARComisionAmountConcept THEN C.conceptvalue ELSE 0 END) AS ARComisionAmount,
                SUM(CASE WHEN C.concept = @AFPARComisionAmountConcept THEN C.conceptvaluelo ELSE 0 END) AS ARComisionAmountLo,
                SUM(CASE WHEN C.concept = @AFPARComisionAmountConcept THEN C.conceptvalueex ELSE 0 END) AS ARComisionAmountEx,
                SUM(CASE WHEN C.concept = @AFPEmployerContribution THEN C.conceptvalue ELSE 0 END) AS EmployerContribution,
                SUM(CASE WHEN C.concept = @AFPEmployerContribution THEN C.conceptvaluelo ELSE 0 END) AS EmployerContributionLo,
                SUM(CASE WHEN C.concept = @AFPEmployerContribution THEN C.conceptvalueex ELSE 0 END) AS EmployerContributionEx,
                MAX(C.replicationunit) AS replicationunit,
                MAX(C.costcenter) AS costcenter,
                MAX(C.costcentername) AS costcentername,
                MAX(C.payrolltype) AS payrolltype,
                MAX(C.afpcard) AS afpcard,
                MAX(CASE WHEN LTRIM(RTRIM(PT.ShortName)) = 'FIN_DE_MES' THEN C.ceasedate END) AS ceasedate,
                MAX(CASE WHEN LTRIM(RTRIM(PT.ShortName)) = 'FIN_DE_MES' THEN C.entrydate END) AS entrydate,
                SUM(CASE
                    WHEN C.concept IN (
                        @AFPFixedAmountConcept, @AFPVariableAmountConcept,
                        @AFPInsuredAmountConcept, @AFPARComisionAmountConcept, @AFPEmployerContribution
                    ) THEN 1 ELSE 0
                END) AS tiene_aportes
            FROM #ConceptosAfp C
                INNER JOIN PR_ProcessType PT (NOLOCK)
                    ON PT.ProcessType = C.processtype
                   AND PT.Company = C.company
            GROUP BY C.person, C.company, C.payrolltype, LEFT(C.prperiod, 6) + SUBSTRING(C.prperiod, 5, 2)
        ) S
            INNER JOIN pr_employee EM (NOLOCK)
                ON EM.person = S.person
               AND EM.company = S.company
        WHERE S.tiene_aportes > 0
          AND ISNULL(LTRIM(RTRIM(S.afp)), '') <> '';

        INSERT INTO PR_EmployeeAFPHeader (
            Company, ReplicationUnit, PRPeriod, PayRollType, AFP, costcenter,
            costcentername, PaymentStatus, XLastUser, XLastDate
        )
        SELECT
            A.Company,
            A.ReplicationUnit,
            A.PRPeriod,
            A.PayRollType,
            A.AFP,
            A.Costcenter,
            MAX(A.Costcentername),
            'P',
            @xlastuser,
            GETDATE()
        FROM PR_EmployeeAFP A (NOLOCK)
        WHERE A.Company = @cia
          AND LEFT(A.PRPeriod, 6) = @period
          AND A.PayRollType IN (SELECT DISTINCT payrolltype FROM #PlanillasProcesar)
          AND ISNULL(A.ReplicationUnit, '') <> ''
        GROUP BY
            A.Company, A.ReplicationUnit, A.PRPeriod, A.PayRollType, A.AFP, A.Costcenter;

        UPDATE PR_EmployeeAFP
        SET AssureableRemAmountLo = AssureableRemAmount
        WHERE Company = @cia
          AND LEFT(PRPeriod, 4) = LEFT(@period, 4);

        COMMIT TRANSACTION;

        SELECT
            1 AS actualizado,
            (SELECT COUNT(*) FROM PR_EmployeeAFP (NOLOCK)
             WHERE Company = @cia AND LEFT(PRPeriod, 6) = @period
               AND PayRollType IN (SELECT DISTINCT payrolltype FROM #PlanillasProcesar)) AS filas_afp,
            (SELECT COUNT(*) FROM PR_EmployeeAFPHeader (NOLOCK)
             WHERE Company = @cia AND LEFT(PRPeriod, 6) = @period
               AND PayRollType IN (SELECT DISTINCT payrolltype FROM #PlanillasProcesar)) AS filas_header,
            'Control de datos AFP ejecutado correctamente.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @err VARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('Error en control de datos AFP: %s', 16, 1, @err);
    END CATCH
END
GO



-- ============================================================================
-- [09/89] sp_pr_actualizar_pensiones_trabajador_web.sql
-- ============================================================================

/*
    Actualiza datos de pensiones del trabajador (PR_Employee).
    Clave: person + company (@cia).
    Fecha inscripción: VARCHAR(10) YYYY-MM-DD o vacío → NULL.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_pensiones_trabajador_web]
    @cia                        VARCHAR(10),
    @person                     VARCHAR(20),
    @pensiontype                VARCHAR(20),
    @pensioninscriptiondate     VARCHAR(10) = '',
    @regimehealth               VARCHAR(20),
    @flagmixta                  VARCHAR(1) = 'N',
    @flagasigfamiliar           VARCHAR(1) = 'N',
    @cuspp                      VARCHAR(20) = NULL,
    @xlastuser                  VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1 FROM pr_employee
        WHERE company = @cia AND person = @person
    )
    BEGIN
        RAISERROR('Trabajador no encontrado para la compañía indicada.', 16, 1);
        RETURN;
    END

    IF RTRIM(ISNULL(@flagmixta, '')) NOT IN ('Y', 'N') SET @flagmixta = 'N';
    IF RTRIM(ISNULL(@flagasigfamiliar, '')) NOT IN ('Y', 'N') SET @flagasigfamiliar = 'N';

    DECLARE @fecha_inscripcion DATETIME = NULL;
    IF RTRIM(ISNULL(@pensioninscriptiondate, '')) <> ''
        SET @fecha_inscripcion = TRY_CONVERT(DATETIME, @pensioninscriptiondate, 23);

    UPDATE pr_employee
    SET
        pensiontype = NULLIF(LTRIM(RTRIM(@pensiontype)), ''),
        pensioninscriptiondate = @fecha_inscripcion,
        regimehealth = NULLIF(LTRIM(RTRIM(@regimehealth)), ''),
        flagmixta = @flagmixta,
        flagasigfamiliar = @flagasigfamiliar,
        afpcard = NULLIF(LTRIM(RTRIM(@cuspp)), ''),
        xlastdate = GETDATE(),
        xlastuser = NULLIF(LTRIM(RTRIM(@xlastuser)), '')
    WHERE company = @cia
      AND person = @person;
END
GO



-- ============================================================================
-- [10/89] sp_pr_aperturarperiodo_proceso_web.sql
-- ============================================================================

/*
    Apertura de periodo para un tipo de proceso (lógica Useroption1 PowerBuilder).
    Usado por: POST /api/aperturar-periodos/aperturar (una llamada por proceso seleccionado).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_aperturarperiodo_proceso_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(20),
    @xlastuser   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LEFT(LTRIM(RTRIM(ISNULL(@cia, ''))), 4);
    SET @payrolltype = LEFT(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), 20);
    SET @processtype = LEFT(LTRIM(RTRIM(ISNULL(@processtype, ''))), 20);
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 10);
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), 20);

    IF @cia = '' OR @payrolltype = '' OR @processtype = '' OR @period = ''
    BEGIN
        RAISERROR('Faltan parámetros para aperturar el periodo.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Period p WITH (NOLOCK)
        WHERE p.Company = @cia
          AND p.PayRollType = @payrolltype
          AND LTRIM(RTRIM(p.PRPeriod)) = @period
    )
    BEGIN
        RAISERROR('No existe el periodo configurado para el tipo de planilla seleccionado.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_PayRollTypeProcess ptp WITH (NOLOCK)
        WHERE ptp.Company = @cia
          AND ptp.PayRollType = @payrolltype
          AND ptp.ProcessType = @processtype
    )
    BEGIN
        RAISERROR('El tipo de proceso no está configurado para la planilla.', 16, 1);
        RETURN;
    END;

    DECLARE @replicationunit VARCHAR(4) = '';

    SELECT TOP 1
        @replicationunit = LEFT(NULLIF(LTRIM(RTRIM(pc.ReplicationUnit)), ''), 4)
    FROM PR_ProcessControl pc WITH (NOLOCK)
    WHERE pc.Company = @cia
      AND pc.PayRollType = @payrolltype
      AND pc.ProcessType = @processtype;

    IF @replicationunit IS NULL
        SET @replicationunit = '';

    IF NOT EXISTS (
        SELECT 1
        FROM PR_ProcessControl pc WITH (NOLOCK)
        WHERE pc.Company = @cia
          AND pc.PayRollType = @payrolltype
          AND pc.ProcessType = @processtype
    )
    BEGIN
        INSERT INTO PR_ProcessControl (
            PayRollType, ProcessType, PRPeriod, Status,
            PaymentDate, ProcessDate, Company, ReplicationUnit,
            XLastUser, XLastDate
        )
        SELECT
            @payrolltype,
            @processtype,
            LEFT(LTRIM(RTRIM(p.PRPeriod)), 10),
            CASE
                WHEN LTRIM(RTRIM(p.PRPeriod)) < @period THEN 'C'
                WHEN LTRIM(RTRIM(p.PRPeriod)) > @period THEN 'P'
                ELSE 'A'
            END,
            NULL,
            CASE WHEN LTRIM(RTRIM(p.PRPeriod)) = @period THEN GETDATE() ELSE NULL END,
            @cia,
            LEFT(ISNULL(NULLIF(LTRIM(RTRIM(p.ReplicationUnit)), ''), @replicationunit), 4),
            @xlastuser,
            GETDATE()
        FROM PR_Period p WITH (NOLOCK)
        WHERE p.Company = @cia
          AND p.PayRollType = @payrolltype;
        RETURN;
    END;

    UPDATE PR_ProcessControl
    SET Status = 'C',
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND LTRIM(RTRIM(PRPeriod)) < @period;

    UPDATE PR_ProcessControl
    SET Status = 'P',
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND LTRIM(RTRIM(PRPeriod)) > @period;

    UPDATE PR_ProcessControl
    SET Status = 'A',
        PRPeriod = @period,
        ProcessDate = GETDATE(),
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND LTRIM(RTRIM(PRPeriod)) = @period;

    IF @@ROWCOUNT = 0
    BEGIN
        INSERT INTO PR_ProcessControl (
            PayRollType, ProcessType, PRPeriod, Status,
            PaymentDate, ProcessDate, Company, ReplicationUnit,
            XLastUser, XLastDate
        )
        VALUES (
            @payrolltype, @processtype, @period, 'A',
            NULL, GETDATE(), @cia, @replicationunit,
            @xlastuser, GETDATE()
        );
    END;
END
GO



-- ============================================================================
-- [11/89] sp_pr_calcular_provcts_persona.sql
-- ============================================================================

-- Exportado desde hm_aci2

--sp_pr_calcular_liquidacion_persona 'BGT', 'LIMABGT 000000000001', 'BGT 000000000011', '20241111', '45177754', 'ADMIN', 3.14

--select * FROM PR_PROCESSTYPE

--select * FROM PR_PAYROLLTYPE

--select PR_Concept.FormulaCode  from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = 'BGT'
--	and PR_FormulaHeader.Proccestype = 'BGT 000000000002' and PR_FormulaHeader.Payrolltype = 'LIMABGT 000000000001')

	--select PR_FormulaHeader.FormulaHeader, PR_Concept.FormulaCode  from PR_FormulaHeader inner join PR_Concept on (PR_FormulaHeader.Concept = PR_Concept.Concept and  PR_FormulaHeader.Company = 'BGT'
	--and PR_FormulaHeader.Proccestype = 'BGT 000000000002' and PR_FormulaHeader.Payrolltype = 'LIMABGT 000000000001')
	
--	select * from PR_Concept where FormulaCode = 'HRS_EXTRAS_PORC_35'
--	select * from PR_FormulaDetail where FormulaHeader = 'LIMABGT 000000000031'

/*
    Cálculo de provisión CTS por persona.
    Proceso: PROVISION CTS (sp_pr_calcular_provcts_persona).

    XDIASCTS (activo): 30 días del mes en provisión, prorrateado si ingresa después del día 1 del mes del periodo.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_calcular_provcts_persona]
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


	
	
	----DIAS GRATI TRUNCA

	declare @dia_grati_trunca numeric(19,4)
	declare @ceasedate datetime, @fechaingreso datetime, @fechaini datetime

	set @ceasedate = (select CeaseDate from #empleado)
	set @fechaingreso = (select fechaingreso from #empleado)
		



	declare @dia_cts_trunca numeric(19,4)
	declare @mes_periodo int

	set @mes_periodo = convert(int, substring(@period, 5, 2))

	/*
	    XDIASCTS - Provisión CTS mensual.
	    Semestres: Nov-Abr (meses 11,12,1-4) y May-Oct (meses 5-10).
	    Trabajador activo: 30 días del mes, salvo ingreso en el mismo mes del periodo
	    (después del día 1): prorrateo f_getDias360(fecha ingreso, fin de mes).
	    Trabajador cesado: mantiene lógica de días truncos por semestre.
	*/
	declare @inicio_mes date, @fin_mes date, @inicio_semestre date, @anio_periodo int

	set @anio_periodo = convert(int, left(@period, 4))
	set @inicio_mes = convert(date, left(@period, 6) + '01')
	set @fin_mes = convert(date, left(@period, 6) + '30')

	if @mes_periodo between 5 and 10
		set @inicio_semestre = convert(date, left(@period, 4) + '0501')
	else if @mes_periodo in (11, 12)
		set @inicio_semestre = convert(date, left(@period, 4) + '1101')
	else
		set @inicio_semestre = convert(date, convert(char(4), @anio_periodo - 1) + '1101')

	set @dia_cts_trunca =
					case when @ceasedate is null then
						case
							when @mes_periodo between 5 and 10 or @mes_periodo in (11, 12, 1, 2, 3, 4) then
								case
									when convert(date, @fechaingreso) > @inicio_mes
									 and convert(date, @fechaingreso) <= @fin_mes
									 and left(convert(varchar(8), @fechaingreso, 112), 6) = left(@period, 6)
									then dbo.f_getDias360(convert(date, @fechaingreso), @fin_mes)
									when convert(date, @fechaingreso) <= @inicio_mes
									  or convert(date, @fechaingreso) < @inicio_semestre
									then 30
									when convert(date, @fechaingreso) >= @inicio_semestre
									 and convert(date, @fechaingreso) < @inicio_mes
									then 30
									else 30
								end
							else
								case when convert(date, @fechaingreso) > convert(datetime, convert(char(4), @anio_periodo - 1) + '1031')
									then dbo.f_getDias360(convert(date, @fechaingreso), @fin_mes)
									else dbo.f_getDias360(convert(date, convert(char(4), @anio_periodo - 1) + '1101'), @fin_mes)
								end
						end
					else
						case when @ceasedate >= convert(datetime,left(@period,4)+'0501') and  @ceasedate <= convert(datetime,left(@period,4)+'1031') then
								case when convert(date,@fechaingreso) >= convert(date,left(@period,4)+'0501') and convert(date,@fechaingreso) <= convert(date,left(@period,4)+'1031') then dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) ) else dbo.f_getDias360(convert(date, left(@period,4)+'0501') ,convert(date,@ceasedate) ) end 
							else
								case when @ceasedate > convert(datetime,left(@period,4)+'1031') then
									case when  convert(date,@fechaingreso) > convert(datetime,left(@period,4)+'1031') then dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) ) else dbo.f_getDias360(convert(date, left(@period,4) +'1101') ,convert(date,@ceasedate) ) end 
								else
									
									
										case when  convert(date,@fechaingreso) > convert(datetime,convert(char(4),convert(int,left(@period,4)) - 1)+'1031') then dbo.f_getDias360(convert(date,@fechaingreso) ,convert(date,@ceasedate) ) else dbo.f_getDias360(convert(date,convert(char(4),convert(int,left(@period,4)) - 1)+'1101') ,convert(date,@ceasedate) ) end 
									
								end
							end
					end
	set @dia_cts_trunca = case when isnull((select FlagApplyFormula from #conceptos where FormulaCode = 'XDIASCTS'),'N') = 'Y' then isnull((select ConceptValue from #conceptos where FormulaCode = 'XDIASCTS'),0) else @dia_cts_trunca end
	execute sp_pr_registrar_log_calculo @company, @payrolltype,  @processtype, @period, @person, @UserID, 'XDIASCTS', @dia_cts_trunca, 'F'
	if isnull(@dia_cts_trunca,0) > 0 and  ISNULL((select count(*) from #formulas where FormulaCode = 'XDIASCTS'),0) = 0
	begin
		execute sp_pr_registrar_concepto @company, @payrolltype,  @processtype, @period, @person, @UserID, @tc, 'XDIASCTS', @dia_cts_trunca, 'Y'
	end

	--DIAS TOTAL DE DIAS CTS 

	declare @dia_total_cts numeric(19,4)
	declare @fechafinPeriodo datetime
	
	set @fechafinPeriodo = convert(datetime,left(@period,6)+'30')

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


-- ============================================================================
-- [12/89] sp_pr_calcularplanillas_web.sql
-- ============================================================================

/*
    Trabajadores elegibles para el cálculo de planilla (módulo Procesar planilla).
    Devuelve nombre, person, fechas de ingreso/reingreso, cese y última fecha de cálculo.

    @cia, @payrolltype, @processtype, @period: obligatorios para fecha de cálculo.
    @cesados: T = activos + cesados del mes del periodo, Y = solo cesados del mes, N = sin fecha de cese.
    @repunit: '0' = todas las unidades; otro valor filtra SY_Person.ReplicationUnit.

    Solo incluye trabajadores con fecha de ingreso/reingreso <= ultimo dia del mes del periodo.
    Los cesados de meses anteriores al periodo no se listan (p. ej. cese en mayo no aparece en junio).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_calcularplanillas_web]
    @cia          VARCHAR(10),
    @payrolltype  VARCHAR(20),
    @processtype  VARCHAR(20),
    @period       VARCHAR(10),
    @cesados      CHAR(1),
    @repunit      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LEFT(LTRIM(RTRIM(ISNULL(@cia, ''))), 10);
    SET @payrolltype = LEFT(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), 20);
    SET @processtype = LEFT(LTRIM(RTRIM(ISNULL(@processtype, ''))), 20);
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 10);

    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@repunit, '')) = '' SET @repunit = '0';

    DECLARE @fecha_inicio_mes DATE;
    DECLARE @fecha_fin_mes DATE;
    DECLARE @period_ym CHAR(6);

    SET @period_ym = LEFT(@period, 6);
    IF LEN(@period_ym) = 6 AND @period_ym NOT LIKE '%[^0-9]%'
    BEGIN
        SET @fecha_inicio_mes = CONVERT(DATE, @period_ym + '01', 112);
        SET @fecha_fin_mes = EOMONTH(@fecha_inicio_mes);
    END;

    SELECT
        LTRIM(RTRIM(
            ISNULL(SY_PERSON.LASTNAME1, '') + ' ' +
            ISNULL(SY_PERSON.LASTNAME2, '') + ' ' +
            ISNULL(SY_PERSON.NAME1, '') + ' ' +
            ISNULL(SY_PERSON.NAME2, '')
        )) AS [name],
        PR_EMPLOYEE.PERSON AS person,
        PR_EMPLOYEE.COMPANY AS company,
        PR_EMPLOYEE.PAYROLLTYPE AS payrolltype,
        ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS entrydate,
        PR_EMPLOYEE.CEASEDATE AS ceasedate,
        EPR.XLastDate AS calculationdate
    FROM PR_EMPLOYEE
        INNER JOIN SY_PERSON
            ON PR_EMPLOYEE.PERSON = SY_PERSON.PERSON
        LEFT JOIN PR_EmployeePayRoll EPR
            ON EPR.Person = PR_EMPLOYEE.Person
           AND EPR.Company = @cia
           AND EPR.PayRollType = @payrolltype
           AND EPR.ProcessType = @processtype
           AND LTRIM(RTRIM(EPR.PRPeriod)) = @period
    WHERE PR_EMPLOYEE.COMPANY = @cia
      AND PR_EMPLOYEE.PAYROLLTYPE = @payrolltype
      AND PR_EMPLOYEE.STATUS = 'N'
      AND (
            (
                @cesados = 'T'
                AND (
                    PR_EMPLOYEE.CEASEDATE IS NULL
                    OR @fecha_inicio_mes IS NULL
                    OR CONVERT(DATE, PR_EMPLOYEE.CEASEDATE) >= @fecha_inicio_mes
                )
            )
            OR (
                @cesados = 'Y'
                AND @fecha_inicio_mes IS NOT NULL
                AND @fecha_fin_mes IS NOT NULL
                AND PR_EMPLOYEE.CEASEDATE IS NOT NULL
                AND CONVERT(DATE, PR_EMPLOYEE.CEASEDATE) >= @fecha_inicio_mes
                AND CONVERT(DATE, PR_EMPLOYEE.CEASEDATE) <= @fecha_fin_mes
            )
            OR (
                @cesados = 'N'
                AND PR_EMPLOYEE.CEASEDATE IS NULL
            )
      )
      AND (@repunit = '0' OR SY_PERSON.REPLICATIONUNIT = @repunit)
      AND (
            @fecha_fin_mes IS NULL
            OR CONVERT(DATE, ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE)) <= @fecha_fin_mes
      )
    ORDER BY [name], person;
END
GO



-- ============================================================================
-- [13/89] sp_pr_cerrarperiodo_proceso_web.sql
-- ============================================================================

/*
    Cierra el periodo activo de un tipo de proceso (Status A/G → C).
    Usado por: POST /api/aperturar-periodos/cerrar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_cerrarperiodo_proceso_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @xlastuser   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LEFT(LTRIM(RTRIM(ISNULL(@cia, ''))), 4);
    SET @payrolltype = LEFT(LTRIM(RTRIM(ISNULL(@payrolltype, ''))), 20);
    SET @processtype = LEFT(LTRIM(RTRIM(ISNULL(@processtype, ''))), 20);
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), 20);

    IF @cia = '' OR @payrolltype = '' OR @processtype = ''
    BEGIN
        RAISERROR('Faltan parámetros para cerrar el periodo.', 16, 1);
        RETURN;
    END;

    UPDATE PR_ProcessControl
    SET Status = 'C',
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND Status IN ('A', 'G');
END
GO



-- ============================================================================
-- [14/89] sp_pr_control_pagos_afp_web.sql
-- ============================================================================

/*
    Control de Pagos AFP — resumen por tipo de planilla y AFP.
    Legacy PowerBuilder: PAGOS AFP (RPR001).

    Usado por: GET /afp/control-pagos, POST /reporte_control_pagos_afp

    Parámetros:
      @company    — código de compañía
      @payrolltype — tipo de planilla (obligatorio)
      @period     — periodo YYYYMM (6 dígitos)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_control_pagos_afp_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    SELECT
        P.description AS tipoplanilla,
        A.description AS afpname,
        COUNT(*) AS cantidad,
        SUM(ROUND(F.fixedamountlo, 2)) AS fixedamountlo,
        SUM(ROUND(F.insuredamountlo, 2)) AS insuredamountlo,
        SUM(ROUND(F.employercontributionlo, 2)) AS employercontributionlo,
        SUM(ROUND(F.variableamountlo, 2)) AS variableamountlo,
        SUM(ROUND(F.arcomisionamountlo, 2)) AS arcomisionamountlo
    FROM PR_EmployeeAFPHeader H (NOLOCK)
        INNER JOIN PR_EmployeeAFP F (NOLOCK)
            ON H.company = F.company
           AND H.replicationunit = F.replicationunit
           AND H.costcenter = F.costcenter
           AND H.prperiod = F.prperiod
           AND H.afp = F.afp
           AND H.payrolltype = F.payrolltype
        INNER JOIN PR_Employee E (NOLOCK)
            ON F.company = E.company
           AND F.person = E.person
        INNER JOIN PR_AFP A (NOLOCK)
            ON F.afp = A.afp
        INNER JOIN PR_PayRollType P (NOLOCK)
            ON E.payrolltype = P.payrolltype
    WHERE H.company = @company
      AND H.payrolltype = @payrolltype
      AND LEFT(H.prperiod, 6) = @period
    GROUP BY
        P.description,
        A.description
    ORDER BY
        P.description,
        A.description;
END
GO



-- ============================================================================
-- [15/89] sp_pr_datosusuario_web.sql
-- ============================================================================

/*
    Datos del usuario / trabajador para perfil web.

    Usado por: get_datos_usuario_web (database.py).

    Parámetros:
      @userid — SY_User.UserID (código de acceso)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_datosusuario_web]
    @userid VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));

    SELECT
        ISNULL(p.LastName1, '') AS primerapellido,
        ISNULL(p.LastName2, '') AS segundoapellido,
        ISNULL(p.Name1, '') + ' ' + ISNULL(p.Name2, '') AS nombres,
        ISNULL(SY_PersonDocumentType.Description, '') AS TipoDocumento,
        ISNULL(p.documentnumber, '') AS NroDocumento,
        ISNULL(PR_Nacionalidad.Description, '') AS LugarNacimiento,
        p.BirthDate AS FechaNacimiento,
        ISNULL(p.Telephone, '') AS TelefonoFijo,
        ISNULL(p.SecTelephone, '') AS Movil,
        ISNULL(p.EMail, '') AS email,
        ISNULL(p.Address, '') AS Direccion,
        ISNULL(SY_Localite.Name, '') AS distrito,
        ISNULL(SY_Province.Name, '') AS provincia,
        ISNULL(SY_Department.Name, '') AS departamento,
        '' AS Fotografia,
        E.Company AS company,
        E.Person AS person,
        p.Sex AS sexo,
        PP.Description AS cargo,
        B1.Name AS BancoSalario,
        E.SalaryAccount AS CuentaSalario,
        B2.Name AS BancoCTS,
        E.CTSAccount AS CuentaCTS,
        I.Description AS NivelInstruccion,
        PR_Institution.description AS Institucion,
        PR_Career.Description AS carrera,
        PR_EmployeeType.Description AS tipoempleado,
        ISNULL(E.ReEntryDate, E.EntryDate) AS FechaIngreso,
        HR_CONTRACTMODALITY.Description AS tipocontrato,
        PR_PensionType.Description AS Regimenenpension,
        ISNULL(E.AFPCard, '') AS cussp,
        'Si' AS AsignacionFamiliar,
        'Si' AS Afpmixta
    FROM SY_User u (NOLOCK)
        INNER JOIN SY_Person p (NOLOCK) ON p.UserID = u.UserID
        INNER JOIN PR_Employee E (NOLOCK) ON p.Person = E.Person AND E.Status = 'N'
        INNER JOIN PR_Position PP (NOLOCK) ON E.Position = PP.Position
        INNER JOIN SY_Company c (NOLOCK) ON E.Company = c.Company
        INNER JOIN SY_UserProfile up (NOLOCK) ON up.UserID = u.UserID
        INNER JOIN PR_mapping2 M (NOLOCK) ON c.Company = M.company
        LEFT JOIN SY_Localite (NOLOCK) ON p.Localite = SY_Localite.Localite
        LEFT JOIN SY_Province (NOLOCK)
            ON p.Province = SY_Province.Province
           AND SY_Province.Province = SY_Localite.Province
        LEFT JOIN SY_Department (NOLOCK)
            ON p.Department = SY_Department.Department
           AND SY_Province.Department = SY_Department.Department
        LEFT JOIN PR_Nacionalidad (NOLOCK) ON P.Nationality = PR_Nacionalidad.Nacionalidad
        INNER JOIN SY_PersonDocumentType (NOLOCK)
            ON P.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
        LEFT JOIN ERP_Bank B1 (NOLOCK) ON E.SalaryBank = B1.Bank
        LEFT JOIN ERP_Bank B2 (NOLOCK) ON E.CTSBank = B2.Bank
        LEFT JOIN PR_InstructionLevel I ON p.InstructionLevel = I.InstructionLevel
        LEFT JOIN PR_Institution
            ON p.costcenter1 = PR_Institution.pdt
           AND PR_Institution.Company = E.Company
        LEFT JOIN PR_Career
            ON PR_Institution.Institution = PR_Career.Institution
           AND PR_Career.pdt = p.costcenter2
        LEFT JOIN PR_EmployeeType ON E.employeetype = PR_EmployeeType.employeetype
        LEFT JOIN HR_CONTRACTMODALITY ON E.ContractModality = HR_CONTRACTMODALITY.ContractModality
        LEFT JOIN PR_PensionType ON E.PensionType = PR_PensionType.PensionType
    WHERE u.UserID = @userid;
END
GO



-- ============================================================================
-- [16/89] sp_pr_detalleboletaaportes_web.sql
-- ============================================================================

/*
    Generar boletas — detalle de aportes para el PDF.

    Usado por: generar_pdf_en_memoria (app.py).

    Parámetros:
      @cia, @process, @payrolltype, @period, @person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_detalleboletaaportes_web]
    @cia         VARCHAR(4),
    @process     VARCHAR(20),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        C.person,
        pr_concepttype.shortname,
        pr_concept.printtext,
        C.conceptvalue,
        pr_concept.conceptorder
    FROM pr_concept (NOLOCK),
         pr_concepttype (NOLOCK),
         pr_employeepayrollconcept C (NOLOCK)
    WHERE C.concept = pr_concept.concept
      AND pr_concept.concepttype = pr_concepttype.concepttype
      AND C.company = @cia
      AND C.processtype = @process
      AND C.payrolltype = @payrolltype
      AND C.prperiod = @period
      AND C.person = @person
      AND ISNULL(pr_concept.flagpayrollticket, 'N') = 'Y'
      AND pr_concepttype.shortname = 'A'
    ORDER BY 5;
END
GO



-- ============================================================================
-- [17/89] sp_pr_detalleboletadescuentos_web.sql
-- ============================================================================

/*
    Generar boletas — detalle de descuentos para el PDF.

    Usado por: generar_pdf_en_memoria (app.py).

    Parámetros:
      @cia, @process, @payrolltype, @period, @person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_detalleboletadescuentos_web]
    @cia         VARCHAR(4),
    @process     VARCHAR(20),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        C.person,
        pr_concepttype.shortname,
        pr_concept.printtext,
        C.conceptvalue,
        pr_concept.conceptorder
    FROM pr_concept (NOLOCK),
         pr_concepttype (NOLOCK),
         pr_employeepayrollconcept C (NOLOCK)
    WHERE C.concept = pr_concept.concept
      AND pr_concept.concepttype = pr_concepttype.concepttype
      AND C.company = @cia
      AND C.processtype = @process
      AND C.payrolltype = @payrolltype
      AND C.prperiod = @period
      AND C.person = @person
      AND ISNULL(pr_concept.flagpayrollticket, 'N') = 'Y'
      AND pr_concepttype.shortname = 'D'
    ORDER BY 5;
END
GO



-- ============================================================================
-- [18/89] sp_pr_detalleboletaingresos_web.sql
-- ============================================================================

/*
    Generar boletas — detalle de ingresos para el PDF.

    Usado por: generar_pdf_en_memoria (app.py).

    Parámetros:
      @cia, @process, @payrolltype, @period, @person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_detalleboletaingresos_web]
    @cia         VARCHAR(4),
    @process     VARCHAR(20),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        C.person,
        pr_concepttype.shortname,
        pr_concept.printtext,
        C.conceptvalue,
        pr_concept.conceptorder
    FROM pr_concept (NOLOCK),
         pr_concepttype (NOLOCK),
         pr_employeepayrollconcept C (NOLOCK)
    WHERE C.concept = pr_concept.concept
      AND pr_concept.concepttype = pr_concepttype.concepttype
      AND C.company = @cia
      AND C.processtype = @process
      AND C.payrolltype = @payrolltype
      AND C.prperiod = @period
      AND C.person = @person
      AND ISNULL(pr_concept.flagpayrollticket, 'N') = 'Y'
      AND pr_concepttype.shortname = 'I'
    ORDER BY 5;
END
GO



-- ============================================================================
-- [19/89] sp_pr_eliminar_calculo_planilla_web.sql
-- ============================================================================

/*
    Elimina el cálculo de planilla de un trabajador para compañía, tipo, proceso y periodo.
    Equivalente web al proceso legacy de PowerBuilder (eliminar cálculo).
    Usado por: POST /api/procesar-planilla/eliminar-calculo (procesar_planilla.html).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminar_calculo_planilla_web]
    @company     VARCHAR(10),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(10),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    IF @company = '' OR @payrolltype = '' OR @processtype = '' OR @period = ''
    BEGIN
        RAISERROR('Faltan compañía, tipo de planilla, proceso o periodo.', 16, 1);
        RETURN;
    END;

    IF @person = ''
    BEGIN
        RAISERROR('Debe seleccionar un trabajador.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM PR_IntegralProcessLog
        WHERE Company = @company
          AND PRPeriod = @period
          AND Person = @person;

        DELETE FROM PR_EMPLOYEEAFP
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND PRPeriod = @period
          AND Person = @person;

        DELETE FROM PR_EmployeePayRollConcept
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND ProcessType = @processtype
          AND PRPeriod = @period
          AND Person = @person;

        DELETE FROM PR_EmployeePayRoll
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND ProcessType = @processtype
          AND PRPeriod = @period
          AND Person = @person;

        DELETE FROM PR_LOG_CALCULO_PLANILLAS
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND Process = @processtype
          AND Period = @period
          AND Person = @person;

        DELETE FROM PR_PayrollLog
        WHERE Company = @company
          AND PayRollType = @payrolltype
          AND ProcessType = @processtype
          AND PRPeriod = @period
          AND Person = @person;

        COMMIT TRANSACTION;

        SELECT 1 AS ok, @person AS person;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH;
END
GO



-- ============================================================================
-- [20/89] sp_pr_eliminarasignacionconcepto_web.sql
-- ============================================================================

/*
    Elimina una asignación de concepto (PR_EmployeeConcept).
    Clave: person, company, concept, payrolltype, prperiodstart, costcenter.
    Usado por: POST /api/asignacion-conceptos/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarasignacionconcepto_web]
    @par_company       VARCHAR(10),
    @par_person        VARCHAR(20),
    @par_concept       VARCHAR(20),
    @par_payrolltype   VARCHAR(20),
    @par_prperiodstart VARCHAR(10),
    @par_costcenter    VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @par_company = LTRIM(RTRIM(ISNULL(@par_company, '')));
    SET @par_person = LTRIM(RTRIM(ISNULL(@par_person, '')));
    SET @par_concept = LTRIM(RTRIM(ISNULL(@par_concept, '')));
    SET @par_payrolltype = LTRIM(RTRIM(ISNULL(@par_payrolltype, '')));
    SET @par_prperiodstart = LTRIM(RTRIM(ISNULL(@par_prperiodstart, '')));
    SET @par_costcenter = LTRIM(RTRIM(ISNULL(@par_costcenter, '')));

    IF @par_company = '' OR @par_person = '' OR @par_concept = '' OR @par_payrolltype = '' OR @par_prperiodstart = ''
    BEGIN
        RAISERROR('Faltan datos de la asignación a eliminar.', 16, 1);
        RETURN;
    END

    DELETE FROM PR_EmployeeConcept
    WHERE Person = @par_person
      AND Company = @par_company
      AND Concept = @par_concept
      AND PayRollType = @par_payrolltype
      AND PRPeriodStart = @par_prperiodstart
      AND CostCenter = @par_costcenter;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('No se encontró la asignación a eliminar.', 16, 1);
        RETURN;
    END
END
GO



-- ============================================================================
-- [21/89] sp_pr_eliminarconcepto_web.sql
-- ============================================================================

/*
    Elimina un concepto del maestro (PR_Concept) si no está en uso.

    No permite eliminar si el concepto existe en:
      - PR_EmployeeConcept
      - PR_EmployeePayRollConcept
      - PR_EmployeeAFP (vía movimientos de planilla vinculados a AFP)

    Usado por: POST /api/conceptos/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarconcepto_web]
    @company VARCHAR(4),
    @concept VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @concept = LTRIM(RTRIM(ISNULL(@concept, '')));

    IF @company = '' OR @concept = ''
    BEGIN
        RAISERROR('Indique compañía y concepto a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Concept (NOLOCK)
        WHERE Company = @company
          AND Concept = @concept
    )
    BEGIN
        RAISERROR('El concepto no existe o no pertenece a la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_EmployeeConcept (NOLOCK)
        WHERE Company = @company
          AND Concept = @concept
    )
    BEGIN
        RAISERROR('No se puede eliminar: el concepto está asignado a empleados (PR_EmployeeConcept).', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_EmployeePayRollConcept (NOLOCK)
        WHERE Company = @company
          AND Concept = @concept
    )
    BEGIN
        RAISERROR('No se puede eliminar: el concepto tiene movimientos de planilla (PR_EmployeePayRollConcept).', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_EmployeePayRollConcept P (NOLOCK)
            INNER JOIN PR_EmployeeAFP A (NOLOCK)
                ON A.Company = P.Company
               AND A.Person = P.Person
               AND A.PayRollType = P.PayRollType
               AND LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), P.PRPeriod))), 6)
                 = LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), A.PRPeriod))), 6)
        WHERE P.Company = @company
          AND P.Concept = @concept
    )
    BEGIN
        RAISERROR('No se puede eliminar: el concepto está vinculado a registros AFP (PR_EmployeeAFP).', 16, 1);
        RETURN;
    END;

    DELETE FROM PR_Concept
    WHERE Company = @company
      AND Concept = @concept;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('No se pudo eliminar el concepto.', 16, 1);
        RETURN;
    END;

    SELECT
        @concept AS concept,
        'Concepto eliminado correctamente.' AS mensaje;
END
GO



-- ============================================================================
-- [22/89] sp_pr_genera_correlativo_web.sql
-- ============================================================================

/*
    Genera el siguiente ID correlativo para un objeto (tabla maestra).

    Formato del ID:
      LEFT(@cia + '    ', 4) + RIGHT('000000000000' + correlativo, 12)
      Ejemplo BGT:  'BGT 000000000004'

    Lee e incrementa SY_ObjectSecuence (ReplicationUnit = LIMA).
    Devuelve el ID generado en resultset: id_generado.

    Usado por: sp_pr_guardarconcepto_web y futuro maestro de conceptos.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_genera_correlativo_web]
    @cia        VARCHAR(4),
    @object     VARCHAR(20),
    @xlastuser  VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @secuence        NUMERIC(18, 0);
    DECLARE @next            NUMERIC(18, 0);
    DECLARE @id_generado     VARCHAR(20);
    DECLARE @prefix          CHAR(4);

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @object = UPPER(LTRIM(RTRIM(ISNULL(@object, ''))));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @cia = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @object = ''
    BEGIN
        RAISERROR('Indique el objeto correlativo.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @secuence = Secuence
        FROM SY_ObjectSecuence WITH (UPDLOCK, HOLDLOCK)
        WHERE Company = @cia
          AND Object = @object
          AND ReplicationUnit = @replicationunit;

        IF @secuence IS NULL
        BEGIN
            RAISERROR(
                'No existe correlativo en SY_ObjectSecuence para compañía %s, objeto %s y unidad %s.',
                16,
                1,
                @cia,
                @object,
                @replicationunit
            );
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        SET @next = @secuence + 1;
        SET @prefix = LEFT(@cia + '    ', 4);
        SET @id_generado = @prefix + RIGHT(
            '000000000000' + CONVERT(VARCHAR(12), CONVERT(BIGINT, @next)),
            12
        );

        UPDATE SY_ObjectSecuence
        SET Secuence = @next,
            XLastUser = ISNULL(@xlastuser, XLastUser),
            XLastDate = GETDATE()
        WHERE Company = @cia
          AND Object = @object
          AND ReplicationUnit = @replicationunit;

        COMMIT TRANSACTION;

        SELECT @id_generado AS id_generado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO



-- ============================================================================
-- [23/89] sp_pr_generar_banbif_web.sql
-- ============================================================================

/*
    Genera líneas de detalle del archivo BANBIF / BXIE (213 caracteres por registro).
    No incluye cabecera (igual que el sistema PowerBuilder anterior).
    Requiere #BanbifPersonas (person) cargada por la app web.
    Banco destino: pr_mapping.banbifbank.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_banbif_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @todos_bancos    CHAR(1) = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@todos_bancos, '')) = '' SET @todos_bancos = 'N';
    SET @todos_bancos = UPPER(@todos_bancos);
    IF @todos_bancos NOT IN ('Y', 'N') SET @todos_bancos = 'N';

    IF OBJECT_ID('tempdb..#BanbifPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #BanbifPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @collectionform VARCHAR(20);
    DECLARE @banbifbank     VARCHAR(20);
    DECLARE @tipo_moneda    CHAR(1);

    SELECT @collectionform = LTRIM(RTRIM(ISNULL(m.collectionform, ''))),
           @banbifbank = LTRIM(RTRIM(ISNULL(m.banbifbank, '')))
    FROM pr_mapping m
    WHERE m.company = @par_company;

    IF @collectionform = ''
    BEGIN
        RAISERROR('Configure la forma de pago (CollectionForm) en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    IF @banbifbank = ''
    BEGIN
        RAISERROR('Configure BanbifBank en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    SET @tipo_moneda = CASE WHEN @par_currency = 'EX' THEN '2' ELSE '1' END;

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #BanbifPersonas tp
        WHERE LTRIM(RTRIM(ISNULL(tp.person, ''))) <> ''
    ),
    Pagos AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc
            INNER JOIN PersonasSel ps ON ps.person = epc.person
            INNER JOIN PR_Employee emp
                ON emp.person = epc.person
               AND emp.company = epc.company
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
          AND emp.collectionform = @collectionform
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    ),
    DetalleBase AS (
        SELECT
            e.person,
            CASE
                WHEN ISNULL(pdt.PDT, '') IN ('01', '1') THEN '1'
                WHEN ISNULL(pdt.PDT, '') IN ('04', '4') THEN '3'
                WHEN ISNULL(pdt.PDT, '') IN ('07', '7') THEN '4'
                ELSE ' '
            END AS tipo_doc_txt,
            LTRIM(RTRIM(ISNULL(sp.DocumentNumber, ''))) AS documentnumber,
            LTRIM(RTRIM(ISNULL(sp.lastname1, ''))) AS lastname1,
            LTRIM(RTRIM(ISNULL(sp.lastname2, ''))) AS lastname2,
            LTRIM(RTRIM(
                LTRIM(RTRIM(ISNULL(sp.name1, ''))) + ' ' +
                LTRIM(RTRIM(ISNULL(sp.name2, '')))
            )) AS nombres,
            LEFT(
                CASE
                    WHEN LEN(LTRIM(RTRIM(ISNULL(eb.PDT, '')))) = 2
                        THEN '0' + LTRIM(RTRIM(eb.PDT))
                    ELSE LEFT(LTRIM(RTRIM(ISNULL(eb.PDT, ''))) + REPLICATE(' ', 3), 3)
                END,
                3
            ) AS codbank,
            LEFT(
                LTRIM(RTRIM(
                    CASE
                        WHEN @todos_bancos = 'Y' THEN ISNULL(e.socialassistancenumber, '')
                        WHEN @par_currency = 'EX' THEN ISNULL(e.socialassistancecenter, '')
                        ELSE ISNULL(e.salaryaccount, '')
                    END
                )) + REPLICATE(' ', 20),
                20
            ) AS cuenta_empleado,
            p.importe
        FROM PR_Employee e
            INNER JOIN SY_Person sp ON sp.person = e.person
            INNER JOIN pr_mapping m ON m.company = e.company
            INNER JOIN Pagos p ON p.person = e.person
            INNER JOIN PersonasSel ps ON ps.person = e.person
            LEFT JOIN SY_PersonDocumentType pdt
                ON pdt.PersonDocumentType = sp.EmployeeDocumentType
            LEFT JOIN ERP_Bank eb
                ON eb.bank = e.salarybank
               AND eb.company = e.company
            LEFT JOIN te_accounttype tat
                ON tat.accounttype = e.salaryaccounttype
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND (
                e.salarycurrency = @par_currency
             OR (@par_currency = 'EX' AND ISNULL(e.socialassistancecenter, '') <> '')
          )
          AND ISNULL(m.banbifbank, '') <> ''
          AND e.collectionform = @collectionform
          AND (
                (@todos_bancos = 'N' AND e.salarybank = m.banbifbank)
             OR (
                    @todos_bancos = 'Y'
                    AND e.salarybank <> m.banbifbank
                    AND (
                        ISNULL(tat.abrev, '') = 'B'
                     OR UPPER(ISNULL(tat.description, '')) LIKE '%INTERBANCARIA%'
                    )
                    AND ISNULL(e.socialassistancenumber, '') <> ''
                )
          )
          AND sp.status = 'A'
          AND (
                CASE
                    WHEN e.status IS NULL THEN 'N'
                    WHEN e.status = '' THEN 'N'
                    WHEN e.status = 'N' THEN 'N'
                    ELSE 'Y'
                END = 'N'
             OR e.ineffectivedate >= GETDATE()
          )
    ),
    Numerado AS (
        SELECT
            *,
            ROW_NUMBER() OVER (
                ORDER BY lastname1, lastname2, nombres, person
            ) AS orden
        FROM DetalleBase
        WHERE LTRIM(RTRIM(cuenta_empleado)) <> ''
    )
    SELECT
        orden,
        LEFT(
            LEFT(CAST(orden AS VARCHAR(10)) + REPLICATE(' ', 7), 7) +
            tipo_doc_txt +
            LEFT(documentnumber + REPLICATE(' ', 11), 11) +
            LEFT(lastname1 + REPLICATE(' ', 20), 20) +
            LEFT(lastname2 + REPLICATE(' ', 20), 20) +
            LEFT(nombres + REPLICATE(' ', 44), 44) +
            REPLICATE(' ', 60) +
            REPLICATE(' ', 10) +
            'H' +
            codbank +
            cuenta_empleado +
            @tipo_moneda +
            RIGHT(
                REPLICATE('0', 14) +
                CAST(CAST(ROUND(ISNULL(importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
                14
            ) +
            '5',
            213
        ) AS linea_txt
    FROM Numerado
    ORDER BY orden;
END
GO



-- ============================================================================
-- [24/89] sp_pr_generar_continental_web.sql
-- ============================================================================

/*
    Genera archivo Continental / BBVA (cabecera 151 + detalle 233 chars).
    Requiere #ContinentalPersonas (person) cargada por la app web.
    Banco destino: pr_mapping.continentalbank.
    Cuenta origen: TE_BankAccount vía continentalbank y moneda.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_continental_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();

    IF OBJECT_ID('tempdb..#ContinentalPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #ContinentalPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @tipo_operacion   CHAR(3);
    DECLARE @cuenta_origen    VARCHAR(20);
    DECLARE @moneda_txt       CHAR(3);
    DECLARE @collectionform   VARCHAR(20);
    DECLARE @continentalbank  VARCHAR(20);
    DECLARE @ref_cabecera     VARCHAR(25);
    DECLARE @ref_detalle      VARCHAR(40);
    DECLARE @empresa_aci      CHAR(1);
    DECLARE @total_reg        INT;
    DECLARE @total_importe    DECIMAL(18, 2);
    DECLARE @importe15        VARCHAR(15);
    DECLARE @linea_cabecera   VARCHAR(151);

    SELECT @collectionform = LTRIM(RTRIM(ISNULL(m.collectionform, ''))),
           @continentalbank = LTRIM(RTRIM(ISNULL(m.continentalbank, '')))
    FROM pr_mapping m
    WHERE m.company = @par_company;

    IF @collectionform = ''
    BEGIN
        RAISERROR('Configure la forma de pago (CollectionForm) en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    IF @continentalbank = ''
    BEGIN
        RAISERROR('Configure ContinentalBank en PR_Mapping para la compañía.', 16, 1);
        RETURN;
    END

    SELECT @cuenta_origen = LEFT(LTRIM(RTRIM(ISNULL(ba.BankAccountNumber, ''))), 20)
    FROM TE_BankAccount ba
    WHERE ba.Company = @par_company
      AND ba.Bank = @continentalbank
      AND ba.accountcurrency = @par_currency;

    IF @cuenta_origen IS NULL OR LTRIM(RTRIM(@cuenta_origen)) = ''
    BEGIN
        RAISERROR('No se encontró cuenta origen Continental en TE_BankAccount para la compañía/moneda.', 16, 1);
        RETURN;
    END

    SET @moneda_txt = CASE WHEN @par_currency = 'EX' THEN 'USD' ELSE 'PEN' END;

    IF EXISTS (
        SELECT 1
        FROM PR_PayRollType pt
        WHERE pt.Company = @par_company
          AND pt.PayRollType = @par_payrolltype
          AND (
                UPPER(ISNULL(pt.ShortName, '')) LIKE '%4TA%'
             OR UPPER(ISNULL(pt.ShortName, '')) LIKE '%HONORARIOS%'
          )
    )
        SET @tipo_operacion = '800';
    ELSE
        SET @tipo_operacion = '700';

    SELECT @ref_cabecera = LEFT(
        LTRIM(RTRIM(ISNULL(pt.Description, ISNULL(pt.ShortName, @par_processtype)))),
        25
    )
    FROM PR_ProcessType pt
    WHERE pt.Company = @par_company
      AND pt.ProcessType = @par_processtype;

    IF @ref_cabecera IS NULL SET @ref_cabecera = '';
    SET @ref_cabecera = LEFT(@ref_cabecera + REPLICATE(' ', 25), 25);

    SELECT @ref_detalle = LEFT(
        LTRIM(RTRIM(ISNULL(pc.Description, @par_concept))),
        40
    )
    FROM PR_Concept pc
    WHERE pc.Company = @par_company
      AND pc.Concept = @par_concept;

    IF @ref_detalle IS NULL SET @ref_detalle = '';
    SET @ref_detalle = LEFT(@ref_detalle + REPLICATE(' ', 40), 40);

    IF EXISTS (
        SELECT 1 FROM sy_company sc
        WHERE sc.company = @par_company
          AND LTRIM(RTRIM(ISNULL(sc.email_server, ''))) = 'ACI'
    )
        SET @empresa_aci = 'Y';
    ELSE
        SET @empresa_aci = 'N';

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #ContinentalPersonas tp
        WHERE LTRIM(RTRIM(ISNULL(tp.person, ''))) <> ''
    ),
    Pagos AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc
            INNER JOIN PersonasSel ps ON ps.person = epc.person
            INNER JOIN PR_Employee emp
                ON emp.person = epc.person
               AND emp.company = epc.company
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
          AND emp.collectionform = @collectionform
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    ),
    DetalleBase AS (
        SELECT
            e.person,
            CASE
                WHEN ISNULL(sp.Ruc, '') <> '' AND ISNULL(sp.flagrucpersontype, '') = '20' THEN 'R'
                WHEN ISNULL(pdt.PDT, '') IN ('01', '1') THEN 'L'
                WHEN ISNULL(pdt.PDT, '') IN ('04', '4') THEN 'E'
                WHEN ISNULL(pdt.PDT, '') IN ('07', '7') THEN 'P'
                ELSE 'L'
            END AS doi_tipo,
            LTRIM(RTRIM(ISNULL(sp.DocumentNumber, ''))) AS documentnumber,
            LTRIM(RTRIM(ISNULL(sp.Ruc, ''))) AS ruc,
            LTRIM(RTRIM(ISNULL(sp.lastdocumentnumber, ''))) AS lastdocumentnumber,
            UPPER(LTRIM(RTRIM(
                ISNULL(sp.lastname1, '') + ' ' +
                ISNULL(sp.lastname2, '') + ' ' +
                ISNULL(sp.name1, '') + ' ' +
                ISNULL(sp.name2, '')
            ))) AS nombre,
            CASE WHEN e.salarybank = m.continentalbank THEN 'P' ELSE 'I' END AS tipo_abono,
            LEFT(
                LTRIM(RTRIM(
                    CASE
                        WHEN ISNULL(tat.abrev, '') = 'B' AND @empresa_aci = 'Y'
                            THEN ISNULL(e.socialassistancenumber, '')
                        ELSE ISNULL(e.salaryaccount, '')
                    END
                )) + REPLICATE(' ', 20),
                20
            ) AS cuenta_empleado,
            p.importe
        FROM PR_Employee e
            INNER JOIN SY_Person sp ON sp.person = e.person
            INNER JOIN pr_mapping m ON m.company = e.company
            INNER JOIN Pagos p ON p.person = e.person
            INNER JOIN PersonasSel ps ON ps.person = e.person
            LEFT JOIN SY_PersonDocumentType pdt
                ON pdt.PersonDocumentType = sp.EmployeeDocumentType
            LEFT JOIN te_accounttype tat
                ON tat.accounttype = e.salaryaccounttype
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND e.salarycurrency = @par_currency
          AND ISNULL(m.continentalbank, '') <> ''
          AND e.collectionform = @collectionform
          AND e.salarybank = m.continentalbank
          AND sp.status = 'A'
          AND (
                CASE
                    WHEN e.status IS NULL THEN 'N'
                    WHEN e.status = '' THEN 'N'
                    WHEN e.status = 'N' THEN 'N'
                    ELSE 'Y'
                END = 'N'
             OR e.ineffectivedate >= GETDATE()
          )
    )
    SELECT
        person,
        doi_tipo,
        CASE
            WHEN doi_tipo = 'R' THEN LEFT(ruc + REPLICATE(' ', 12), 12)
            WHEN doi_tipo = 'E' THEN LEFT(lastdocumentnumber + REPLICATE(' ', 12), 12)
            ELSE LEFT(documentnumber + REPLICATE(' ', 12), 12)
        END AS documento_fmt,
        tipo_abono,
        cuenta_empleado,
        LEFT(nombre + REPLICATE(' ', 40), 40) AS nombre_fmt,
        importe,
        RIGHT(
            REPLICATE('0', 15) +
            CAST(CAST(ROUND(ISNULL(importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
            15
        ) AS importe15
    INTO #Detalle
    FROM DetalleBase
    WHERE LTRIM(RTRIM(cuenta_empleado)) <> '';

    SELECT @total_reg = COUNT(*), @total_importe = ISNULL(SUM(importe), 0)
    FROM #Detalle;

    SET @importe15 = RIGHT(
        REPLICATE('0', 15) +
        CAST(CAST(ROUND(ISNULL(@total_importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
        15
    );

    SET @linea_cabecera =
        @tipo_operacion +
        LEFT(@cuenta_origen + REPLICATE(' ', 20), 20) +
        @moneda_txt +
        @importe15 +
        'A' +
        REPLICATE(' ', 8) +
        REPLICATE(' ', 1) +
        @ref_cabecera +
        RIGHT(REPLICATE('0', 6) + CAST(@total_reg AS VARCHAR(10)), 6) +
        'S' +
        REPLICATE(' ', 68);

    SELECT orden, linea_txt
    FROM (
        SELECT 0 AS orden, @linea_cabecera AS linea_txt
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY nombre_fmt, person) AS orden,
            LEFT(
                '002' +
                doi_tipo +
                documento_fmt +
                tipo_abono +
                cuenta_empleado +
                nombre_fmt +
                importe15 +
                @ref_detalle +
                REPLICATE(' ', 101),
                233
            ) AS linea_txt
        FROM #Detalle
    ) AS lineas
    ORDER BY orden;
END
GO



-- ============================================================================
-- [25/89] sp_pr_generar_interbank_web.sql
-- ============================================================================

/*
    Genera líneas del archivo Interbank (cabecera tipo 01 + detalle tipo 02).
    Layout según Macro Pagos Masivos Interbank / txt_ibk.txt (haberes, servicio 04):
      Cabecera 104 chars | Detalle 380 chars.
    Requiere #InterbankPersonas (person) cargada por la app web.
    Banco destino: pr_mapping.interbankbank.
    Código empresa en cabecera (pos. 100-104): MC001 (temporal, en duro).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_interbank_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();

    IF OBJECT_ID('tempdb..#InterbankPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #InterbankPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @fecha_envio     VARCHAR(14);
    DECLARE @codigo_empresa  VARCHAR(5);
    DECLARE @total_reg       INT;
    DECLARE @total_soles     DECIMAL(18, 2);
    DECLARE @total_dolares   DECIMAL(18, 2);
    DECLARE @importe_soles   VARCHAR(17);
    DECLARE @importe_dolares VARCHAR(13);
    DECLARE @linea_cabecera  VARCHAR(104);

    SET @fecha_envio =
        CONVERT(VARCHAR(8), GETDATE(), 112) +
        RIGHT('0' + CAST(DATEPART(HOUR, GETDATE()) AS VARCHAR(2)), 2) +
        RIGHT('0' + CAST(DATEPART(MINUTE, GETDATE()) AS VARCHAR(2)), 2) +
        RIGHT('0' + CAST(DATEPART(SECOND, GETDATE()) AS VARCHAR(2)), 2);

    SET @codigo_empresa = 'MC001';

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #InterbankPersonas tp
        WHERE LTRIM(RTRIM(ISNULL(tp.person, ''))) <> ''
    ),
    Pagos AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc
            INNER JOIN PersonasSel ps ON ps.person = epc.person
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    ),
    DetalleBase AS (
        SELECT
            e.person,
            LEFT(
                CASE
                    WHEN LEFT(LTRIM(RTRIM(ISNULL(e.salaryaccount, ''))), 2) = '09'
                        THEN LTRIM(RTRIM(e.salaryaccount))
                    ELSE '09' + LTRIM(RTRIM(ISNULL(e.salaryaccount, '')))
                END + REPLICATE(' ', 20),
                20
            ) AS cuenta,
            CASE
                WHEN ISNULL(pdt.PDT, '') IN ('01', '1') THEN '01'
                WHEN ISNULL(pdt.PDT, '') IN ('04', '4', '03', '3') THEN '04'
                WHEN ISNULL(pdt.PDT, '') IN ('06', '6') THEN '06'
                WHEN ISNULL(pdt.PDT, '') IN ('07', '7') THEN '07'
                ELSE '01'
            END AS tipodocumento,
            LTRIM(RTRIM(
                CASE
                    WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                    ELSE sp.DocumentNumber
                END
            )) AS numerodocumento,
            LTRIM(RTRIM(ISNULL(sp.lastname1, ''))) AS apellido1,
            LTRIM(RTRIM(ISNULL(sp.lastname2, ''))) AS apellido2,
            LTRIM(RTRIM(
                LTRIM(RTRIM(ISNULL(sp.name1, ''))) +
                CASE
                    WHEN LTRIM(RTRIM(ISNULL(sp.name2, ''))) <> ''
                        THEN ' ' + LTRIM(RTRIM(sp.name2))
                    ELSE ''
                END
            )) AS nombres,
            p.importe
        FROM PR_Employee e
            INNER JOIN SY_Person sp ON sp.person = e.person
            INNER JOIN pr_mapping m ON m.company = e.company
            INNER JOIN Pagos p ON p.person = e.person
            INNER JOIN PersonasSel ps ON ps.person = e.person
            LEFT JOIN SY_PersonDocumentType pdt
                ON pdt.PersonDocumentType = sp.EmployeeDocumentType
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND ISNULL(e.salaryaccount, '') <> ''
          AND ISNULL(m.interbankbank, '') <> ''
          AND e.salarybank = m.interbankbank
          AND sp.status = 'A'
          AND (
                CASE
                    WHEN e.status IS NULL THEN 'N'
                    WHEN e.status = '' THEN 'N'
                    WHEN e.status = 'N' THEN 'N'
                    ELSE 'Y'
                END = 'N'
             OR e.ineffectivedate >= GETDATE()
          )
    )
    SELECT
        person,
        cuenta,
        tipodocumento,
        numerodocumento,
        apellido1,
        apellido2,
        nombres,
        importe,
        RIGHT(
            REPLICATE('0', 15) +
            CAST(CAST(ROUND(ISNULL(importe, 0), 2) * 100 AS BIGINT) AS VARCHAR(20)),
            15
        ) AS importe15,
        LEFT(
            'P' + RIGHT(REPLICATE('0', 10) + numerodocumento, 10),
            11
        ) AS referencia,
        LEFT(REPLICATE(' ', 6) + apellido1 + REPLICATE(' ', 14), 20) AS apellido1_fmt,
        LEFT(REPLICATE(' ', 6) + apellido2 + REPLICATE(' ', 14), 20) AS apellido2_fmt,
        LEFT(REPLICATE(' ', 6) + nombres + REPLICATE(' ', 22), 28) AS nombres_fmt
    INTO #Detalle
    FROM DetalleBase;

    SELECT @total_reg = COUNT(*) FROM #Detalle;

    IF @par_currency = 'LO'
    BEGIN
        SELECT @total_soles = ISNULL(SUM(importe), 0) FROM #Detalle;
        SET @total_dolares = 0;
    END
    ELSE
    BEGIN
        SELECT @total_dolares = ISNULL(SUM(importe), 0) FROM #Detalle;
        SET @total_soles = 0;
    END

    SET @importe_soles = RIGHT(
        REPLICATE('0', 17) +
        CAST(CAST(ROUND(ISNULL(@total_soles, 0), 2) * 10000 AS BIGINT) AS VARCHAR(20)),
        17
    );
    SET @importe_dolares = RIGHT(
        REPLICATE('0', 13) +
        CAST(CAST(ROUND(ISNULL(@total_dolares, 0), 2) * 10000 AS BIGINT) AS VARCHAR(20)),
        13
    );

    SET @linea_cabecera =
        '01' +
        '04' +
        REPLICATE(' ', 36) +
        @fecha_envio +
        REPLICATE(' ', 9) +
        RIGHT(REPLICATE('0', 6) + CAST(@total_reg AS VARCHAR(10)), 6) +
        @importe_soles +
        @importe_dolares +
        LEFT(@codigo_empresa + REPLICATE(' ', 5), 5);

    /*
        Detalle tipo 02 (380 chars):
        02 + secuencial(10) + esp(39) + tipodoc(2) + importe(15) + esp(1) + cuenta(20)
        + esp(10) + P+doc(11) + esp(1) + apellido1(20) + apellido2(20) + nombres(28)
        + importe_cta(15 ceros haberes) + filler(186)
    */
    ;WITH DetalleSeq AS (
        SELECT
            d.*,
            ROW_NUMBER() OVER (ORDER BY d.apellido1, d.apellido2, d.nombres, d.person) AS seq
        FROM #Detalle d
    )
    SELECT orden, linea_txt
    FROM (
        SELECT 0 AS orden, @linea_cabecera AS linea_txt
        UNION ALL
        SELECT
            seq AS orden,
            LEFT(
                '02' +
                LEFT(CAST(seq AS VARCHAR(10)) + REPLICATE(' ', 10), 10) +
                REPLICATE(' ', 39) +
                tipodocumento +
                importe15 +
                ' ' +
                cuenta +
                REPLICATE(' ', 10) +
                referencia +
                ' ' +
                apellido1_fmt +
                apellido2_fmt +
                nombres_fmt +
                '000000000000000' +
                REPLICATE(' ', 186),
                380
            ) AS linea_txt
        FROM DetalleSeq
    ) AS lineas
    ORDER BY orden;
END
GO



-- ============================================================================
-- [26/89] sp_pr_generar_telecredito_web.sql
-- ============================================================================

/*
    Genera líneas del archivo Telecrédito BCP (cabecera tipo 1 + detalle tipo 2).
    Requiere tabla temporal #TelecreditoPersonas (person) creada por la app web
    con los trabajadores seleccionados antes de ejecutar este SP.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generar_telecredito_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();

    IF OBJECT_ID('tempdb..#TelecreditoPersonas') IS NULL
    BEGIN
        RAISERROR('Falta la tabla temporal #TelecreditoPersonas con los trabajadores seleccionados.', 16, 1);
        RETURN;
    END

    DECLARE @moneda_txt      VARCHAR(4);
    DECLARE @tipo_proceso    CHAR(1);
    DECLARE @cuenta_origen   VARCHAR(20);
    DECLARE @tipo_cta_origen CHAR(1);
    DECLARE @ref_planilla    VARCHAR(40);
    DECLARE @concepto_desc   VARCHAR(40);
    DECLARE @total_reg       INT;
    DECLARE @monto_total     DECIMAL(18, 2);
    DECLARE @checksum        BIGINT;
    DECLARE @linea_cabecera  VARCHAR(500);
    DECLARE @cta_chk         VARCHAR(20);
    DECLARE @parte_chk       VARCHAR(30);

    SET @moneda_txt = CASE WHEN @par_currency = 'EX' THEN '1001' ELSE '0001' END;

    SELECT @concepto_desc = LTRIM(RTRIM(ISNULL(pc.Description, @par_concept)))
    FROM PR_Concept pc
    WHERE pc.Company = @par_company
      AND pc.Concept = @par_concept;

    SELECT @cuenta_origen = LEFT(LTRIM(RTRIM(ISNULL(ba.BankAccountNumber, ''))), 20)
    FROM TE_BankAccount ba
    WHERE ba.Company = @par_company
      AND ba.Bank = (SELECT CreditoBank FROM PR_Mapping WHERE Company = @par_company)
      AND ba.accountcurrency = @par_currency;

    SELECT @tipo_cta_origen = LEFT(ISNULL(tat.abrev, 'C'), 1)
    FROM te_accounttype tat
    WHERE tat.AccountType = (
        SELECT SalaryAccountType FROM PR_Mapping WHERE Company = @par_company
    );

    SELECT
        @tipo_proceso = LEFT(LTRIM(RTRIM(ISNULL(CAST(pt.subtype AS VARCHAR(10)), ''))), 1),
        @ref_planilla = LEFT(
            'PLANILLA HABERES ' + LTRIM(RTRIM(ISNULL(pt.Description, ISNULL(pt.ShortName, '')))),
            40
        )
    FROM PR_ProcessType pt
    WHERE pt.ProcessType = @par_processtype;

    IF @tipo_proceso IS NULL OR @tipo_proceso = '' SET @tipo_proceso = '1';
    IF @ref_planilla IS NULL OR LTRIM(RTRIM(@ref_planilla)) = '' SET @ref_planilla = 'PLANILLA HABERES';
    IF @tipo_cta_origen IS NULL OR @tipo_cta_origen = '' SET @tipo_cta_origen = 'C';

    ;WITH PersonasSel AS (
        SELECT DISTINCT LTRIM(RTRIM(tp.person)) AS person
        FROM #TelecreditoPersonas tp
        WHERE LTRIM(RTRIM(ISNULL(tp.person, ''))) <> ''
    ),
    Pagos AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc
            INNER JOIN PersonasSel ps ON ps.person = epc.person
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    ),
    DetalleBase AS (
        SELECT
            e.person,
            LEFT(ISNULL(e.salaryaccount, ''), 20) AS cuenta,
            LEFT(ISNULL(tat.abrev, 'A'), 1) AS tipocuenta,
            CASE
                WHEN ISNULL(pdt.PDT, '') = '01' THEN '1'
                WHEN ISNULL(pdt.PDT, '') IN ('03', '04') THEN '3'
                WHEN ISNULL(pdt.PDT, '') = '07' THEN '4'
                WHEN ISNULL(pdt.PDT, '') = '1' THEN '1'
                WHEN ISNULL(pdt.PDT, '') IN ('3', '4') THEN '3'
                ELSE '1'
            END AS tipodocumento,
            LEFT(LTRIM(RTRIM(
                CASE
                    WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                    ELSE sp.DocumentNumber
                END
            )), 12) AS numerodocumento,
            LEFT(LTRIM(RTRIM(
                ISNULL(sp.lastname1, '') + ' ' +
                ISNULL(sp.lastname2, '') + ' ' +
                ISNULL(sp.name1, '') + ' ' +
                ISNULL(sp.name2, '')
            )), 75) AS nombre,
            LEFT(LTRIM(RTRIM(
                'Referencia Beneficiario ' + LTRIM(RTRIM(
                    CASE
                        WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                        ELSE sp.DocumentNumber
                    END
                ))
            )), 40) AS refbeneficiario,
            LEFT(LTRIM(RTRIM(
                'Ref Emp ' + LTRIM(RTRIM(
                    CASE
                        WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                        ELSE sp.DocumentNumber
                    END
                ))
            )), 20) AS refempresa,
            p.importe
        FROM PR_Employee e
            INNER JOIN SY_Person sp ON sp.person = e.person
            INNER JOIN pr_mapping m ON m.company = e.company
            INNER JOIN Pagos p ON p.person = e.person
            INNER JOIN PersonasSel ps ON ps.person = e.person
            LEFT JOIN TE_accounttype tat ON tat.AccountType = e.SalaryAccountType
            LEFT JOIN SY_PersonDocumentType pdt
                ON pdt.PersonDocumentType = sp.EmployeeDocumentType
        WHERE e.company = @par_company
          AND e.payrolltype = @par_payrolltype
          AND ISNULL(e.salaryaccount, '') <> ''
          AND ISNULL(m.creditobank, '') <> ''
          AND e.salarybank = m.creditobank
          AND sp.status = 'A'
          AND (
                CASE
                    WHEN e.status IS NULL THEN 'N'
                    WHEN e.status = '' THEN 'N'
                    WHEN e.status = 'N' THEN 'N'
                    ELSE 'Y'
                END = 'N'
             OR e.ineffectivedate >= GETDATE()
          )
    )
    SELECT
        person,
        cuenta,
        tipocuenta,
        tipodocumento,
        numerodocumento,
        nombre,
        refbeneficiario,
        refempresa,
        importe,
        RIGHT(REPLICATE('0', 14) + CAST(CAST(ROUND(ISNULL(importe, 0), 2, 0) AS BIGINT) AS VARCHAR(20)), 14) +
        '.' +
        RIGHT(
            '00' + CAST(
                ABS(
                    CAST(ROUND(ISNULL(importe, 0) * 100, 0) AS BIGINT) -
                    CAST(ROUND(ISNULL(importe, 0), 2, 0) AS BIGINT) * 100
                ) AS VARCHAR(3)
            ),
            2
        ) AS importe_fmt
    INTO #Detalle
    FROM DetalleBase;

    SELECT @total_reg = COUNT(*) FROM #Detalle;
    SELECT @monto_total = ISNULL(SUM(importe), 0) FROM #Detalle;

    /*
        Checksum BCP (pos. 99-113): suma numérica de la parte útil de cada cuenta.
        Cuenta empresa: RIGHT(cuenta, LEN(cuenta) - 3).
        Cuentas empleado tipo A/M/C: RIGHT(cuenta, LEN(cuenta) - 3).
        Otros tipos: RIGHT(cuenta, 10).
    */
    SET @checksum = 0;
    SET @cta_chk = LTRIM(RTRIM(ISNULL(@cuenta_origen, '')));

    IF LEN(@cta_chk) > 3
    BEGIN
        SET @parte_chk = LTRIM(RTRIM(SUBSTRING(@cta_chk, 4, LEN(@cta_chk) - 3)));
        IF @parte_chk <> '' AND ISNUMERIC(@parte_chk) = 1
            SET @checksum = @checksum + CAST(@parte_chk AS BIGINT);
    END;

    SELECT @checksum = @checksum + ISNULL(SUM(
        CASE
            WHEN LTRIM(RTRIM(ISNULL(cuenta, ''))) = '' THEN CAST(0 AS BIGINT)
            WHEN tipocuenta IN ('A', 'M', 'C') THEN
                CASE
                    WHEN LEN(LTRIM(RTRIM(cuenta))) > 3 THEN
                        CASE
                            WHEN ISNUMERIC(LTRIM(RTRIM(SUBSTRING(LTRIM(RTRIM(cuenta)), 4, LEN(LTRIM(RTRIM(cuenta))) - 3)))) = 1
                            THEN CAST(LTRIM(RTRIM(SUBSTRING(LTRIM(RTRIM(cuenta)), 4, LEN(LTRIM(RTRIM(cuenta))) - 3))) AS BIGINT)
                            ELSE CAST(0 AS BIGINT)
                        END
                    ELSE CAST(0 AS BIGINT)
                END
            ELSE
                CASE
                    WHEN ISNUMERIC(LTRIM(RTRIM(RIGHT(LTRIM(RTRIM(cuenta)), 10)))) = 1
                    THEN CAST(LTRIM(RTRIM(RIGHT(LTRIM(RTRIM(cuenta)), 10))) AS BIGINT)
                    ELSE CAST(0 AS BIGINT)
                END
        END
    ), 0)
    FROM #Detalle;

    SET @linea_cabecera =
        '1' +
        RIGHT(REPLICATE('0', 6) + CAST(@total_reg AS VARCHAR(10)), 6) +
        CONVERT(VARCHAR(8), @par_paydate, 112) +
        @tipo_proceso +
        @tipo_cta_origen +
        @moneda_txt +
        LEFT(ISNULL(@cuenta_origen, '') + REPLICATE(' ', 20), 20) +
        RIGHT(REPLICATE('0', 14) + CAST(CAST(ROUND(ISNULL(@monto_total, 0), 2, 0) AS BIGINT) AS VARCHAR(20)), 14) +
        '.' +
        RIGHT(
            '00' + CAST(
                ABS(
                    CAST(ROUND(ISNULL(@monto_total, 0) * 100, 0) AS BIGINT) -
                    CAST(ROUND(ISNULL(@monto_total, 0), 2, 0) AS BIGINT) * 100
                ) AS VARCHAR(3)
            ),
            2
        ) +
        LEFT(ISNULL(@ref_planilla, '') + REPLICATE(' ', 40), 40) +
        RIGHT(REPLICATE('0', 15) + CAST(ISNULL(@checksum, 0) AS VARCHAR(20)), 15);

    SELECT orden, linea_txt
    FROM (
        SELECT 0 AS orden, @linea_cabecera AS linea_txt
        UNION ALL
        SELECT
            ROW_NUMBER() OVER (ORDER BY nombre, person) AS orden,
            '2' +
            tipocuenta +
            LEFT(cuenta + REPLICATE(' ', 20), 20) +
            tipodocumento +
            LEFT(numerodocumento + REPLICATE(' ', 12), 12) +
            '   ' +
            LEFT(nombre + REPLICATE(' ', 75), 75) +
            LEFT(refbeneficiario + REPLICATE(' ', 40), 40) +
            LEFT(refempresa + REPLICATE(' ', 20), 20) +
            @moneda_txt +
            importe_fmt +
            'S' AS linea_txt
        FROM #Detalle
    ) AS lineas
    ORDER BY orden;
END
GO



-- ============================================================================
-- [27/89] sp_pr_generarboleta_web.sql
-- ============================================================================

/*
    Generar boletas — cabecera y totales para el PDF.

    Usado por: generar_pdf_en_memoria (app.py).

    Parámetros:
      @cia, @process, @payrolltype, @period, @person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_generarboleta_web]
    @cia         VARCHAR(4),
    @process     VARCHAR(20),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @currency CHAR(2);
    SET @currency = 'LO';

    SELECT DISTINCT
        CASE WHEN sy_person.lastname1 IS NULL THEN '' ELSE sy_person.lastname1 END + ' ' +
        CASE WHEN sy_person.lastname2 IS NULL THEN '' ELSE sy_person.lastname2 END + ' ' +
        CASE WHEN sy_person.name1 IS NULL THEN '' ELSE sy_person.name1 END + ' ' +
        CASE WHEN sy_person.name2 IS NULL THEN '' ELSE sy_person.name2 END AS nombre_trabajador,

        (SELECT MAX(pr_pensiontype.pdt)
         FROM PR_EmployeePayRoll AS E2
             INNER JOIN pr_pensiontype ON E2.pensiontype = pr_pensiontype.pensiontype
                                        AND E2.company = pr_pensiontype.company
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS TipoPension,

        (SELECT description
         FROM sy_persondocumenttype (NOLOCK)
         WHERE sy_persondocumenttype.PersonDocumentType = sy_person.employeedocumenttype) + ':' AS DocumentType,
        sy_person.documentnumber AS dni,

        CASE (SELECT MAX(Y.description)
              FROM PR_EmployeePayRoll E2
                  LEFT JOIN pr_afp Y ON E2.afp = Y.afp
              WHERE E2.COMPANY = @cia
                AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                AND E2.processtype = @process
                AND E2.PRPERIOD = @period
                AND E2.PERSON = SY_Person.Person)
            WHEN NULL THEN 'SNP'
            WHEN '' THEN 'SNP'
            ELSE (SELECT MAX(Y.description)
                  FROM PR_EmployeePayRoll E2
                      LEFT JOIN pr_afp Y ON E2.afp = Y.afp
                  WHERE E2.COMPANY = @cia
                    AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                    AND E2.processtype = @process
                    AND E2.PRPERIOD = @period
                    AND E2.PERSON = SY_Person.Person)
        END AS afp_description,

        CASE WHEN (
            (SELECT MAX(pr_pensiontype.pdt)
             FROM PR_EmployeePayRoll AS E2
                 INNER JOIN pr_pensiontype ON E2.pensiontype = pr_pensiontype.pensiontype
                                            AND E2.company = pr_pensiontype.company
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)) = '99'
        THEN 'NINGUNO'
        ELSE
            CASE (SELECT MAX(Y.description)
                  FROM PR_EmployeePayRoll E2
                      LEFT JOIN pr_afp Y ON E2.afp = Y.afp
                  WHERE E2.COMPANY = @cia
                    AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                    AND E2.processtype = @process
                    AND E2.PRPERIOD = @period
                    AND E2.PERSON = SY_Person.Person)
                WHEN NULL THEN 'SNP'
                WHEN '' THEN 'SNP'
                ELSE (SELECT MAX(Y.description)
                      FROM PR_EmployeePayRoll E2
                          LEFT JOIN pr_afp Y ON E2.afp = Y.afp
                      WHERE E2.COMPANY = @cia
                        AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                        AND E2.processtype = @process
                        AND E2.PRPERIOD = @period
                        AND E2.PERSON = SY_Person.Person)
            END
        END AS regimenpension,

        (SELECT MAX(E2.afpcard)
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS cupss,
        pr_employee.socialassistancenumber,
        pr_employeepayroll.person,

        (SELECT SUM(ISNULL(E2.salary, 0))
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS rem_basica,

        (SELECT MAX(E2.costcentername)
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS cccode,

        (SELECT SUM(ISNULL(E2.vacationdays, 0))
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS vacationdays,

        CASE WHEN @currency = 'LO' THEN
            (SELECT SUM(ISNULL(E2.totalincomelo, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        ELSE
            (SELECT SUM(ISNULL(E2.totalincomeex, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        END AS total_ingresos,

        CASE WHEN @currency = 'LO' THEN
            (SELECT SUM(ISNULL(E2.totaldebitslo, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        ELSE
            (SELECT SUM(ISNULL(E2.totaldebitsex, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        END AS total_egresos,

        CASE WHEN @currency = 'LO' THEN
            (SELECT SUM(ISNULL(E2.totalpatronallo, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        ELSE
            (SELECT SUM(ISNULL(E2.totalpatronalex, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        END AS total_aportes,

        (SELECT SUM(ISNULL(E2.absencesdays, 0))
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS absencesday,

        ISNULL((SELECT SUM(ISNULL(E2.conceptvalue, 0))
                FROM pr_employeepayrollconcept AS E2
                WHERE E2.COMPANY = @cia
                  AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                  AND E2.processtype = @process
                  AND E2.Concept IN (SELECT mrallowancedaysnotaxconcept FROM PR_Mapping2 WHERE PR_Mapping2.company = @cia)
                  AND E2.PRPERIOD = @period
                  AND E2.PERSON = SY_Person.Person), 0) AS medicalrestdays,

        ISNULL((SELECT SUM(ISNULL(E2.conceptvalue, 0))
                FROM pr_employeepayrollconcept AS E2
                WHERE E2.COMPANY = @cia
                  AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                  AND E2.processtype = @process
                  AND E2.Concept IN (SELECT mrallowancedaystaxconcept FROM PR_Mapping2 WHERE PR_Mapping2.company = @cia)
                  AND E2.PRPERIOD = @period
                  AND E2.PERSON = SY_Person.Person), 0) AS maternidad,

        ISNULL((SELECT SUM(ISNULL(E2.conceptvalue, 0))
                FROM pr_employeepayrollconcept AS E2
                WHERE E2.COMPANY = @cia
                  AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                  AND E2.processtype = @process
                  AND E2.Concept IN (SELECT mrallowancedaysnotaxconcept FROM PR_Mapping2 WHERE PR_Mapping2.company = @cia)
                  AND E2.PRPERIOD = @period
                  AND E2.PERSON = SY_Person.Person), 0) +
        ISNULL((SELECT SUM(ISNULL(E2.conceptvalue, 0))
                FROM pr_employeepayrollconcept AS E2
                WHERE E2.COMPANY = @cia
                  AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
                  AND E2.processtype = @process
                  AND E2.Concept IN (SELECT mrallowancedaystaxconcept FROM PR_Mapping2 WHERE PR_Mapping2.company = @cia)
                  AND E2.PRPERIOD = @period
                  AND E2.PERSON = SY_Person.Person), 0) AS dias_subsidio,

        CASE WHEN @currency = 'LO' THEN
            (SELECT SUM(ISNULL(E2.netlo, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        ELSE
            (SELECT SUM(ISNULL(E2.netex, 0))
             FROM PR_EmployeePayRoll AS E2
             WHERE E2.COMPANY = @cia
               AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
               AND E2.processtype = @process
               AND E2.PRPERIOD = @period
               AND E2.PERSON = SY_Person.Person)
        END AS neto_pagar,

        sy_company.description AS nombre_empresa,
        sy_company.ruc AS ruc_empresa,
        sy_company.address AS direccion_empresa,
        'DS. 001-98-TR' AS decreto_empresa,
        sy_company.telephone AS telefono_empresa,
        sy_company.Rep_Position AS cargo_representante,
        sy_company.Representative AS nombre_representante,
        sy_person.email AS correo_trabajador,
        (SELECT description
         FROM PR_EmployeeCategory (NOLOCK)
         WHERE pr_employee.employeecategory = PR_EmployeeCategory.employeecategory) AS CategoryDescription,
        pr_employee.employeecategory,
        pr_employee.employeecode,

        (SELECT MAX(ISNULL(E2.position, 0))
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS position,
        pr_payrolltype.title,
        pr_employeecategory.description,

        (SELECT MAX(ISNULL(P.description, 0))
         FROM PR_EmployeePayRoll AS E2
             LEFT JOIN pr_position P ON E2.position = P.position
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS cargo_trabajador,

        (SELECT MAX(E2.ceasedate)
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS fecha_cese,

        (SELECT MAX(E2.entrydate)
         FROM PR_EmployeePayRoll AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS fecha_ingreso,
        PR_ProcessType.description AS process,
        PR_ProcessType.ShortName AS process_shortname,
        pr_period.datebegin,
        pr_period.dateend,
        pr_period.cadatebegin,
        pr_period.cadateend,
        pr_periodtype.description,
        sy_department.name,
        sy_person.birthdate,

        (SELECT SUM(ISNULL(E2.conceptvalue, 0))
         FROM pr_employeepayrollconcept AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.Concept IN (SELECT mrcompanydaysconcept FROM PR_Mapping2 WHERE PR_Mapping2.company = @cia)
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS dias_no_subsidiados,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAS_PATERNIDAD'
           AND PERSON = pr_employee.Person) AS dias_paternidad,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAFALLECIMIENTO'
           AND PERSON = pr_employee.Person) AS dias_fallecimiento,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'CANT_DIAS_AUS_JUSTI'
           AND PERSON = pr_employee.Person) AS dias_faltas_justif,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) <> '02' THEN
            CASE WHEN (SELECT COUNT(*)
                       FROM PR_EmployeeConcept
                       WHERE Person = pr_employee.person
                         AND PayRollType = @payrolltype
                         AND EXISTS (SELECT *
                                     FROM PR_Concept
                                     WHERE Concept = PR_EmployeeConcept.Concept
                                       AND formulacode = 'AFP_FLUJO')) > 0
            THEN 'MIXTO' ELSE 'FLUJO' END
        ELSE '' END AS tipocomision,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'JOR_DIARIO'
           AND PERSON = pr_employee.Person) AS jornal,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAS_VACAC_NORMAL'
           AND PERSON = pr_employee.Person) AS dias_vacaciones,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'C_HORASTRABAJADAS'
           AND PERSON = pr_employee.Person) AS horassemana,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'CANT_HORAS_100'
           AND PERSON = pr_employee.Person) AS CANT_HORAS_100,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'CANT_HORAS_60'
           AND PERSON = pr_employee.Person) AS CANT_HORAS_60,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'CANT_HORAS_NOC'
           AND PERSON = pr_employee.Person) AS CANT_HORAS_NOC,

        (SELECT CONCEPTVALUE
         FROM PR_EMPLOYEEPAYROLLCONCEPT
         WHERE COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND CONCEPT = pr_mapping.salaryconcept
           AND PERSON = pr_employee.Person) AS salaryconcept,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'SUELDOBASICO'
           AND PERSON = pr_employee.Person) AS sueldobasico,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'FALTAS_EMPRE'
           AND PERSON = pr_employee.Person) AS dias_no_laborados,

        (SELECT ISNULL(SUM(ISNULL(CONCEPTVALUE, 0.00)), 0.00)
         FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.concept = pr_concept.concept
           AND PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PROCESSTYPE = @process
           AND PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PRPERIOD = @period
           AND pr_concept.formulacode = 'DIAS_PAGADOS'
           AND PERSON = pr_employee.Person) AS dias_laborables,

        (SELECT SUM(ISNULL(E2.conceptvalue, 0))
         FROM pr_employeepayrollconcept AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.Concept IN (SELECT absencesdaysconcept FROM PR_Mapping WHERE PR_Mapping.company = @cia)
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS dias_faltas_injustif,

        (SELECT SUM(ISNULL(E2.conceptvalue, 0))
         FROM pr_employeepayrollconcept AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.Concept IN (SELECT mrvacationdaystaxconcept FROM PR_Mapping WHERE PR_Mapping.company = @cia)
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS diassingoce,

        (SELECT SUM(ISNULL(E2.conceptvalue, 0))
         FROM pr_employeepayrollconcept AS E2
         WHERE E2.COMPANY = @cia
           AND E2.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND E2.processtype = @process
           AND E2.Concept IN (SELECT mrvacationdaysnotaxconcept FROM PR_Mapping WHERE PR_Mapping.company = @cia)
           AND E2.PRPERIOD = @period
           AND E2.PERSON = SY_Person.Person) AS diascongoce,

        (SELECT PR_EMPLOYEEPAYROLLCONCEPT.CONCEPTVALUE
         FROM PR_EMPLOYEEPAYROLLCONCEPT
         WHERE PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = @cia
           AND PR_EMPLOYEEPAYROLLCONCEPT.PROCESSTYPE = @process
           AND PR_EMPLOYEEPAYROLLCONCEPT.PAYROLLTYPE = pr_employeepayroll.PayRollType
           AND PR_EMPLOYEEPAYROLLCONCEPT.PRPERIOD = @period
           AND PR_EMPLOYEEPAYROLLCONCEPT.CONCEPT = pr_mapping.sundaydaysworkconcept
           AND PR_EMPLOYEEPAYROLLCONCEPT.PERSON = pr_employee.Person) AS Sunday_days_work,
        pr_employee.SalaryAccount AS numerocuenta,
        (SELECT name FROM erp_bank WHERE bank = pr_employee.salarybank) AS bancosalario,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) IN (21, 22, 23, 24, 25)
        THEN (SELECT PensionPercentage FROM pr_AFP WHERE pr_AFP.AFP = pr_employee.AFP)
        ELSE 0 END AS aporte,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) IN (21, 22, 23, 24, 25)
        THEN (SELECT VariablePercentage FROM pr_AFP WHERE pr_AFP.AFP = pr_employee.AFP)
        ELSE 0 END AS comisionflujo,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) IN (21, 22, 23, 24, 25)
        THEN (SELECT InsuredPercentage FROM pr_AFP WHERE pr_AFP.AFP = pr_employee.AFP)
        ELSE 0 END AS seguro,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) = 2
        THEN 13 ELSE 0 END AS snp,

        CASE WHEN (SELECT PDT FROM PR_pensionType WHERE PR_pensionType.PensionType = pr_employee.pensionType) IN (21, 23, 24, 25)
        THEN (SELECT FixedAmount FROM pr_AFP WHERE pr_AFP.AFP = pr_employee.AFP)
        ELSE 0 END AS comisionmixta,

        (SELECT Description FROM PR_SpecialStatus WHERE SpecialStatus = pr_employee.SpecialStatus) AS clasificacion,

        CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(PR_ProcessType.ShortName, '')))) = 'GRATIFICACION' THEN
            'BOLETA DE GRATIFICACION - '
        ELSE
            'BOLETA DE PAGO ' + UPPER(LTRIM(RTRIM(ISNULL(pr_periodtype.description, '')))) + ' - '
        END +
        UPPER(
            CASE SUBSTRING(@period, 5, 2)
                WHEN '01' THEN 'Enero'
                WHEN '02' THEN 'Febrero'
                WHEN '03' THEN 'Marzo'
                WHEN '04' THEN 'Abril'
                WHEN '05' THEN 'Mayo'
                WHEN '06' THEN 'Junio'
                WHEN '07' THEN 'Julio'
                WHEN '08' THEN 'Agosto'
                WHEN '09' THEN 'Setiembre'
                WHEN '10' THEN 'Octubre'
                WHEN '11' THEN 'Noviembre'
                WHEN '12' THEN 'Diciembre'
                ELSE SUBSTRING(@period, 5, 2)
            END
        ) + ' ' + LEFT(@period, 4) AS titulo_boleta,

        'Del ' +
        CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(PR_ProcessType.ShortName, '')))) = 'GRATIFICACION' THEN
            '01-07-2020'
        ELSE
            CONVERT(VARCHAR(10), pr_period.cadatebegin, 103)
        END +
        ' al ' + CONVERT(VARCHAR(10), pr_period.cadateend, 103) AS RangoFechas

    FROM pr_employee
        LEFT JOIN pr_employeecategory ON pr_employee.EmployeeCategory = pr_employeecategory.EmployeeCategory,
         sy_person
        LEFT JOIN sy_department ON sy_person.department = sy_department.department,
         sy_company,
         pr_payrolltype,
         pr_employeepayroll
        LEFT JOIN pr_position ON pr_employeepayroll.Position = pr_position.Position,
         PR_ProcessType,
         pr_mapping,
         pr_period,
         ac_costcenter,
         pr_periodtype
    WHERE pr_mapping.company = @cia
      AND pr_employeepayroll.costcenter = ac_costcenter.costcenter
      AND pr_employee.company = pr_mapping.company
      AND pr_employee.Person = sy_person.Person
      AND pr_employee.Company = sy_company.Company
      AND pr_employeepayroll.PayRollType = pr_payrolltype.PayRollType
      AND pr_employeepayroll.Company = pr_employee.Company
      AND pr_employeepayroll.Person = pr_employee.Person
      AND pr_employeepayroll.ProcessType = PR_ProcessType.ProcessType
      AND pr_employeepayroll.processtype = @process
      AND pr_employeepayroll.payrolltype = @payrolltype
      AND pr_payrolltype.periodtype = pr_periodtype.periodtype
      AND pr_employeepayroll.prperiod = @period
      AND pr_employeepayroll.person = @person
      AND pr_period.payrolltype = @payrolltype
      AND pr_period.prperiod = @period;
END
GO



-- ============================================================================
-- [28/89] sp_pr_guardarasignacionconcepto_web.sql
-- ============================================================================

/*
    Inserta o actualiza una asignación de concepto (PR_EmployeeConcept).
    @modo: I = nuevo, U = actualizar.

    Campos no expuestos en UI (valores por defecto):
      PercentageDistribution = 'A', Comments = NULL, Application = NULL,
      Project/ProjectCode = '', FlagCopy = NULL.

    Reglas:
      Permanente (P): PRPeriodEnd = NULL.
      Temporal (T): PRPeriodStart y PRPeriodEnd obligatorios; fin >= inicio.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarasignacionconcepto_web]
    @modo                CHAR(1),
    @par_company         VARCHAR(10),
    @par_person          VARCHAR(20),
    @par_concept         VARCHAR(20),
    @par_payrolltype     VARCHAR(20),
    @par_prperiodstart   VARCHAR(10),
    @par_costcenter      VARCHAR(20),
    @par_prperiodend     VARCHAR(10),
    @par_conceptvalue    NUMERIC(18, 4),
    @par_conceptcurrency CHAR(2),
    @par_flagapplyformula CHAR(1),
    @par_flagfrecuencytype CHAR(1),
    @xlastuser           VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @costcenter      VARCHAR(20);
    DECLARE @costcentercode  VARCHAR(20);
    DECLARE @replicationunit VARCHAR(4);
    DECLARE @conceptvaluelo  NUMERIC(18, 4);
    DECLARE @conceptvalueex  NUMERIC(18, 4);
    DECLARE @exchangerate    NUMERIC(18, 4);

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido.', 16, 1);
        RETURN;
    END

    SET @par_company = LTRIM(RTRIM(ISNULL(@par_company, '')));
    SET @par_person = LTRIM(RTRIM(ISNULL(@par_person, '')));
    SET @par_concept = LTRIM(RTRIM(ISNULL(@par_concept, '')));
    SET @par_payrolltype = LTRIM(RTRIM(ISNULL(@par_payrolltype, '')));
    SET @par_prperiodstart = LTRIM(RTRIM(ISNULL(@par_prperiodstart, '')));
    SET @par_costcenter = LTRIM(RTRIM(ISNULL(@par_costcenter, '')));
    SET @par_prperiodend = NULLIF(LTRIM(RTRIM(ISNULL(@par_prperiodend, ''))), '');
    SET @par_conceptcurrency = UPPER(LTRIM(RTRIM(ISNULL(@par_conceptcurrency, 'LO'))));
    SET @par_flagapplyformula = UPPER(LTRIM(RTRIM(ISNULL(@par_flagapplyformula, 'N'))));
    SET @par_flagfrecuencytype = UPPER(LTRIM(RTRIM(ISNULL(@par_flagfrecuencytype, 'P'))));

    IF @par_company = '' OR @par_person = '' OR @par_concept = '' OR @par_payrolltype = '' OR @par_prperiodstart = ''
    BEGIN
        RAISERROR('Complete compañía, empleado, concepto, tipo planilla y periodo inicio.', 16, 1);
        RETURN;
    END

    IF @par_conceptvalue IS NULL
    BEGIN
        RAISERROR('Indique el valor del concepto.', 16, 1);
        RETURN;
    END

    IF @par_conceptcurrency NOT IN ('LO', 'EX')
    BEGIN
        RAISERROR('Moneda inválida. Use LO o EX.', 16, 1);
        RETURN;
    END

    IF @par_flagfrecuencytype NOT IN ('P', 'T')
    BEGIN
        RAISERROR('Tipo de asignación inválido. Use Permanente (P) o Temporal (T).', 16, 1);
        RETURN;
    END

    IF @par_flagapplyformula NOT IN ('Y', 'N')
        SET @par_flagapplyformula = 'N';

    IF @par_flagfrecuencytype = 'P'
        SET @par_prperiodend = NULL;
    ELSE IF @par_prperiodend IS NULL
    BEGIN
        RAISERROR('Para asignación temporal indique el periodo fin.', 16, 1);
        RETURN;
    END
    ELSE IF @par_prperiodend < @par_prperiodstart
    BEGIN
        RAISERROR('El periodo fin no puede ser anterior al periodo inicio.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 FROM PR_Employee e
        WHERE e.Company = @par_company
          AND e.Person = @par_person
          AND e.PayRollType = @par_payrolltype
    )
    BEGIN
        RAISERROR('El trabajador no existe o no pertenece al tipo de planilla indicado.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 FROM PR_Concept c
        WHERE c.Company = @par_company
          AND c.Concept = @par_concept
          AND c.Status = 'A'
    )
    BEGIN
        RAISERROR('El concepto no existe o no está activo para la compañía.', 16, 1);
        RETURN;
    END

    IF NOT EXISTS (
        SELECT 1 FROM PR_Period p
        WHERE p.Company = @par_company
          AND p.PayRollType = @par_payrolltype
          AND p.PRPeriod = @par_prperiodstart
    )
    BEGIN
        RAISERROR('El periodo inicio no existe para la planilla seleccionada.', 16, 1);
        RETURN;
    END

    IF @par_flagfrecuencytype = 'T'
       AND NOT EXISTS (
            SELECT 1 FROM PR_Period p
            WHERE p.Company = @par_company
              AND p.PayRollType = @par_payrolltype
              AND p.PRPeriod = @par_prperiodend
       )
    BEGIN
        RAISERROR('El periodo fin no existe para la planilla seleccionada.', 16, 1);
        RETURN;
    END

    SELECT
        @costcenter = ISNULL(NULLIF(LTRIM(RTRIM(e.CostCenter)), ''), ''),
        @costcentercode = ISNULL(
            NULLIF(LTRIM(RTRIM(e.CostCenterName)), ''),
            ISNULL(NULLIF(LTRIM(RTRIM(e.CostCenter)), ''), '')
        ),
        @replicationunit = NULLIF(LTRIM(RTRIM(sp.ReplicationUnit)), '')
    FROM PR_Employee e
        INNER JOIN SY_Person sp ON sp.Person = e.Person
    WHERE e.Company = @par_company
      AND e.Person = @par_person;

    IF @modo = 'I'
    BEGIN
        IF @par_costcenter <> ''
            SET @costcenter = @par_costcenter;

        IF EXISTS (
            SELECT 1 FROM PR_EmployeeConcept ec
            WHERE ec.Person = @par_person
              AND ec.Company = @par_company
              AND ec.Concept = @par_concept
              AND ec.PayRollType = @par_payrolltype
              AND ec.PRPeriodStart = @par_prperiodstart
              AND ec.CostCenter = @costcenter
        )
        BEGIN
            RAISERROR('Ya existe una asignación con la misma clave (trabajador, concepto, planilla, periodo inicio y centro de costo).', 16, 1);
            RETURN;
        END

        IF @par_conceptcurrency = 'LO'
        BEGIN
            SET @conceptvaluelo = @par_conceptvalue;
            SET @conceptvalueex = 0;
            SET @exchangerate = 0;
        END
        ELSE
        BEGIN
            SET @conceptvalueex = @par_conceptvalue;
            SET @conceptvaluelo = 0;
            SET @exchangerate = 1;
        END

        INSERT INTO PR_EmployeeConcept (
            Person, Company, Concept, PayRollType, PRPeriodStart, CostCenter,
            PRPeriodEnd, ConceptValue, Application, ConceptCurrency, Comments,
            FlagApplyFormula, FlagFrecuencyType, ReplicationUnit,
            XLastUser, XLastDate, ConceptValueLo, ConceptValueEx, ExchangeRate,
            CostCenterCode, Project, ProjectCode, PercentageDistribution, FlagCopy
        )
        VALUES (
            @par_person, @par_company, @par_concept, @par_payrolltype, @par_prperiodstart, @costcenter,
            @par_prperiodend, @par_conceptvalue, NULL, @par_conceptcurrency, NULL,
            @par_flagapplyformula, @par_flagfrecuencytype, @replicationunit,
            NULLIF(LTRIM(RTRIM(@xlastuser)), ''), GETDATE(), @conceptvaluelo, @conceptvalueex, @exchangerate,
            @costcentercode, '', '', 'A', NULL
        );
    END
    ELSE
    BEGIN
        IF @par_costcenter = ''
            SET @par_costcenter = @costcenter;

        IF NOT EXISTS (
            SELECT 1 FROM PR_EmployeeConcept ec
            WHERE ec.Person = @par_person
              AND ec.Company = @par_company
              AND ec.Concept = @par_concept
              AND ec.PayRollType = @par_payrolltype
              AND ec.PRPeriodStart = @par_prperiodstart
              AND ec.CostCenter = @par_costcenter
        )
        BEGIN
            RAISERROR('No se encontró la asignación a actualizar.', 16, 1);
            RETURN;
        END

        IF @par_conceptcurrency = 'LO'
        BEGIN
            SET @conceptvaluelo = @par_conceptvalue;
            SET @conceptvalueex = 0;
            SET @exchangerate = 0;
        END
        ELSE
        BEGIN
            SET @conceptvalueex = @par_conceptvalue;
            SET @conceptvaluelo = 0;
            SET @exchangerate = 1;
        END

        UPDATE PR_EmployeeConcept
        SET
            PRPeriodEnd = @par_prperiodend,
            ConceptValue = @par_conceptvalue,
            ConceptCurrency = @par_conceptcurrency,
            FlagApplyFormula = @par_flagapplyformula,
            FlagFrecuencyType = @par_flagfrecuencytype,
            ConceptValueLo = @conceptvaluelo,
            ConceptValueEx = @conceptvalueex,
            ExchangeRate = @exchangerate,
            XLastUser = NULLIF(LTRIM(RTRIM(@xlastuser)), ''),
            XLastDate = GETDATE()
        WHERE Person = @par_person
          AND Company = @par_company
          AND Concept = @par_concept
          AND PayRollType = @par_payrolltype
          AND PRPeriodStart = @par_prperiodstart
          AND CostCenter = @par_costcenter;
    END
END
GO



-- ============================================================================
-- [29/89] sp_pr_guardarconcepto_web.sql
-- ============================================================================

/*
    Alta / edición de concepto de planilla (PR_Concept) — maestro web.

    @modo: I = nuevo (genera Concept con sp_pr_genera_correlativo_web),
           U = actualizar registro existente.

    Campos expuestos en UI maestro Conceptos (Configuración).
    ConceptGroup se resuelve automáticamente al insertar si no se envía.

    Usado por: POST /api/conceptos/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarconcepto_web]
    @modo                 CHAR(1),
    @company              VARCHAR(4),
    @concept              VARCHAR(20) = NULL,
    @description          VARCHAR(50),
    @formulacode          VARCHAR(20),
    @concepttype          VARCHAR(20),
    @conceptgroup         VARCHAR(20) = NULL,
    @conceptcurrency      CHAR(2) = 'LO',
    @flagismonetary       CHAR(1) = 'Y',
    @printtext            VARCHAR(50) = NULL,
    @conceptorder         INT = NULL,
    @status               CHAR(1) = 'A',
    @flagassign           VARCHAR(1) = 'N',
    @flagpayrollticket    VARCHAR(1) = 'N',
    @flagcontract         CHAR(1) = 'N',
    @pdt                  VARCHAR(20) = NULL,
    @flagconceptdeclare   CHAR(1) = NULL,
    @reporden             INT = NULL,
    @flaginsertar         CHAR(1) = NULL,
    @flagafectoafp        CHAR(1) = NULL,
    @flagafecto5ta        CHAR(1) = NULL,
    @xlastuser            VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @concept_nuevo   VARCHAR(20);
    DECLARE @tabla_id        TABLE (id_generado VARCHAR(20));

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @concept = NULLIF(LTRIM(RTRIM(ISNULL(@concept, ''))), '');
    SET @description = LTRIM(RTRIM(ISNULL(@description, '')));
    SET @formulacode = UPPER(LTRIM(RTRIM(ISNULL(@formulacode, ''))));
    SET @concepttype = LTRIM(RTRIM(ISNULL(@concepttype, '')));
    SET @conceptgroup = NULLIF(LTRIM(RTRIM(ISNULL(@conceptgroup, ''))), '');
    SET @conceptcurrency = UPPER(LTRIM(RTRIM(ISNULL(@conceptcurrency, 'LO'))));
    SET @flagismonetary = UPPER(LTRIM(RTRIM(ISNULL(@flagismonetary, 'Y'))));
    SET @printtext = NULLIF(LTRIM(RTRIM(ISNULL(@printtext, ''))), '');
    SET @status = UPPER(LTRIM(RTRIM(ISNULL(@status, 'A'))));
    SET @flagassign = UPPER(LTRIM(RTRIM(ISNULL(@flagassign, 'N'))));
    SET @flagpayrollticket = UPPER(LTRIM(RTRIM(ISNULL(@flagpayrollticket, 'N'))));
    SET @flagcontract = UPPER(LTRIM(RTRIM(ISNULL(@flagcontract, 'N'))));
    SET @pdt = NULLIF(LTRIM(RTRIM(ISNULL(@pdt, ''))), '');
    SET @flagconceptdeclare = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@flagconceptdeclare, '')))), '');
    SET @flaginsertar = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@flaginsertar, '')))), '');
    SET @flagafectoafp = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@flagafectoafp, '')))), '');
    SET @flagafecto5ta = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@flagafecto5ta, '')))), '');
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido. Use I (insertar) o U (actualizar).', 16, 1);
        RETURN;
    END;

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @description = ''
    BEGIN
        RAISERROR('Indique la descripción del concepto.', 16, 1);
        RETURN;
    END;

    IF @formulacode = ''
    BEGIN
        RAISERROR('Indique el nemónico (FormulaCode).', 16, 1);
        RETURN;
    END;

    IF @concepttype = ''
    BEGIN
        RAISERROR('Indique el tipo de concepto.', 16, 1);
        RETURN;
    END;

    IF @flagismonetary = 'N'
        SET @conceptcurrency = 'LO';

    IF @conceptcurrency NOT IN ('LO', 'EX')
    BEGIN
        RAISERROR('Moneda inválida. Use LO o EX.', 16, 1);
        RETURN;
    END;

    IF @flagismonetary NOT IN ('Y', 'N')
    BEGIN
        RAISERROR('Valor monetario inválido. Use Y o N.', 16, 1);
        RETURN;
    END;

    IF @status NOT IN ('A', 'I')
    BEGIN
        RAISERROR('Estado inválido. Use A (activo) o I (inactivo).', 16, 1);
        RETURN;
    END;

    IF @modo = 'U' AND @concept IS NULL
    BEGIN
        RAISERROR('Indique el código del concepto a actualizar.', 16, 1);
        RETURN;
    END;

    IF @printtext IS NULL
        SET @printtext = @description;

    IF @reporden IS NULL
        SET @reporden = ISNULL(@conceptorder, 0);

    IF @flagconceptdeclare IS NULL
        SET @flagconceptdeclare = 'N';

    IF @flaginsertar IS NULL
        SET @flaginsertar = 'N';

    IF @flagafectoafp IS NULL
        SET @flagafectoafp = 'N';

    IF @flagafecto5ta IS NULL
        SET @flagafecto5ta = 'N';

    IF NOT EXISTS (
        SELECT 1 FROM PR_ConceptType (NOLOCK)
        WHERE ConceptType = @concepttype
    )
    BEGIN
        RAISERROR('Tipo de concepto inexistente.', 16, 1);
        RETURN;
    END;

    IF @conceptgroup IS NULL
    BEGIN
        SELECT TOP 1 @conceptgroup = C.ConceptGroup
        FROM PR_Concept C (NOLOCK)
        WHERE C.Company = @company
          AND C.ConceptType = @concepttype
        ORDER BY C.Concept;

        IF @conceptgroup IS NULL
        BEGIN
            SELECT TOP 1 @conceptgroup = C.ConceptGroup
            FROM PR_Concept C (NOLOCK)
            WHERE C.Company = @company
            ORDER BY C.Concept;
        END;

        IF @conceptgroup IS NULL
        BEGIN
            SELECT TOP 1 @conceptgroup = G.ConceptGroup
            FROM PR_ConceptGroup G (NOLOCK)
            ORDER BY G.ConceptGroup;
        END;
    END;

    IF @conceptgroup IS NULL OR NOT EXISTS (
        SELECT 1 FROM PR_ConceptGroup (NOLOCK)
        WHERE ConceptGroup = @conceptgroup
    )
    BEGIN
        RAISERROR('No se pudo determinar un grupo de concepto válido.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM PR_Concept (NOLOCK)
            WHERE Company = @company
              AND FormulaCode = @formulacode
        )
        BEGIN
            RAISERROR('Ya existe un concepto con el mismo nemónico en la compañía.', 16, 1);
            RETURN;
        END;

        INSERT INTO @tabla_id (id_generado)
        EXEC dbo.sp_pr_genera_correlativo_web
            @cia = @company,
            @object = 'PR_CONCEPT',
            @xlastuser = @xlastuser;

        SELECT @concept_nuevo = id_generado FROM @tabla_id;

        IF @concept_nuevo IS NULL OR LTRIM(RTRIM(@concept_nuevo)) = ''
        BEGIN
            RAISERROR('No se pudo generar el correlativo del concepto.', 16, 1);
            RETURN;
        END;

        INSERT INTO PR_Concept (
            Concept,
            ConceptGroup,
            ConceptType,
            FormulaCode,
            ConceptOrder,
            Description,
            ConceptCurrency,
            FlagIsMonetary,
            PrintText,
            Flagassign,
            Status,
            Company,
            ReplicationUnit,
            XLastUser,
            XLastDate,
            FLAGCONTRACT,
            FlagPayrollTicket,
            FLAGTEXTVALUEPRINT,
            pdt,
            flagconceptdeclare,
            RentOrder,
            PercentageDistribution,
            reporden,
            flaginsertar,
            flagafectoAFP,
            flagafecto5ta
        )
        VALUES (
            @concept_nuevo,
            @conceptgroup,
            @concepttype,
            @formulacode,
            @conceptorder,
            @description,
            @conceptcurrency,
            @flagismonetary,
            @printtext,
            @flagassign,
            @status,
            @company,
            @replicationunit,
            @xlastuser,
            GETDATE(),
            @flagcontract,
            @flagpayrollticket,
            'X',
            @pdt,
            @flagconceptdeclare,
            0,
            'A',
            @reporden,
            @flaginsertar,
            @flagafectoafp,
            @flagafecto5ta
        );

        SELECT
            @concept_nuevo AS concept,
            'I' AS modo,
            'Concepto creado correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM PR_Concept (NOLOCK)
        WHERE Concept = @concept
          AND Company = @company
    )
    BEGIN
        RAISERROR('Concepto inexistente para la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1 FROM PR_Concept (NOLOCK)
        WHERE Company = @company
          AND FormulaCode = @formulacode
          AND Concept <> @concept
    )
    BEGIN
        RAISERROR('Ya existe otro concepto con el mismo nemónico en la compañía.', 16, 1);
        RETURN;
    END;

    UPDATE PR_Concept
    SET ConceptGroup = @conceptgroup,
        ConceptType = @concepttype,
        FormulaCode = @formulacode,
        ConceptOrder = @conceptorder,
        Description = @description,
        ConceptCurrency = @conceptcurrency,
        FlagIsMonetary = @flagismonetary,
        PrintText = @printtext,
        Flagassign = @flagassign,
        Status = @status,
        XLastUser = @xlastuser,
        XLastDate = GETDATE(),
        FLAGCONTRACT = @flagcontract,
        FlagPayrollTicket = @flagpayrollticket,
        pdt = @pdt,
        flagconceptdeclare = @flagconceptdeclare,
        reporden = @reporden,
        flaginsertar = @flaginsertar,
        flagafectoAFP = @flagafectoafp,
        flagafecto5ta = @flagafecto5ta
    WHERE Concept = @concept
      AND Company = @company;

    SELECT
        @concept AS concept,
        'U' AS modo,
        'Concepto actualizado correctamente.' AS mensaje;
END
GO



-- ============================================================================
-- [30/89] sp_pr_listaasignacionconceptos_web.sql
-- ============================================================================

/*
    Listado de asignación de conceptos a trabajadores (PR_EmployeeConcept).
    Usado por: POST /api/asignacion-conceptos/listado (asignacion_conceptos.html).

    Basado en DataWindow legacy (AUXILIARES/Lista de asignacion.txt).

    Filtros iniciales:
      @par_company, @par_payrolltype, @par_period ('0' = todos los periodos),
      @par_concept ('0' = todos los conceptos), @par_person ('0' = todos los empleados),
      @nombre (búsqueda parcial, opcional), @cesados (T/Y/N),
      @par_frecuencytype ('0' = todos, P = permanente, T = temporal),
      @par_replicationunit ('0' = todas las unidades, SY_Person.ReplicationUnit).

    Filtros legacy no expuestos aún (valores por defecto):
      centro de costo = todos, viewliq = T, tareo = N, validar = T.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listaasignacionconceptos_web]
    @par_company     VARCHAR(10),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(10),
    @par_concept     VARCHAR(20),
    @par_person      VARCHAR(20) = '0',
    @nombre          VARCHAR(100),
    @cesados         CHAR(1),
    @par_frecuencytype CHAR(1) = '0',
    @par_replicationunit VARCHAR(4) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @par_period_all  CHAR(1) = 'N';
    DECLARE @par_allconcept  CHAR(1) = 'N';
    DECLARE @par_employee_all CHAR(1) = 'Y';
    DECLARE @person_filter   VARCHAR(20) = '';
    DECLARE @par_cc_all      CHAR(1) = 'Y';
    DECLARE @par_cc          VARCHAR(20) = '';
    DECLARE @par_frecuency_all CHAR(1) = 'N';
    DECLARE @par_frecuency   CHAR(1) = '';
    DECLARE @par_repunit_all CHAR(1) = 'Y';
    DECLARE @par_repunit     VARCHAR(4) = '';
    DECLARE @par_viewliq     CHAR(1) = 'T';
    DECLARE @par_tareo       CHAR(1) = 'N';
    DECLARE @par_validar     CHAR(1) = 'T';

    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@par_period, '')) IN ('', '0') SET @par_period_all = 'Y';
    IF RTRIM(ISNULL(@par_concept, '')) IN ('', '0') SET @par_allconcept = 'Y';
    IF @nombre IS NULL SET @nombre = '';
    SET @nombre = LTRIM(RTRIM(@nombre));
    SET @person_filter = LTRIM(RTRIM(ISNULL(@par_person, '')));
    IF @person_filter IN ('', '0')
        SET @par_employee_all = 'Y';
    ELSE
        SET @par_employee_all = 'N';
    SET @par_frecuencytype = UPPER(LTRIM(RTRIM(ISNULL(@par_frecuencytype, '0'))));
    IF @par_frecuencytype IN ('', '0')
        SET @par_frecuency_all = 'Y';
    ELSE IF @par_frecuencytype IN ('P', 'T')
        SET @par_frecuency = @par_frecuencytype;
    ELSE
        SET @par_frecuency_all = 'Y';

    SET @par_repunit = LTRIM(RTRIM(ISNULL(@par_replicationunit, '')));
    IF @par_repunit IN ('', '0')
        SET @par_repunit_all = 'Y';
    ELSE
        SET @par_repunit_all = 'N';

    SELECT
        ec.Person AS person,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS nombre,
        ISNULL(e.EmployeeCode, ec.Person) AS employeecode,
        ec.Company AS company,
        ec.Concept AS concept,
        (
            SELECT TOP 1 c.Description
            FROM PR_Concept c
            WHERE c.Company = ec.Company
              AND c.Concept = ec.Concept
        ) AS conceptname,
        ec.PayRollType AS payrolltype,
        ec.PRPeriodStart AS prperiodstart,
        ec.PRPeriodEnd AS prperiodend,
        ec.ConceptValue AS conceptvalue,
        ec.ConceptCurrency AS conceptcurrency,
        ec.FlagApplyFormula AS flagapplyformula,
        ec.FlagFrecuencyType AS flagfrecuencytype,
        ec.CostCenter AS costcenter,
        ec.CostCenterCode AS costcentercode,
        ec.Project AS project,
        ec.Comments AS comments,
        CASE WHEN ec.XLastUser = 'TAREO' THEN 'T' ELSE '' END AS tareo,
        ec.XLastUser AS xlastuser,
        ec.XLastDate AS xlastdate
    FROM PR_EmployeeConcept ec WITH (NOLOCK)
        INNER JOIN PR_Employee e WITH (NOLOCK)
            ON e.Person = ec.Person
           AND e.Company = ec.Company
        INNER JOIN SY_Person sp WITH (NOLOCK)
            ON sp.Person = e.Person
    WHERE e.Person = ec.Person
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND ec.Company = @par_company
      AND e.Company = @par_company
      AND (@par_allconcept = 'Y' OR ec.Concept = @par_concept)
      AND ec.PayRollType = @par_payrolltype
      AND (
            @par_employee_all = 'Y'
         OR ec.Person = @person_filter
      )
      AND (
            @par_period_all = 'Y'
         OR (
                (
                    CASE
                        WHEN ec.PRPeriodEnd IS NULL THEN 'N'
                        WHEN RTRIM(ec.PRPeriodEnd) = '' THEN 'N'
                        ELSE 'Y'
                    END = 'N'
                    AND ec.PRPeriodStart <= @par_period
                )
             OR (@par_period BETWEEN ec.PRPeriodStart AND ec.PRPeriodEnd)
            )
      )
      AND (
            @par_cc_all = 'Y'
         OR ec.CostCenter = @par_cc
      )
      AND (
            @par_frecuency_all = 'Y'
         OR ec.FlagFrecuencyType = @par_frecuency
      )
      AND (
            @par_repunit_all = 'Y'
         OR sp.ReplicationUnit = @par_repunit
      )
      AND (
            @par_viewliq = 'T'
         OR (@par_viewliq = 'N' AND e.CeaseDate IS NULL)
         OR (
                @par_period_all = 'Y'
            AND @par_viewliq = 'L'
            AND e.CeaseDate IS NOT NULL
            )
         OR (
                @par_period_all = 'N'
            AND @par_viewliq = 'L'
            AND (
                    SELECT COUNT(*)
                    FROM PR_Period p
                    WHERE p.Company = @par_company
                      AND e.PayRollType = p.PayRollType
                      AND p.PRPeriod = @par_period
                      AND CONVERT(VARCHAR, e.CeaseDate, 112)
                          BETWEEN CONVERT(VARCHAR, p.DateBegin, 112)
                              AND CONVERT(VARCHAR, p.DateEnd, 112)
                ) = 1
            )
      )
      AND (
            @par_tareo = 'N'
         OR ec.XLastUser = 'TAREO'
      )
      AND (
            @par_validar = 'T'
         OR (@par_validar = 'P' AND ISNULL(sp.IsRecruiter, 'N') = 'N')
         OR (@par_validar = 'H' AND ISNULL(sp.IsRecruiter, 'N') = 'Y')
      )
      AND (
            @nombre = ''
         OR LTRIM(RTRIM(
                ISNULL(sp.LastName1, '') + ' ' +
                ISNULL(sp.LastName2, '') + ' ' +
                ISNULL(sp.Name1, '') + ' ' +
                ISNULL(sp.Name2, '')
            )) LIKE '%' + @nombre + '%'
      )
    ORDER BY nombre, ec.Person, ec.Concept, ec.PRPeriodStart;
END
GO



-- ============================================================================
-- [31/89] sp_pr_listabanbif_web.sql
-- ============================================================================

/*
    Listado de trabajadores elegibles para archivo BANBIF (BXIE).
    Usa pr_mapping.banbifbank.
    @cesados: T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listabanbif_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @cesados         CHAR(1),
    @todos_bancos    CHAR(1) = 'N'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@todos_bancos, '')) = '' SET @todos_bancos = 'N';
    SET @todos_bancos = UPPER(@todos_bancos);
    IF @todos_bancos NOT IN ('Y', 'N') SET @todos_bancos = 'N';

    ;WITH Pagos AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    )
    SELECT
        e.person,
        LTRIM(RTRIM(
            CASE
                WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                ELSE sp.DocumentNumber
            END
        )) AS dni,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        p.importe,
        pdt.PDT AS tipodoc,
        LTRIM(RTRIM(ISNULL(eb.Name, ISNULL(e.salarybank, '')))) AS banco
    FROM PR_Employee e
        INNER JOIN SY_Person sp ON sp.person = e.person
        INNER JOIN pr_mapping m ON m.company = e.company
        INNER JOIN Pagos p ON p.person = e.person
        LEFT JOIN SY_PersonDocumentType pdt
            ON pdt.PersonDocumentType = sp.EmployeeDocumentType
        LEFT JOIN te_accounttype tat
            ON tat.accounttype = e.salaryaccounttype
        LEFT JOIN ERP_Bank eb
            ON eb.bank = e.salarybank
           AND eb.company = e.company
    WHERE e.company = @par_company
      AND e.payrolltype = @par_payrolltype
      AND (
            e.salarycurrency = @par_currency
         OR (@par_currency = 'EX' AND ISNULL(e.socialassistancecenter, '') <> '')
      )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND ISNULL(m.banbifbank, '') <> ''
      AND ISNULL(m.collectionform, '') <> ''
      AND e.collectionform = m.collectionform
      AND (
            (
                @todos_bancos = 'N'
                AND e.salarybank = m.banbifbank
                AND (
                    (@par_currency = 'LO' AND ISNULL(e.salaryaccount, '') <> '')
                 OR (@par_currency = 'EX' AND ISNULL(e.socialassistancecenter, '') <> '')
                )
            )
         OR (
                @todos_bancos = 'Y'
                AND e.salarybank <> m.banbifbank
                AND (
                    ISNULL(tat.abrev, '') = 'B'
                 OR UPPER(ISNULL(tat.description, '')) LIKE '%INTERBANCARIA%'
                )
                AND ISNULL(e.socialassistancenumber, '') <> ''
            )
      )
      AND sp.status = 'A'
      AND (
            CASE
                WHEN e.status IS NULL THEN 'N'
                WHEN e.status = '' THEN 'N'
                WHEN e.status = 'N' THEN 'N'
                ELSE 'Y'
            END = 'N'
         OR e.ineffectivedate >= GETDATE()
      )
    ORDER BY nombre, dni;
END
GO



-- ============================================================================
-- [32/89] sp_pr_listacontinental_web.sql
-- ============================================================================

/*
    Listado de trabajadores elegibles para archivo Continental (BBVA).
    Usa pr_mapping.continentalbank.
    @cesados: T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listacontinental_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @cesados         CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';

    ;WITH Pagos AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    )
    SELECT
        e.person,
        LTRIM(RTRIM(
            CASE
                WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                ELSE sp.DocumentNumber
            END
        )) AS dni,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        p.importe,
        pdt.PDT AS tipodoc
    FROM PR_Employee e
        INNER JOIN SY_Person sp ON sp.person = e.person
        INNER JOIN pr_mapping m ON m.company = e.company
        INNER JOIN Pagos p ON p.person = e.person
        LEFT JOIN SY_PersonDocumentType pdt
            ON pdt.PersonDocumentType = sp.EmployeeDocumentType
    WHERE e.company = @par_company
      AND e.payrolltype = @par_payrolltype
      AND e.salarycurrency = @par_currency
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND ISNULL(m.continentalbank, '') <> ''
      AND ISNULL(m.collectionform, '') <> ''
      AND e.collectionform = m.collectionform
      AND e.salarybank = m.continentalbank
      AND sp.status = 'A'
      AND (
            CASE
                WHEN e.status IS NULL THEN 'N'
                WHEN e.status = '' THEN 'N'
                WHEN e.status = 'N' THEN 'N'
                ELSE 'Y'
            END = 'N'
         OR e.ineffectivedate >= GETDATE()
      )
    ORDER BY nombre, dni;
END
GO



-- ============================================================================
-- [33/89] sp_pr_listado_declaracion_afp_web.sql
-- ============================================================================

/*
    Declaración AFP — reporte analítico RPR004 Planilla de AFP (AFPnet).

    Usado por: POST /api/declaracion-afp/listado y /api/declaracion-afp/generar-xlsx

    Basado en: AUXILIARES/REPORTE AFPNET.txt (DataWindow PowerBuilder).

    Parámetros:
      @cia              — compañía
      @period           — periodo YYYYMM (6 dígitos)
      @payroll_all      — Y = todas las planillas, N = filtrar por @payroll
      @payroll          — tipo de planilla
      @afp_all          — Y = todas las AFP, N = filtrar por @afp
      @afp              — código AFP
      @repunit_all      — Y = todas las unidades de replicación
      @repunit          — unidad de replicación
      @flagcostcenter   — Y = todos los centros de costo, N = filtrar por @costcenter
      @costcenter       — centro de costo
      @employee_all     — Y = todos los trabajadores, N = filtrar por @employee
      @employee         — código persona
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_declaracion_afp_web]
    @cia              VARCHAR(10),
    @period           VARCHAR(20),
    @payroll_all      CHAR(1)     = 'Y',
    @payroll          VARCHAR(20) = NULL,
    @afp_all          CHAR(1)     = 'Y',
    @afp              VARCHAR(20) = NULL,
    @repunit_all      CHAR(1)     = 'Y',
    @repunit          VARCHAR(4)  = NULL,
    @flagcostcenter   CHAR(1)     = 'Y',
    @costcenter       VARCHAR(20) = NULL,
    @employee_all     CHAR(1)     = 'Y',
    @employee         VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 6);
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @afp_all = UPPER(LTRIM(RTRIM(ISNULL(@afp_all, 'Y'))));
    SET @afp = LTRIM(RTRIM(ISNULL(@afp, '')));
    SET @repunit_all = UPPER(LTRIM(RTRIM(ISNULL(@repunit_all, 'Y'))));
    SET @repunit = LTRIM(RTRIM(ISNULL(@repunit, '')));
    SET @flagcostcenter = UPPER(LTRIM(RTRIM(ISNULL(@flagcostcenter, 'Y'))));
    SET @costcenter = LTRIM(RTRIM(ISNULL(@costcenter, '')));
    SET @employee_all = UPPER(LTRIM(RTRIM(ISNULL(@employee_all, 'Y'))));
    SET @employee = LTRIM(RTRIM(ISNULL(@employee, '')));

    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @afp_all NOT IN ('Y', 'N') SET @afp_all = 'Y';
    IF @repunit_all NOT IN ('Y', 'N') SET @repunit_all = 'Y';
    IF @flagcostcenter NOT IN ('Y', 'N') SET @flagcostcenter = 'Y';
    IF @employee_all NOT IN ('Y', 'N') SET @employee_all = 'Y';

    /* Régimen AFP y fechas ingreso/cese según planilla del periodo (PR_EmployeePayRoll). */
    CREATE TABLE #AfpPlanilla (
        person VARCHAR(20) NOT NULL PRIMARY KEY
    );

    INSERT INTO #AfpPlanilla (person)
    SELECT DISTINCT LTRIM(RTRIM(EP.Person))
    FROM PR_EmployeePayRoll EP (NOLOCK)
    WHERE EP.Company = @cia
      AND LEFT(EP.PRPeriod, 6) = @period
      AND ISNULL(LTRIM(RTRIM(EP.AFP)), '') <> ''
      AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
      AND (@afp_all = 'Y' OR LTRIM(RTRIM(EP.AFP)) = @afp);

    CREATE TABLE #PlanillaFechas (
        person VARCHAR(20) NOT NULL PRIMARY KEY,
        entrydate DATETIME NULL,
        ceasedate DATETIME NULL
    );

    INSERT INTO #PlanillaFechas (person, entrydate, ceasedate)
    SELECT
        LTRIM(RTRIM(EP.Person)),
        MAX(CASE WHEN LTRIM(RTRIM(PT.ShortName)) = 'FIN_DE_MES' THEN EP.EntryDate END),
        MAX(CASE WHEN LTRIM(RTRIM(PT.ShortName)) = 'FIN_DE_MES' THEN EP.CeaseDate END)
    FROM PR_EmployeePayRoll EP (NOLOCK)
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PT.ProcessType = EP.ProcessType
           AND PT.Company = EP.Company
    WHERE EP.Company = @cia
      AND LEFT(EP.PRPeriod, 6) = @period
      AND ISNULL(LTRIM(RTRIM(EP.AFP)), '') <> ''
      AND LTRIM(RTRIM(PT.ShortName)) = 'FIN_DE_MES'
      AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
      AND (@afp_all = 'Y' OR LTRIM(RTRIM(EP.AFP)) = @afp)
    GROUP BY LTRIM(RTRIM(EP.Person));

    SELECT
        E.person,
        LTRIM(RTRIM(ISNULL(F.description, ''))) AS afp_description,
        LTRIM(RTRIM(COALESCE(
            NULLIF(LTRIM(RTRIM(ISNULL(A.afpcard, ''))), ''),
            NULLIF(LTRIM(RTRIM(ISNULL(E.AFPCard, ''))), ''),
            ''
        ))) AS cuspp,
        LTRIM(RTRIM(ISNULL(P.documentnumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(P.lastname1, ''))) AS lastname1,
        LTRIM(RTRIM(ISNULL(P.lastname2, ''))) AS lastname2,
        LTRIM(RTRIM(ISNULL(P.name1, '') + ' ' + ISNULL(P.name2, ''))) AS names,
        CASE
            WHEN CONVERT(VARCHAR(4), YEAR(ISNULL(PL.ceasedate, PL.entrydate)))
                 + RIGHT('00' + CONVERT(VARCHAR(2), MONTH(ISNULL(PL.ceasedate, PL.entrydate))), 2) <> LEFT(A.prperiod, 6)
            THEN ''
            ELSE CASE
                WHEN PL.ceasedate IS NULL THEN '01 ' + CONVERT(CHAR(10), PL.entrydate, 103)
                ELSE '02 ' + CONVERT(CHAR(10), PL.ceasedate, 103)
            END
        END AS fecha_cese,
        CASE
            WHEN PL.entrydate IS NULL THEN ''
            ELSE CONVERT(CHAR(10), PL.entrydate, 103)
        END AS entrydate,
        CASE
            WHEN PL.ceasedate IS NULL THEN ''
            ELSE CONVERT(CHAR(10), PL.ceasedate, 103)
        END AS ceasedate,
        CASE
            WHEN PL.entrydate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), PL.entrydate, 112), 6) = @period THEN 'S'
            ELSE 'N'
        END AS inicio_relacion,
        CASE
            WHEN PL.ceasedate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), PL.ceasedate, 112), 6) = @period THEN 'S'
            ELSE 'N'
        END AS cese_relacion,
        CASE
            WHEN ISNULL((
                SELECT SUM(MR.Days)
                FROM PR_EmployeeMedicalRest MR (NOLOCK)
                    INNER JOIN PR_MedicalRestType MT (NOLOCK)
                        ON MR.MedicalRestType = MT.MedicalRestType
                       AND MT.pdt = '05'
                WHERE MR.person = E.person
                  AND MR.Company = @cia
                  AND LEFT(MR.PRPeriod, 6) = @period
            ), 0) >= 30
            AND NOT EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept X (NOLOCK)
                    INNER JOIN PR_Concept Y (NOLOCK)
                        ON X.Concept = Y.Concept
                       AND Y.Company = @cia
                WHERE Y.FormulaCode = 'TOTAL_REM_AFP'
                  AND X.Person = E.person
                  AND X.Company = @cia
                  AND LEFT(X.PRPeriod, 6) = @period
            ) THEN 'L'
            ELSE ''
        END AS excepcion_aportar,
        CASE
            WHEN CAST(ISNULL(A.assureableremamountlo, 0) AS DECIMAL(19, 2)) > 0 THEN 'S'
            WHEN ISNULL((
                SELECT SUM(MR.Days)
                FROM PR_EmployeeMedicalRest MR (NOLOCK)
                    INNER JOIN PR_MedicalRestType MT (NOLOCK)
                        ON MR.MedicalRestType = MT.MedicalRestType
                       AND MT.pdt = '05'
                WHERE MR.person = E.person
                  AND MR.Company = @cia
                  AND LEFT(MR.PRPeriod, 6) = @period
            ), 0) >= 30
            AND NOT EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept X (NOLOCK)
                    INNER JOIN PR_Concept Y (NOLOCK)
                        ON X.Concept = Y.Concept
                       AND Y.Company = @cia
                WHERE Y.FormulaCode = 'TOTAL_REM_AFP'
                  AND X.Person = E.person
                  AND X.Company = @cia
                  AND LEFT(X.PRPeriod, 6) = @period
            ) THEN 'S'
            WHEN E.reentrydate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), E.reentrydate, 112), 6) = @period THEN 'S'
            WHEN E.reentrydate IS NULL
             AND E.entrydate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), E.entrydate, 112), 6) = @period THEN 'S'
            WHEN PL.entrydate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), PL.entrydate, 112), 6) = @period THEN 'S'
            WHEN PL.ceasedate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), PL.ceasedate, 112), 6) = @period THEN 'S'
            ELSE 'N'
        END AS relacion_laboral,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeConcept EC (NOLOCK)
                    INNER JOIN PR_Concept C2 (NOLOCK)
                        ON EC.Concept = C2.Concept
                       AND C2.Company = @cia
                WHERE EC.Person = E.person
                  AND EC.PayRollType = E.payrolltype
                  AND EC.Company = @cia
                  AND C2.FormulaCode = 'FLAG_MINERO'
            ) THEN 'M'
            ELSE 'N'
        END AS tipo_trabajo,
        CASE
            WHEN ISNULL((
                SELECT SUM(MR.Days)
                FROM PR_EmployeeMedicalRest MR (NOLOCK)
                    INNER JOIN PR_MedicalRestType MT (NOLOCK)
                        ON MR.MedicalRestType = MT.MedicalRestType
                       AND MT.pdt = '05'
                WHERE MR.person = E.person
                  AND MR.Company = @cia
                  AND LEFT(MR.PRPeriod, 6) = @period
            ), 0) >= 30
            AND NOT EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept X (NOLOCK)
                    INNER JOIN PR_Concept Y (NOLOCK)
                        ON X.Concept = Y.Concept
                       AND Y.Company = @cia
                WHERE Y.FormulaCode = 'TOTAL_REM_AFP'
                  AND X.Person = E.person
                  AND X.Company = @cia
                  AND LEFT(X.PRPeriod, 6) = @period
            ) THEN CAST(0 AS DECIMAL(19, 2))
            ELSE CAST(ISNULL(A.assureableremamountlo, 0) AS DECIMAL(19, 2))
        END AS remuneracion,
        CAST(ISNULL(F.TopAFP, 0) AS DECIMAL(19, 2)) AS topafp,
        CAST(ISNULL(F.InsuredPercentage, 0) AS DECIMAL(19, 4)) AS insuredpercentage,
        CAST(ISNULL(A.fixedamountlo, 0) AS DECIMAL(19, 2)) AS aporte_obligatorio,
        CAST(ISNULL(A.variableamountlo, 0) AS DECIMAL(19, 2)) AS aporte_empleador,
        CAST(ISNULL(A.fixedamountlo, 0) + ISNULL(A.variableamountlo, 0) AS DECIMAL(19, 2)) AS total_fondo_pensiones,
        CAST(ISNULL(A.insuredamountlo, 0) AS DECIMAL(19, 2)) AS seguro,
        CAST(ROUND(
            (
                CASE
                    WHEN ISNULL(F.TopAFP, 0) > 0 AND ISNULL(A.assureableremamountlo, 0) > ISNULL(F.TopAFP, 0)
                        THEN F.TopAFP
                    ELSE ISNULL(A.assureableremamountlo, 0)
                END
            ) * ISNULL(F.InsuredPercentage, 0) / 100.0,
        2) AS DECIMAL(19, 2)) AS seguro_esperado,
        CAST(ISNULL(A.arcomisionamountlo, 0) AS DECIMAL(19, 2)) AS comision,
        CAST(ISNULL(A.insuredamountlo, 0) + ISNULL(A.arcomisionamountlo, 0) AS DECIMAL(19, 2)) AS total_retenciones,
        CAST(ISNULL((
            SELECT CONCEPTVALUE
            FROM PR_EMPLOYEEPAYROLLCONCEPT X (NOLOCK)
                INNER JOIN PR_Concept Y (NOLOCK) ON X.Concept = Y.Concept
            WHERE X.COMPANY = @cia
              AND Y.COMPANY = @cia
              AND X.concept = Y.concept
              AND X.PROCESSTYPE = (
                    SELECT processtype
                    FROM pr_processtype (NOLOCK)
                    WHERE shortname = 'FIN_DE_MES'
                      AND company = @cia
                )
              AND X.PAYROLLTYPE = E.payrolltype
              AND LEFT(X.PRPERIOD, 6) = @period
              AND Y.formulacode = 'AFP2APORTE'
              AND X.PERSON = E.person
        ), 0) AS DECIMAL(19, 2)) AS aporte_riesgo_trab,
        ISNULL((
            SELECT CASE LTRIM(RTRIM(ISNULL(S.pdt, '')))
                WHEN '01' THEN '0'
                WHEN '04' THEN '1'
                WHEN '02' THEN '2'
                WHEN '03' THEN '2'
                WHEN '13' THEN '3'
                WHEN '11' THEN '3'
                WHEN '07' THEN '4'
                ELSE '0'
            END
            FROM sy_persondocumenttype S (NOLOCK)
            WHERE S.PersonDocumentType = P.employeedocumenttype
        ), '0') AS tipodoc
    FROM PR_EmployeeAFP A (NOLOCK)
        INNER JOIN PR_EmployeeAFPHeader H (NOLOCK)
            ON H.company = A.company
           AND H.prperiod = A.prperiod
           AND H.afp = A.afp
           AND H.replicationunit = A.replicationunit
           AND H.costcenter = A.costcenter
           AND H.payrolltype = A.payrolltype
        INNER JOIN PR_AFP F (NOLOCK) ON A.afp = F.afp
        INNER JOIN sy_person P (NOLOCK) ON A.person = P.person
        INNER JOIN pr_employee E (NOLOCK)
            ON A.person = E.person
           AND A.company = E.company
        INNER JOIN #AfpPlanilla AP (NOLOCK)
            ON AP.person = LTRIM(RTRIM(A.person))
        INNER JOIN #PlanillaFechas PL (NOLOCK)
            ON PL.person = LTRIM(RTRIM(A.person))
        INNER JOIN sy_company C (NOLOCK) ON A.company = C.company
    WHERE A.company = @cia
      AND LEFT(A.prperiod, 6) = @period
      AND (@payroll_all = 'Y' OR H.payrolltype = @payroll)
      AND (@afp_all = 'Y' OR A.afp = @afp)
      AND (@repunit_all = 'Y' OR H.replicationunit = @repunit)
      AND (@flagcostcenter = 'Y' OR H.costcenter = @costcenter)
      AND (@employee_all = 'Y' OR A.person = @employee)

    UNION ALL

    /* Jubilados: PR_EmployeeConcept con FLAG_JUBILADO (legacy UNION ALL AFPnet). */
    SELECT
        E.person,
        '(Jubilado)' AS afp_description,
        LTRIM(RTRIM(ISNULL(E.AFPCard, ''))) AS cuspp,
        LTRIM(RTRIM(ISNULL(P.documentnumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(P.lastname1, ''))) AS lastname1,
        LTRIM(RTRIM(ISNULL(P.lastname2, ''))) AS lastname2,
        LTRIM(RTRIM(ISNULL(P.name1, '') + ' ' + ISNULL(P.name2, ''))) AS names,
        CASE
            WHEN CONVERT(VARCHAR(4), YEAR(ISNULL(PL.ceasedate, PL.entrydate)))
                 + RIGHT('00' + CONVERT(VARCHAR(2), MONTH(ISNULL(PL.ceasedate, PL.entrydate))), 2) <> LEFT(@period, 6)
            THEN ''
            ELSE CASE
                WHEN PL.ceasedate IS NULL THEN '01 ' + CONVERT(CHAR(10), PL.entrydate, 103)
                ELSE '02 ' + CONVERT(CHAR(10), PL.ceasedate, 103)
            END
        END AS fecha_cese,
        CASE
            WHEN PL.entrydate IS NULL THEN ''
            ELSE CONVERT(CHAR(10), PL.entrydate, 103)
        END AS entrydate,
        CASE
            WHEN PL.ceasedate IS NULL THEN ''
            ELSE CONVERT(CHAR(10), PL.ceasedate, 103)
        END AS ceasedate,
        CASE
            WHEN PL.entrydate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), PL.entrydate, 112), 6) = @period THEN 'S'
            ELSE 'N'
        END AS inicio_relacion,
        CASE
            WHEN PL.ceasedate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), PL.ceasedate, 112), 6) = @period THEN 'S'
            ELSE 'N'
        END AS cese_relacion,
        CASE
            WHEN ISNULL((
                SELECT SUM(MR.Days)
                FROM PR_EmployeeMedicalRest MR (NOLOCK)
                    INNER JOIN PR_MedicalRestType MT (NOLOCK)
                        ON MR.MedicalRestType = MT.MedicalRestType
                       AND MT.pdt = '05'
                WHERE MR.person = E.person
                  AND MR.Company = @cia
                  AND LEFT(MR.PRPeriod, 6) = @period
            ), 0) >= 30
            AND NOT EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept X (NOLOCK)
                    INNER JOIN PR_Concept Y (NOLOCK)
                        ON X.Concept = Y.Concept
                       AND Y.Company = @cia
                WHERE Y.FormulaCode = 'TOTAL_REM_AFP'
                  AND X.Person = E.person
                  AND X.Company = @cia
                  AND LEFT(X.PRPeriod, 6) = @period
            ) THEN 'L'
            ELSE 'J'
        END AS excepcion_aportar,
        'S' AS relacion_laboral,
        'N' AS tipo_trabajo,
        CAST(0 AS DECIMAL(19, 2)) AS remuneracion,
        CAST(0 AS DECIMAL(19, 2)) AS topafp,
        CAST(0 AS DECIMAL(19, 4)) AS insuredpercentage,
        CAST(0 AS DECIMAL(19, 2)) AS aporte_obligatorio,
        CAST(0 AS DECIMAL(19, 2)) AS aporte_empleador,
        CAST(0 AS DECIMAL(19, 2)) AS total_fondo_pensiones,
        CAST(0 AS DECIMAL(19, 2)) AS seguro,
        CAST(0 AS DECIMAL(19, 2)) AS seguro_esperado,
        CAST(0 AS DECIMAL(19, 2)) AS comision,
        CAST(0 AS DECIMAL(19, 2)) AS total_retenciones,
        CAST(0 AS DECIMAL(19, 2)) AS aporte_riesgo_trab,
        ISNULL((
            SELECT CASE LTRIM(RTRIM(ISNULL(S.pdt, '')))
                WHEN '01' THEN '0'
                WHEN '04' THEN '1'
                WHEN '02' THEN '2'
                WHEN '03' THEN '2'
                WHEN '13' THEN '3'
                WHEN '11' THEN '3'
                WHEN '07' THEN '4'
                ELSE '0'
            END
            FROM sy_persondocumenttype S (NOLOCK)
            WHERE S.PersonDocumentType = P.employeedocumenttype
        ), '0') AS tipodoc
    FROM PR_EmployeeConcept EC (NOLOCK)
        INNER JOIN PR_Employee E (NOLOCK)
            ON EC.Person = E.Person
           AND EC.Company = E.Company
        INNER JOIN PR_Concept C (NOLOCK)
            ON EC.Concept = C.Concept
           AND C.Company = @cia
        INNER JOIN sy_person P (NOLOCK)
            ON EC.Person = P.person
        INNER JOIN #AfpPlanilla AP (NOLOCK)
            ON AP.person = LTRIM(RTRIM(EC.Person))
        INNER JOIN #PlanillaFechas PL (NOLOCK)
            ON PL.person = LTRIM(RTRIM(EC.Person))
    WHERE EC.Company = @cia
      AND C.FormulaCode = 'FLAG_JUBILADO'
      AND EC.FlagFrecuencyType IN ('P', 'T')
      AND (
            EC.FlagFrecuencyType = 'P'
            OR (EC.FlagFrecuencyType = 'T' AND LEFT(EC.PRPeriodStart, 6) = @period)
          )
      AND (@payroll_all = 'Y' OR EC.PayRollType = @payroll)
      AND (@employee_all = 'Y' OR EC.Person = @employee)
      AND NOT EXISTS (
            SELECT 1
            FROM PR_EmployeeAFP A2 (NOLOCK)
            WHERE A2.person = EC.Person
              AND A2.company = @cia
              AND LEFT(A2.prperiod, 6) = @period
      )

    ORDER BY afp_description, lastname1;

    DROP TABLE #PlanillaFechas;
    DROP TABLE #AfpPlanilla;
END
GO



-- ============================================================================
-- [34/89] sp_pr_listado_plame14_web.sql
-- ============================================================================

/*
    Listado PLAME Archivo 14 — Jornada laboral y sobretiempo.
    Usado por: POST /api/plame/archivo-14/listado (plame_archivo14.html).

    Basado en sp_pr_listado_plame14 legacy (PowerBuilder).

    Parámetros:
      @cia    — código de compañía
      @period — periodo tributario YYYYMM (6 dígitos)

    Campos exportables (pipe |):
      Tipo doc (2), N° doc (15), Horas ord (3), Min ord (2), Horas extra (3), Min extra (2)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_plame14_web]
    @cia    VARCHAR(4),
    @period VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    SELECT
        person,
        documenttype,
        documentnumber,
        name,
        workinghours,
        workingminutes,
        extrahours,
        extraminutes,
        selection
    FROM (
        SELECT
            pr_employee.person AS person,
            CASE WHEN sy_persondocumenttype.pdt = '03' THEN '04' ELSE sy_persondocumenttype.pdt END AS documenttype,
            sy_person.documentnumber AS documentnumber,
            LTRIM(RTRIM(
                ISNULL(sy_person.lastname1, '') + ' ' +
                ISNULL(sy_person.lastname2, '') + ' ' +
                ISNULL(sy_person.name1, '') + ' ' +
                ISNULL(sy_person.name2, '')
            )) AS name,
            ISNULL((
                SELECT SUM(ISNULL(E.ConceptValueLo, E.ConceptValue) * CASE WHEN P.applysum = 'P' THEN 1 ELSE -1 END)
                FROM PR_EmployeePayRollConcept E
                    INNER JOIN PR_Mapping M ON (E.Company = M.Company AND M.Company = @cia)
                    INNER JOIN PR_CompanyPlame P ON (
                        E.Concept = P.concept
                        AND E.Company = @cia
                        AND E.Person = pr_employeepayroll.Person
                        AND E.PRPeriod = pr_employeepayroll.PRPeriod
                        AND E.PayRollType = pr_employeepayroll.PayRollType
                        AND E.ProcessType IN (M.PlanillaProcess, M.PlanillaSemProcess)
                        AND P.plame = '14'
                        AND P.type = 'WH'
                    )
            ), 0) AS workinghours,
            0 AS workingminutes,
            ISNULL((
                SELECT SUM(ISNULL(E.ConceptValueLo, E.ConceptValue) * CASE WHEN P.applysum = 'P' THEN 1 ELSE -1 END)
                FROM PR_EmployeePayRollConcept E
                    INNER JOIN PR_Mapping M ON (E.Company = M.Company AND M.Company = @cia)
                    INNER JOIN PR_CompanyPlame P ON (
                        E.Concept = P.concept
                        AND E.Company = @cia
                        AND E.Person = pr_employeepayroll.Person
                        AND E.PRPeriod = pr_employeepayroll.PRPeriod
                        AND E.PayRollType = pr_employeepayroll.PayRollType
                        AND E.ProcessType IN (M.PlanillaProcess, M.PlanillaSemProcess)
                        AND P.plame = '14'
                        AND P.type = 'HE'
                    )
            ), 0) AS extrahours,
            0 AS extraminutes,
            'N' AS selection
        FROM pr_employee (NOLOCK)
            INNER JOIN SY_Company ON (PR_Employee.Company = SY_Company.Company AND pr_employee.company = @cia)
            INNER JOIN sy_person (NOLOCK) ON (sy_person.person = pr_employee.person)
            LEFT JOIN sy_persondocumenttype (NOLOCK) ON (sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype)
            INNER JOIN pr_employeecategory (NOLOCK) ON (pr_employee.employeecategory = pr_employeecategory.employeecategory)
            INNER JOIN pr_mapping (NOLOCK) ON (PR_Employee.Company = PR_Mapping.Company AND pr_mapping.company = @cia)
            INNER JOIN pr_employeepayroll (NOLOCK) ON (
                pr_employeepayroll.PayRollType = pr_employee.PayRollType
                AND pr_employeepayroll.Person = pr_employee.Person
                AND pr_employeepayroll.company = pr_employee.company
                AND pr_employeepayroll.ProcessType IN (pr_mapping.PlanillaProcess, pr_mapping.PlanillaSemProcess)
            )
        WHERE pr_employeecategory.PDT IN ('1')
          AND SUBSTRING(pr_employeepayroll.PRPeriod, 1, 6) = @period
    ) T
    GROUP BY
        person,
        documenttype,
        documentnumber,
        name,
        workinghours,
        workingminutes,
        extrahours,
        extraminutes,
        selection
    ORDER BY name ASC;
END
GO



-- ============================================================================
-- [35/89] sp_pr_listado_plame15_web.sql
-- ============================================================================

/*
    PLAME Archivo 15 (.snl) — Días subsidiados y no laborados.

    Usado por: POST /api/plame/archivo-15/listado y generación TXT.

    Línea TXT: TipoDoc|NroDoc|TipoSuspensión|Días|
    Ejemplo:   01|46741460|01|07|

    Parámetros:
      @cia    — compañía
      @period — periodo tributario YYYYMM (6 dígitos)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_plame15_web]
    @cia    VARCHAR(10),
    @period VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    SELECT
        D.person,
        CASE WHEN sy_persondocumenttype.pdt = '03' THEN '04' ELSE sy_persondocumenttype.pdt END AS documenttype,
        LTRIM(RTRIM(sy_person.documentnumber)) AS documentnumber,
        LTRIM(RTRIM(
            ISNULL(sy_person.lastname1, '') + ' ' +
            ISNULL(sy_person.lastname2, '') + ' ' +
            ISNULL(sy_person.name1, '') + ' ' +
            ISNULL(sy_person.name2, '')
        )) AS name,
        LTRIM(RTRIM(D.pdt)) AS suspensiontype,
        LTRIM(RTRIM(ISNULL(T21.description, D.pdt))) AS suspensionname,
        CAST(D.days AS INT) AS days,
        'N' AS selection
    FROM (
        /* Descanso médico — ESSALUD / subsidio (payreponsableflag = S) */
        SELECT
            pr_employee.person AS person,
            pr_medicalresttype.pdt AS pdt,
            SUM(pr_employeemedicalrest.days) AS days
        FROM pr_employee (NOLOCK)
            INNER JOIN pr_employeemedicalrest (NOLOCK)
                ON pr_employee.person = pr_employeemedicalrest.person
               AND pr_employee.company = pr_employeemedicalrest.company
            INNER JOIN pr_medicalresttype (NOLOCK)
                ON pr_medicalresttype.medicalresttype = pr_employeemedicalrest.medicalresttype
        WHERE pr_employee.company = @cia
          AND LEFT(pr_employeemedicalrest.prperiod, 6) = @period
          AND pr_medicalresttype.pdt IN ('01', '05', '07', '26', '20', '21', '22')
          AND pr_employeemedicalrest.payreponsableflag = 'S'
        GROUP BY
            pr_employee.person,
            pr_medicalresttype.pdt

        UNION

        /* Vacaciones — días (tipo D) */
        SELECT
            pr_vacationdetail.person AS person,
            pr_mapping.vacationpdt AS pdt,
            SUM(pr_vacationdetail.days) AS days
        FROM pr_vacationdetail (NOLOCK)
            INNER JOIN pr_mapping (NOLOCK)
                ON pr_mapping.company = @cia
        WHERE pr_vacationdetail.company = @cia
          AND pr_vacationdetail.vacationtype = 'D'
          AND LEFT(pr_vacationdetail.prperiod, 6) = @period
        GROUP BY
            pr_vacationdetail.person,
            pr_mapping.vacationpdt

        UNION

        /* Descanso médico — empleador (payreponsableflag = E) */
        SELECT
            pr_employeemedicalrest.person AS person,
            pr_medicalresttype.pdt AS pdt,
            SUM(pr_employeemedicalrest.days) AS days
        FROM pr_employeemedicalrest (NOLOCK)
            INNER JOIN pr_medicalresttype (NOLOCK)
                ON pr_employeemedicalrest.medicalresttype = pr_medicalresttype.medicalresttype
        WHERE pr_employeemedicalrest.company = @cia
          AND pr_medicalresttype.company = @cia
          AND LEFT(pr_employeemedicalrest.prperiod, 6) = @period
          AND pr_employeemedicalrest.payreponsableflag = 'E'
          AND pr_medicalresttype.pdt NOT IN ('21', '22', '99')
        GROUP BY
            pr_employeemedicalrest.person,
            pr_medicalresttype.pdt
    ) D
        INNER JOIN pr_employee (NOLOCK)
            ON pr_employee.person = D.person
           AND pr_employee.company = @cia
        INNER JOIN sy_person (NOLOCK)
            ON sy_person.person = pr_employee.person
        LEFT JOIN sy_persondocumenttype (NOLOCK)
            ON sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype
        LEFT JOIN (
            SELECT
                LTRIM(RTRIM(pdt)) AS pdt,
                MIN(LTRIM(RTRIM(Description))) AS description
            FROM pr_medicalresttype (NOLOCK)
            WHERE company = @cia
            GROUP BY LTRIM(RTRIM(pdt))
        ) T21
            ON T21.pdt = LTRIM(RTRIM(D.pdt))
    WHERE ISNULL(D.days, 0) <> 0
      AND LTRIM(RTRIM(ISNULL(sy_person.documentnumber, ''))) <> ''
    ORDER BY name, suspensiontype;
END
GO



-- ============================================================================
-- [36/89] sp_pr_listado_plame18_web.sql
-- ============================================================================

/*
    PLAME Archivo 18 (.rem) — Ingresos, tributos y descuentos del trabajador.

    Usado por: POST /api/plame/archivo-18/listado y generación TXT.

    Línea TXT: TipoDoc|NroDoc|PDT|Devengado|Pagado|
    Nombre archivo: 0601AAAAMMRRRRRRRRRRR.rem

    Basado en queries legacy PowerBuilder (listado de empleados + cálculo de conceptos).

    Parámetros:
      @cia         — compañía
      @period      — periodo tributario YYYYMM (6 dígitos)
      @payroll_all — Y = todas las planillas, N = filtrar por @payroll
      @payroll     — tipo de planilla (cuando @payroll_all = N)
      @cesados     — T = todos, Y = solo cesados, N = sin cese
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_plame18_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(20),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL,
    @cesados     CHAR(1)     = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    CREATE TABLE #Empleados (
        person VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY
    );

    /* --- Empleados con conceptos en el periodo (rama principal) --- */
    INSERT INTO #Empleados (person)
    SELECT DISTINCT pr_employee.person
    FROM pr_employee (NOLOCK)
        INNER JOIN sy_person (NOLOCK) ON sy_person.person = pr_employee.person
        LEFT JOIN sy_persondocumenttype (NOLOCK)
            ON sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype
        INNER JOIN pr_concept (NOLOCK) ON 1 = 1
        INNER JOIN pr_concepttype (NOLOCK) ON pr_concepttype.concepttype = pr_concept.concepttype
        INNER JOIN pr_employeepayrollconcept (NOLOCK) ON pr_employeepayrollconcept.concept = pr_concept.concept
        INNER JOIN pr_mapping (NOLOCK) ON pr_mapping.company = @cia
        INNER JOIN pr_employeecategory (NOLOCK) ON pr_employee.employeecategory = pr_employeecategory.employeecategory
    WHERE sy_person.person = pr_employee.person
      AND pr_mapping.company = @cia
      AND pr_employee.employeecategory = pr_employeecategory.employeecategory
      AND pr_employeecategory.PDT = '1'
      AND pr_employeepayrollconcept.concept = pr_concept.concept
      AND pr_concepttype.concepttype = pr_concept.concepttype
      AND pr_concepttype.shortname IN ('I', 'A')
      AND (@payroll_all = 'Y' OR pr_employeepayrollconcept.payrolltype = @payroll)
      AND pr_employeepayrollconcept.person = pr_employee.person
      AND pr_employeepayrollconcept.company = pr_employee.company
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND pr_employee.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND pr_employee.CeaseDate IS NULL)
      )
      AND pr_employeepayrollconcept.processtype IN (
            pr_mapping.CTSProcessType,
            pr_mapping.planillaprocess,
            pr_mapping.planillasemprocess,
            pr_mapping.VacationProcess,
            pr_mapping.liquidacionprocess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND LEFT(pr_employeepayrollconcept.prperiod, 6) = @period
      AND pr_employeepayrollconcept.conceptvaluelo IS NOT NULL
      AND pr_concept.flagismonetary = 'Y'
      AND pr_concept.FLAGPAYROLLTICKET = 'Y'
      AND (
            (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') = 0
         OR (
                (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') > 0
                AND ISNULL(sy_person.isrecruiter, 'N') = 'N'
            )
      );

    /* --- Empleados con descanso médico >= 30 días sin TOTALINGRESO (rama legacy) --- */
    INSERT INTO #Empleados (person)
    SELECT A.person
    FROM PR_Employee A
        INNER JOIN SY_Person B ON A.Person = B.Person AND A.Status = 'N' AND A.Company = @cia
        LEFT JOIN sy_persondocumenttype S ON B.employeedocumenttype = S.persondocumenttype
        INNER JOIN PR_Mapping M ON A.Company = M.Company
    WHERE NOT EXISTS (
            SELECT 1
            FROM pr_employeepayrollconcept P
                INNER JOIN PR_Concept C ON P.Concept = C.Concept AND C.FormulaCode = 'TOTALINGRESO'
            WHERE P.Company = A.Company
              AND P.Person = A.Person
              AND LEFT(P.PRPeriod, 6) = @period
        )
      AND ISNULL((
            SELECT SUM(X.Days)
            FROM PR_EmployeeMedicalRest X
                INNER JOIN PR_MedicalRestType Y
                    ON X.person = A.person
                   AND X.MedicalRestType = Y.MedicalRestType
                   AND Y.pdt = '05'
                   AND LEFT(X.PRPeriod, 6) = @period
                   AND A.Company = @cia
        ), 0) >= 30
      AND NOT EXISTS (
            SELECT 1
            FROM PR_EmployeePayRoll P
            WHERE P.Person = A.Person
              AND P.Company = A.Company
              AND LEFT(P.PRPeriod, 6) = @period
              AND P.ProcessType = M.CTSProcessType
        )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND A.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND A.CeaseDate IS NULL)
      )
      AND NOT EXISTS (SELECT 1 FROM #Empleados E WHERE E.person = A.person);

    CREATE TABLE #Conceptos (
        person          VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        pdt             VARCHAR(10) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        conceptvalue    NUMERIC(19, 4) NOT NULL,
        conceptvaluelo  NUMERIC(19, 4) NOT NULL,
        PRIMARY KEY (person, pdt)
    );

    INSERT INTO #Conceptos (person, pdt, conceptvalue, conceptvaluelo)
    SELECT
        A.person,
        A.pdt,
        SUM(A.conceptvalue) AS conceptvalue,
        SUM(A.conceptvaluelo) AS conceptvaluelo
    FROM (
        SELECT
            pr_employee.person,
            LTRIM(RTRIM(pr_concept.pdt)) AS pdt,
            SUM(pr_employeepayrollconcept.conceptvaluelo) AS conceptvalue,
            SUM(pr_employeepayrollconcept.conceptvaluelo) AS conceptvaluelo
        FROM pr_employee (NOLOCK)
            INNER JOIN pr_employeepayrollconcept (NOLOCK)
                ON pr_employeepayrollconcept.person = pr_employee.person
               AND pr_employeepayrollconcept.company = pr_employee.company
            INNER JOIN pr_employeepayroll (NOLOCK)
                ON pr_employeepayrollconcept.company = pr_employeepayroll.company
               AND pr_employeepayrollconcept.person = pr_employeepayroll.person
               AND pr_employeepayrollconcept.payrolltype = pr_employeepayroll.payrolltype
               AND pr_employeepayrollconcept.processtype = pr_employeepayroll.processtype
               AND pr_employeepayrollconcept.prperiod = pr_employeepayroll.prperiod
            INNER JOIN pr_concept (NOLOCK) ON pr_employeepayrollconcept.concept = pr_concept.concept
            INNER JOIN pr_concepttype (NOLOCK) ON pr_concepttype.concepttype = pr_concept.concepttype
            INNER JOIN pr_mapping (NOLOCK) ON pr_mapping.company = @cia
        WHERE pr_mapping.company = @cia
          AND pr_mapping.company = pr_employee.company
          AND pr_employeepayrollconcept.concept = pr_concept.concept
          AND pr_concepttype.concepttype = pr_concept.concepttype
          AND pr_employeepayrollconcept.person = pr_employee.person
          AND pr_employeepayrollconcept.company = pr_employee.company
          AND (
                (SELECT COUNT(*) FROM pr_payrolltypeprocess WHERE company = @cia AND flagpdt = 'Y') = 0
             OR (
                    SELECT COUNT(*)
                    FROM pr_payrolltypeprocess
                    WHERE PayRollType = pr_employeepayrollconcept.PayRollType
                      AND ProcessType = pr_employeepayrollconcept.ProcessType
                      AND flagpdt = 'Y'
                ) > 0
          )
          AND NOT EXISTS (
                SELECT 1
                FROM pr_processtype
                WHERE ProcessType = pr_employeepayrollconcept.ProcessType
                  AND Company = @cia
                  AND ShortName = 'QUINCENA'
          )
          AND LEFT(pr_employeepayrollconcept.prperiod, 6) = @period
          AND (@payroll_all = 'Y' OR pr_employeepayrollconcept.payrolltype = @payroll)
          AND pr_employeepayrollconcept.conceptvaluelo IS NOT NULL
          AND pr_concept.pdt IS NOT NULL
          AND LTRIM(RTRIM(pr_concept.pdt)) <> ''
          AND pr_concept.flagismonetary = 'Y'
          AND pr_concept.pdt NOT IN (
                '0100', '0200', '0300', '0400', '0500', '0600', '0603', '0604', '0607',
                '0610', '0700', '0800', '0802', '0804', '0806', '0808'
          )
          AND pr_employeepayrollconcept.processtype NOT IN ('LIMABGT 000000000010', 'LIMABGT 000000000011')
          AND EXISTS (SELECT 1 FROM #Empleados E WHERE E.person = pr_employee.person)
        GROUP BY pr_employee.person, pr_concept.pdt

        UNION ALL

        SELECT
            pr_employee.person,
            LTRIM(RTRIM(pr_concept.pdt)) AS pdt,
            0 AS conceptvalue,
            0 AS conceptvaluelo
        FROM pr_employee (NOLOCK)
            INNER JOIN pr_concept (NOLOCK) ON 1 = 1
            INNER JOIN pr_mapping (NOLOCK) ON pr_mapping.company = @cia
            INNER JOIN sy_person (NOLOCK) ON sy_person.person = pr_employee.person
        WHERE pr_mapping.company = @cia
          AND pr_mapping.company = pr_employee.company
          AND sy_person.person = pr_employee.person
          AND pr_concept.pdt IS NOT NULL
          AND pr_concept.flagismonetary = 'Y'
          AND pr_concept.concept = pr_mapping.taxrentconcept
          AND (@payroll_all = 'Y' OR pr_employee.payrolltype = @payroll)
          AND EXISTS (SELECT 1 FROM #Empleados E WHERE E.person = pr_employee.person)
        GROUP BY pr_employee.person, pr_concept.pdt
    ) A
    GROUP BY A.person, A.pdt
    HAVING SUM(A.conceptvaluelo) <> 0 OR SUM(A.conceptvalue) <> 0;

    /* 0605 — quinta categoría: valor 0 si el trabajador no tiene retención en el periodo */
    INSERT INTO #Conceptos (person, pdt, conceptvalue, conceptvaluelo)
    SELECT E.person, '0605', 0, 0
    FROM #Empleados E
    WHERE NOT EXISTS (
        SELECT 1
        FROM #Conceptos C
        WHERE C.person = E.person
          AND C.pdt = '0605'
    );

    /* 0601 — comisión AFP: valor 0 solo si el trabajador tiene régimen AFP (no ONP) y no tiene comisión en el periodo */
    INSERT INTO #Conceptos (person, pdt, conceptvalue, conceptvaluelo)
    SELECT E.person, '0601', 0, 0
    FROM #Empleados E
    WHERE NOT EXISTS (
        SELECT 1
        FROM #Conceptos C
        WHERE C.person = E.person
          AND C.pdt = '0601'
    )
      AND EXISTS (
        SELECT 1
        FROM PR_Employee EM (NOLOCK)
            LEFT JOIN PR_PensionType PT (NOLOCK)
                ON PT.PensionType = EM.PensionType
               AND (
                    LTRIM(RTRIM(ISNULL(PT.Company, ''))) = ''
                    OR PT.Company = EM.Company
               )
        WHERE EM.Company = @cia
          AND EM.Person = E.person
          AND LTRIM(RTRIM(ISNULL(PT.PDT, ''))) IN ('21', '22', '23', '24', '25')
    );

    /* 0601 solo aplica a AFP: excluir ONP (PDT 02) y sin régimen aunque exista dato residual en planilla */
    DELETE C
    FROM #Conceptos C
        INNER JOIN PR_Employee EM (NOLOCK)
            ON EM.Person = C.person
           AND EM.Company = @cia
        LEFT JOIN PR_PensionType PT (NOLOCK)
            ON PT.PensionType = EM.PensionType
           AND (
                LTRIM(RTRIM(ISNULL(PT.Company, ''))) = ''
                OR PT.Company = EM.Company
           )
    WHERE C.pdt = '0601'
      AND LTRIM(RTRIM(ISNULL(PT.PDT, ''))) NOT IN ('21', '22', '23', '24', '25');

    SELECT
        C.person,
        CASE WHEN S.pdt = '03' THEN '04' ELSE S.pdt END AS documenttype,
        LTRIM(RTRIM(B.documentnumber)) AS documentnumber,
        LTRIM(RTRIM(
            ISNULL(B.lastname1, '') + ' ' +
            ISNULL(B.lastname2, '') + ' ' +
            ISNULL(B.name1, '') + ' ' +
            ISNULL(B.name2, '')
        )) AS name,
        LTRIM(RTRIM(C.pdt)) AS pdt,
        CAST(C.conceptvalue AS DECIMAL(19, 2)) AS conceptvalue,
        CAST(C.conceptvaluelo AS DECIMAL(19, 2)) AS conceptvaluelo,
        'N' AS selection
    FROM #Conceptos C
        INNER JOIN PR_Employee A ON A.Person = C.person AND A.Company = @cia
        INNER JOIN SY_Person B ON A.Person = B.Person
        LEFT JOIN sy_persondocumenttype S ON B.employeedocumenttype = S.persondocumenttype
    ORDER BY name ASC, C.pdt ASC;

    DROP TABLE #Conceptos;
    DROP TABLE #Empleados;
END
GO



-- ============================================================================
-- [37/89] sp_pr_listado_plame26_web.sql
-- ============================================================================

/*
    PLAME Archivo 26 (.toc) — Indicador de aporte "Asegura tu pensión".

    Usado por: POST /api/plame/archivo-26/listado y generación TXT.

    Línea TXT: TipoDoc|NroDoc|Indicador|
    Ejemplo:   01|46741460|0|

    Solo tipos de documento Tabla 3: 01, 04, 07, 09 (carné extranjería 03 → 04).

    Parámetros:
      @cia    — compañía
      @period — periodo tributario YYYYMM (6 dígitos)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listado_plame26_web]
    @cia    VARCHAR(10),
    @period VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    IF LEN(@period) > 6
        SET @period = LEFT(@period, 6);

    SELECT DISTINCT
        pr_employee.person,
        CASE
            WHEN sy_persondocumenttype.pdt = '03' THEN '04'
            ELSE LTRIM(RTRIM(sy_persondocumenttype.pdt))
        END AS documenttype,
        LTRIM(RTRIM(sy_person.documentnumber)) AS documentnumber,
        LTRIM(RTRIM(
            ISNULL(sy_person.lastname1, '') + ' ' +
            ISNULL(sy_person.lastname2, '') + ' ' +
            ISNULL(sy_person.name1, '') + ' ' +
            ISNULL(sy_person.name2, '')
        )) AS name,
        '0' AS pensionmembership,
        CASE WHEN pr_employee.flagessaludvida = 'Y' THEN '1' ELSE '0' END AS accidentinsurance,
        LTRIM(RTRIM(ISNULL(pr_employee.TypeAporte, ''))) AS typeaporte,
        LTRIM(RTRIM(ISNULL(sy_person.isdomiciled, ''))) AS isdomiciled,
        'N' AS selection
    FROM pr_employee (NOLOCK)
        INNER JOIN sy_person (NOLOCK)
            ON sy_person.person = pr_employee.person
        LEFT JOIN sy_persondocumenttype (NOLOCK)
            ON sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype
        INNER JOIN pr_employeecategory (NOLOCK)
            ON pr_employee.employeecategory = pr_employeecategory.employeecategory
        INNER JOIN pr_mapping (NOLOCK)
            ON pr_mapping.company = @cia
        INNER JOIN pr_employeepayroll (NOLOCK)
            ON pr_employeepayroll.PayRollType = pr_employee.PayRollType
           AND pr_employeepayroll.Person = pr_employee.Person
           AND pr_employeepayroll.company = pr_employee.company
           AND pr_employeepayroll.ProcessType IN (pr_mapping.PlanillaProcess, pr_mapping.PlanillaSemProcess)
    WHERE pr_employee.company = @cia
      AND pr_employeecategory.PDT IN ('1')
      AND LEFT(pr_employeepayroll.PRPeriod, 6) = @period
      AND LTRIM(RTRIM(ISNULL(sy_person.documentnumber, ''))) <> ''
      AND (
            CHARINDEX(
                'SAINC',
                ISNULL((
                    SELECT TOP 1 LTRIM(RTRIM(Description))
                    FROM SY_Company
                    WHERE Company = @cia
                ), '')
            ) = 0
         OR EXISTS (
                SELECT 1
                FROM pr_payrolltype pt (NOLOCK)
                WHERE pt.PayRollType = pr_employeepayroll.PayRollType
                  AND pt.ShortName LIKE '%CIVIL%'
            )
      )
      AND (
            CASE
                WHEN sy_persondocumenttype.pdt = '03' THEN '04'
                ELSE LTRIM(RTRIM(sy_persondocumenttype.pdt))
            END
          ) IN ('01', '04', '07', '09')
    ORDER BY name;
END
GO



-- ============================================================================
-- [38/89] sp_pr_listadogenerarboletas_web.sql
-- ============================================================================

/*
    Generar boletas — listado de trabajadores con planilla calculada en el periodo.

    Usado por: POST /get_lista_boletas, descargar ZIP y envío masivo de boletas.

    Parámetros:
      @cia          — compañía
      @payrolltype  — tipo de planilla
      @processtype  — proceso
      @period       — periodo PRPeriod
      @person       — código persona; '0' = todos
      @nombre       — búsqueda parcial en SY_Person.Name (opcional)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listadogenerarboletas_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20),
    @nombre      VARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @nombre = NULLIF(LTRIM(RTRIM(ISNULL(@nombre, ''))), '');

    SELECT
        PR_EmployeePayRoll.Person AS person,
        SY_Person.Name AS nombre,
        PR_EmployeePayRoll.entrydate AS fechaingreso,
        PR_EmployeePayRoll.ceasedate AS fechacese,
        SY_Person.EMail AS email,
        ISNULL(SY_Person.Sex, 0) AS sex
    FROM PR_EmployeePayRoll
        INNER JOIN SY_Person ON PR_EmployeePayRoll.Person = SY_Person.Person
    WHERE PR_EmployeePayRoll.Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND PRPeriod = @period
      AND (@person = '0' OR PR_EmployeePayRoll.Person = @person)
      AND (
            @nombre IS NULL
         OR SY_Person.Name LIKE '%' + @nombre + '%'
      )
    ORDER BY 2;
END
GO



-- ============================================================================
-- [39/89] sp_pr_listainterbank_web.sql
-- ============================================================================

/*
    Listado de trabajadores elegibles para archivo Interbank (pago de haberes).
    Usa pr_mapping.interbankbank (no creditobank).

    @cesados: T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listainterbank_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @cesados         CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';

    ;WITH Pagos AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    )
    SELECT
        e.person,
        LTRIM(RTRIM(
            CASE
                WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                ELSE sp.DocumentNumber
            END
        )) AS dni,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        p.importe,
        t.pdt AS tipodoc
    FROM PR_Employee e
        INNER JOIN SY_Person sp
            ON sp.person = e.person
        INNER JOIN pr_mapping m
            ON m.company = e.company
        INNER JOIN Pagos p
            ON p.person = e.person
        LEFT JOIN SY_PersonDocumentType t
            ON sp.EmployeeDocumentType = t.PersonDocumentType
    WHERE e.company = @par_company
      AND e.payrolltype = @par_payrolltype
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND ISNULL(e.salaryaccount, '') <> ''
      AND ISNULL(m.interbankbank, '') <> ''
      AND e.salarybank = m.interbankbank
      AND sp.status = 'A'
      AND (
            CASE
                WHEN e.status IS NULL THEN 'N'
                WHEN e.status = '' THEN 'N'
                WHEN e.status = 'N' THEN 'N'
                ELSE 'Y'
            END = 'N'
         OR e.ineffectivedate >= GETDATE()
      )
    ORDER BY nombre, dni;
END
GO



-- ============================================================================
-- [40/89] sp_pr_listaprocesscontrol_apertura_web.sql
-- ============================================================================

/*
    Listado de control de procesos para apertura de periodos.
    Usado por: POST /api/aperturar-periodos/listado

    Basado en dw_pr_processcontrol_assign_list (PowerBuilder).
    @cia = Company (código corto, ej. BGT).
    @payrolltype = PayRollType (id planilla, ej. LIMABGT 000000000005).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listaprocesscontrol_apertura_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT
        pc.ProcessType AS processtype,
        pt.description AS description,
        pc.Company AS company,
        pc.PayRollType AS payrolltype,
        LTRIM(RTRIM(ISNULL(pc.PRPeriod, ''))) AS prperiod,
        pc.ProcessDate AS processdate,
        LTRIM(RTRIM(ISNULL(pc.Status, ''))) AS status,
        CASE LTRIM(RTRIM(ISNULL(pc.Status, '')))
            WHEN 'A' THEN 'Abierto'
            WHEN 'G' THEN 'Abierto'
            WHEN 'C' THEN 'Cerrado'
            WHEN 'P' THEN 'Pendiente'
            ELSE ''
        END AS statusdesc,
        'N' AS flag
    FROM PR_ProcessControl pc WITH (NOLOCK)
    INNER JOIN PR_PayRollTypeProcess ptp WITH (NOLOCK)
        ON pc.ProcessType = ptp.ProcessType
       AND pc.Company = ptp.Company
       AND pc.PayRollType = ptp.PayRollType
    INNER JOIN PR_ProcessType pt WITH (NOLOCK)
        ON pc.ProcessType = pt.ProcessType
    WHERE pc.Company = @cia
      AND pc.PayRollType = @payrolltype
      AND pc.Status IN ('A', 'G')

    UNION ALL

    SELECT
        ptp.ProcessType AS processtype,
        pt.description AS description,
        ptp.Company AS company,
        ptp.PayRollType AS payrolltype,
        '' AS prperiod,
        NULL AS processdate,
        '' AS status,
        'Sin control' AS statusdesc,
        'N' AS flag
    FROM PR_PayRollTypeProcess ptp WITH (NOLOCK)
    INNER JOIN PR_ProcessType pt WITH (NOLOCK)
        ON ptp.ProcessType = pt.ProcessType
    WHERE ptp.Company = @cia
      AND ptp.PayRollType = @payrolltype
      AND ptp.ProcessType NOT IN (
            SELECT pc2.ProcessType
            FROM PR_ProcessControl pc2 WITH (NOLOCK)
            WHERE pc2.Company = @cia
              AND pc2.PayRollType = @payrolltype
              AND pc2.Status IN ('A', 'G')
      )

    ORDER BY description;
END
GO



-- ============================================================================
-- [41/89] sp_pr_listarconceptos_web.sql
-- ============================================================================

/*
    Listado de conceptos de planilla por compañía (maestro Conceptos).
    Usado por: POST /api/conceptos/listado

    Filtros: @company (obligatorio), @descripcion (opcional, parcial).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listarconceptos_web]
    @company     VARCHAR(4),
    @descripcion VARCHAR(50) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @descripcion = NULLIF(LTRIM(RTRIM(ISNULL(@descripcion, ''))), '');

    SELECT
        C.Concept AS concept,
        C.Description AS description,
        ISNULL(C.pdt, '') AS pdt,
        ISNULL(T.ShortName, '') AS tiposhortname,
        ISNULL(T.Description, '') AS tipodescription,
        C.FormulaCode AS formulacode,
        ISNULL(C.reporden, 0) AS reporden,
        C.XLastDate AS xlastdate,
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeeConcept EC (NOLOCK)
                WHERE EC.Company = C.Company
                  AND EC.Concept = C.Concept
            ) THEN 'N'
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept EPC (NOLOCK)
                WHERE EPC.Company = C.Company
                  AND EPC.Concept = C.Concept
            ) THEN 'N'
            WHEN EXISTS (
                SELECT 1
                FROM PR_EmployeePayRollConcept P (NOLOCK)
                    INNER JOIN PR_EmployeeAFP A (NOLOCK)
                        ON A.Company = P.Company
                       AND A.Person = P.Person
                       AND A.PayRollType = P.PayRollType
                       AND LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), P.PRPeriod))), 6)
                         = LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), A.PRPeriod))), 6)
                WHERE P.Company = C.Company
                  AND P.Concept = C.Concept
            ) THEN 'N'
            ELSE 'Y'
        END AS puede_eliminar
    FROM PR_Concept C (NOLOCK)
        LEFT JOIN PR_ConceptType T (NOLOCK)
            ON C.ConceptType = T.ConceptType
    WHERE C.Company = @company
      AND (
            @descripcion IS NULL
         OR C.Description LIKE '%' + @descripcion + '%'
         OR C.FormulaCode LIKE '%' + @descripcion + '%'
         OR C.PrintText LIKE '%' + @descripcion + '%'
      )
    ORDER BY
        C.Description ASC,
        C.FormulaCode ASC;
END
GO



-- ============================================================================
-- [42/89] sp_pr_listatelecredito_web.sql
-- ============================================================================

/*
    Listado de trabajadores elegibles para generar archivo Telecrédito BCP.
    Combina importes de PR_EmployeePayRollConcept con datos del empleado
    (cuenta en banco de crédito configurado en pr_mapping.creditobank).

    @cesados: T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listatelecredito_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @par_paydate     DATETIME = NULL,
    @cesados         CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF @par_paydate IS NULL SET @par_paydate = GETDATE();
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';

    DECLARE @flag_set_period CHAR(1);
    SELECT @flag_set_period = ISNULL(FlagSetPeriod, 'N')
    FROM pr_mapping
    WHERE company = @par_company;

    ;WITH Pagos AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM pr_employeepayrollconcept epc
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND (
                (@flag_set_period = 'N' AND epc.prperiod = @par_period)
             OR (@flag_set_period = 'Y' AND epc.prperiod = @par_period)
          )
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) > 0
    )
    SELECT
        e.person,
        LTRIM(RTRIM(
            CASE
                WHEN ISNULL(sp.DocumentNumber, '') = '' THEN ISNULL(sp.Ruc, '')
                ELSE sp.DocumentNumber
            END
        )) AS dni,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        p.importe,
        t.pdt AS tipodoc
    FROM PR_Employee e
        INNER JOIN SY_Person sp
            ON sp.person = e.person
        INNER JOIN pr_mapping m
            ON m.company = e.company
        INNER JOIN Pagos p
            ON p.person = e.person
        LEFT JOIN SY_PersonDocumentType t
            ON sp.EmployeeDocumentType = t.PersonDocumentType
    WHERE e.company = @par_company
      AND e.payrolltype = @par_payrolltype
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
      AND ISNULL(e.salaryaccount, '') <> ''
      AND ISNULL(m.creditobank, '') <> ''
      AND e.salarybank = m.creditobank
      AND sp.status = 'A'
      AND (
            CASE
                WHEN e.status IS NULL THEN 'N'
                WHEN e.status = '' THEN 'N'
                WHEN e.status = 'N' THEN 'N'
                ELSE 'Y'
            END = 'N'
         OR e.ineffectivedate >= GETDATE()
      )
    ORDER BY nombre, dni;
END
GO



-- ============================================================================
-- [43/89] sp_pr_listatrabajadores_web.sql
-- ============================================================================

/*
    Listado de trabajadores para el módulo web de Planillas.
    Filtros: compañía (obligatorio), tipo planilla, trabajador (person), DNI, nombre,
    estado, banco haberes, cesados y fecha de ingreso (rango opcional).
    Parámetros opcionales con valor '0' o vacío = sin filtro (excepto estado: A = Activos por defecto).
    @cesados: T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.
    @fecha_ingreso_all: Y = todas las fechas, N = filtrar por rango.
    Fecha de ingreso efectiva: ISNULL(ReEntryDate, EntryDate).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listatrabajadores_web]
    @cia                  VARCHAR(4),
    @payrolltype          VARCHAR(20),
    @person               VARCHAR(20),
    @docnro               VARCHAR(20),
    @nombre               VARCHAR(100),
    @estado               VARCHAR(1),
    @salarybank           VARCHAR(20),
    @cesados              CHAR(1),
    @fecha_ingreso_all    CHAR(1)      = 'Y',
    @fecha_ingreso_desde  VARCHAR(10)  = '',
    @fecha_ingreso_hasta  VARCHAR(10)  = ''
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @fd DATE = NULL;
    DECLARE @fh DATE = NULL;

    IF RTRIM(ISNULL(@payrolltype, '')) = '' SET @payrolltype = '0';
    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF @docnro IS NULL SET @docnro = '';
    IF @nombre IS NULL SET @nombre = '';
    SET @nombre = LTRIM(RTRIM(@nombre));
    IF RTRIM(ISNULL(@estado, '')) = '' SET @estado = 'A';
    IF RTRIM(ISNULL(@salarybank, '')) = '' SET @salarybank = '0';
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    SET @fecha_ingreso_all = UPPER(LTRIM(RTRIM(ISNULL(@fecha_ingreso_all, 'Y'))));
    IF @fecha_ingreso_all NOT IN ('Y', 'N') SET @fecha_ingreso_all = 'Y';
    SET @fecha_ingreso_desde = LTRIM(RTRIM(ISNULL(@fecha_ingreso_desde, '')));
    SET @fecha_ingreso_hasta = LTRIM(RTRIM(ISNULL(@fecha_ingreso_hasta, '')));

    IF @fecha_ingreso_desde <> ''
        SET @fd = TRY_CONVERT(DATE, @fecha_ingreso_desde, 23);
    IF @fecha_ingreso_hasta <> ''
        SET @fh = TRY_CONVERT(DATE, @fecha_ingreso_hasta, 23);

    SELECT
        PR_PAYROLLTYPE.DESCRIPTION AS tipoplanilla,
        PR_EMPLOYEE.EMPLOYEECODE AS codigo,
        PR_EMPLOYEE.PERSON AS person,
        LTRIM(RTRIM(
            ISNULL(SY_PERSON_A.LASTNAME1, '') + ' ' +
            ISNULL(SY_PERSON_A.LASTNAME2, '') + ' ' +
            ISNULL(SY_PERSON_A.NAME1, '') + ' ' +
            ISNULL(SY_PERSON_A.NAME2, '')
        )) AS nombre,
        CASE PR_EMPLOYEE.STATUS
            WHEN 'N' THEN 'Activo'
            ELSE 'Inactivo'
        END AS estado,
        SY_PERSONDOCUMENTTYPE.DESCRIPTION AS tipodocumento,
        SY_PERSON_A.DOCUMENTNUMBER AS numerodocumento,
        ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS fechaingreso,
        PR_EMPLOYEE.CEASEDATE AS fechacese,
        PR_POSITION.DESCRIPTION AS cargo,
        ISNULL(AC_COSTCENTER.NAME, PR_EMPLOYEE.COSTCENTERNAME) AS centrocosto,
        SY_PERSON_A.TELEPHONE AS telefono,
        SY_PERSON_A.EMAIL AS email,
        PR_EMPLOYEETYPE.DESCRIPTION AS tipotrabajador,
        PR_EMPLOYEECATEGORY.DESCRIPTION AS categoria
    FROM PR_EMPLOYEE
        INNER JOIN SY_PERSON SY_PERSON_A
            ON PR_EMPLOYEE.PERSON = SY_PERSON_A.PERSON
        LEFT JOIN PR_PAYROLLTYPE
            ON PR_EMPLOYEE.PAYROLLTYPE = PR_PAYROLLTYPE.PAYROLLTYPE
        LEFT JOIN SY_PERSONDOCUMENTTYPE
            ON SY_PERSON_A.EMPLOYEEDOCUMENTTYPE = SY_PERSONDOCUMENTTYPE.PERSONDOCUMENTTYPE
        LEFT JOIN PR_POSITION
            ON PR_EMPLOYEE.POSITION = PR_POSITION.POSITION
        LEFT JOIN AC_COSTCENTER
            ON PR_EMPLOYEE.COSTCENTER = AC_COSTCENTER.COSTCENTER
        LEFT JOIN PR_EMPLOYEETYPE
            ON PR_EMPLOYEE.EMPLOYEETYPE = PR_EMPLOYEETYPE.EMPLOYEETYPE
        LEFT JOIN PR_EMPLOYEECATEGORY
            ON PR_EMPLOYEE.EMPLOYEECATEGORY = PR_EMPLOYEECATEGORY.EMPLOYEECATEGORY
    WHERE PR_EMPLOYEE.COMPANY = @cia
      --AND ISNULL(PR_EMPLOYEE.REGISTER, 'Y') = 'Y'
      AND (@payrolltype = '0' OR PR_EMPLOYEE.PAYROLLTYPE = @payrolltype)
      AND (@person = '0' OR PR_EMPLOYEE.PERSON = @person)
      AND (@docnro = '' OR SY_PERSON_A.DOCUMENTNUMBER LIKE '%' + @docnro + '%')
      AND (
            @nombre = ''
         OR LTRIM(RTRIM(
                ISNULL(SY_PERSON_A.LASTNAME1, '') + ' ' +
                ISNULL(SY_PERSON_A.LASTNAME2, '') + ' ' +
                ISNULL(SY_PERSON_A.NAME1, '') + ' ' +
                ISNULL(SY_PERSON_A.NAME2, '')
            )) LIKE '%' + @nombre + '%'
      )
      AND (@salarybank = '0' OR PR_EMPLOYEE.SalaryBank = @salarybank)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND PR_EMPLOYEE.CEASEDATE IS NOT NULL)
         OR (@cesados = 'N' AND PR_EMPLOYEE.CEASEDATE IS NULL)
      )
      AND (
          @estado = 'T'
          OR (@estado = 'A' AND PR_EMPLOYEE.STATUS = 'N')
          OR (@estado = 'I' AND ISNULL(PR_EMPLOYEE.STATUS, '') <> 'N')
      )
      AND (
            @fecha_ingreso_all = 'Y'
         OR (
                ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) IS NOT NULL
            AND (@fd IS NULL
                 OR CAST(ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS DATE) >= @fd)
            AND (@fh IS NULL
                 OR CAST(ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS DATE) <= @fh)
            )
      )
    ORDER BY nombre, codigo;
END
GO



-- ============================================================================
-- [44/89] sp_pr_obtener_bancario_trabajador_web.sql
-- ============================================================================

/*
    Datos bancarios de un trabajador para edición web.
    Clave: person + company (@cia).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtener_bancario_trabajador_web]
    @cia    VARCHAR(10),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.person,
        e.company,
        e.employeecode,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        ISNULL(sp.documentnumber, '') AS numerodocumento,
        ISNULL(sc.description, '') AS company_desc,
        ISNULL(e.collectionform, '') AS collectionform,
        ISNULL(cf.description, '') AS collectionform_desc,
        ISNULL(e.salarybank, '') AS salarybank,
        ISNULL(eb.name, '') AS salarybank_desc,
        ISNULL(e.salaryaccounttype, '') AS salaryaccounttype,
        ISNULL(tat.description, '') AS salaryaccounttype_desc,
        ISNULL(e.salaryaccount, '') AS salaryaccount,
        ISNULL(e.socialassistancenumber, '') AS cci,
        ISNULL(e.ctsbank, '') AS ctsbank,
        ISNULL(cb.name, '') AS ctsbank_desc,
        ISNULL(e.ctsaccount, '') AS ctsaccount,
        ISNULL(e.ctscurrency, 'LO') AS ctscurrency
    FROM pr_employee e
        INNER JOIN sy_person sp
            ON sp.person = e.person
        LEFT JOIN sy_company sc
            ON sc.company = e.company
        LEFT JOIN te_collectionform cf
            ON cf.collectionform = e.collectionform
        LEFT JOIN erp_bank eb
            ON eb.bank = e.salarybank
           AND eb.company = e.company
        LEFT JOIN te_accounttype tat
            ON tat.accounttype = e.salaryaccounttype
        LEFT JOIN erp_bank cb
            ON cb.bank = e.ctsbank
           AND cb.company = e.company
    WHERE e.company = @cia
      AND e.person = @person;
END
GO



-- ============================================================================
-- [45/89] sp_pr_obtener_pensiones_trabajador_web.sql
-- ============================================================================

/*
    Datos de pensiones de un trabajador para edición web.
    Clave: person + company (@cia).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtener_pensiones_trabajador_web]
    @cia    VARCHAR(10),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        e.person,
        e.company,
        e.employeecode,
        LTRIM(RTRIM(
            ISNULL(sp.lastname1, '') + ' ' +
            ISNULL(sp.lastname2, '') + ' ' +
            ISNULL(sp.name1, '') + ' ' +
            ISNULL(sp.name2, '')
        )) AS nombre,
        ISNULL(sp.documentnumber, '') AS numerodocumento,
        ISNULL(sc.description, '') AS company_desc,
        ISNULL(e.pensiontype, '') AS pensiontype,
        ISNULL(pt.description, '') AS pensiontype_desc,
        CASE
            WHEN e.pensioninscriptiondate IS NULL THEN ''
            ELSE CONVERT(VARCHAR(10), e.pensioninscriptiondate, 23)
        END AS pensioninscriptiondate,
        ISNULL(e.regimehealth, '') AS regimehealth,
        ISNULL(rh.description, '') AS regimehealth_desc,
        CASE WHEN LTRIM(RTRIM(ISNULL(e.flagmixta, 'N'))) = 'Y' THEN 'Y' ELSE 'N' END AS flagmixta,
        CASE WHEN LTRIM(RTRIM(ISNULL(e.flagasigfamiliar, 'N'))) = 'Y' THEN 'Y' ELSE 'N' END AS flagasigfamiliar,
        LTRIM(RTRIM(ISNULL(e.afpcard, ''))) AS cuspp
    FROM pr_employee e
        INNER JOIN sy_person sp
            ON sp.person = e.person
        LEFT JOIN sy_company sc
            ON sc.company = e.company
        LEFT JOIN pr_pensiontype pt
            ON pt.pensiontype = e.pensiontype
           AND (LTRIM(RTRIM(ISNULL(pt.company, ''))) = '' OR pt.company = e.company)
        LEFT JOIN pr_regimehealth rh
            ON rh.regimehealth = e.regimehealth
           AND (LTRIM(RTRIM(ISNULL(rh.company, ''))) = '' OR rh.company = e.company)
    WHERE e.company = @cia
      AND e.person = @person;
END
GO



-- ============================================================================
-- [46/89] sp_pr_obtenerasignacionconcepto_web.sql
-- ============================================================================

/*
    Detalle de una asignación de concepto (edición).
    Clave: person, company, concept, payrolltype, prperiodstart, costcenter.
    Usado por: POST /api/asignacion-conceptos/detalle
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerasignacionconcepto_web]
    @par_company         VARCHAR(10),
    @par_person          VARCHAR(20),
    @par_concept         VARCHAR(20),
    @par_payrolltype     VARCHAR(20),
    @par_prperiodstart   VARCHAR(10),
    @par_costcenter      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ec.Person AS person,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS nombre,
        ISNULL(e.EmployeeCode, ec.Person) AS employeecode,
        ec.Company AS company,
        ec.Concept AS concept,
        (
            SELECT TOP 1 c.Description
            FROM PR_Concept c
            WHERE c.Company = ec.Company
              AND c.Concept = ec.Concept
        ) AS conceptname,
        ec.PayRollType AS payrolltype,
        ec.PRPeriodStart AS prperiodstart,
        ec.PRPeriodEnd AS prperiodend,
        ec.ConceptValue AS conceptvalue,
        ec.ConceptCurrency AS conceptcurrency,
        ec.FlagApplyFormula AS flagapplyformula,
        ec.FlagFrecuencyType AS flagfrecuencytype,
        ec.CostCenter AS costcenter,
        ec.CostCenterCode AS costcentercode
    FROM PR_EmployeeConcept ec WITH (NOLOCK)
        INNER JOIN PR_Employee e WITH (NOLOCK)
            ON e.Person = ec.Person
           AND e.Company = ec.Company
        INNER JOIN SY_Person sp WITH (NOLOCK)
            ON sp.Person = e.Person
    WHERE ec.Company = @par_company
      AND ec.Person = @par_person
      AND ec.Concept = @par_concept
      AND ec.PayRollType = @par_payrolltype
      AND ec.PRPeriodStart = @par_prperiodstart
      AND ec.CostCenter = @par_costcenter;
END
GO



-- ============================================================================
-- [47/89] sp_pr_obtenerconcepto_web.sql
-- ============================================================================

/*
    Detalle de un concepto para edición (maestro Conceptos).
    Usado por: POST /api/conceptos/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerconcepto_web]
    @company VARCHAR(4),
    @concept VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @concept = LTRIM(RTRIM(ISNULL(@concept, '')));

    SELECT
        C.Concept AS concept,
        C.Company AS company,
        C.Description AS description,
        C.PrintText AS printtext,
        C.FormulaCode AS formulacode,
        C.ConceptType AS concepttype,
        ISNULL(T.Description, '') AS concepttypename,
        C.ConceptCurrency AS conceptcurrency,
        ISNULL(C.FlagIsMonetary, 'N') AS flagismonetary,
        ISNULL(C.Flagassign, 'N') AS flagassign,
        C.ConceptOrder AS conceptorder,
        ISNULL(C.FlagPayrollTicket, 'N') AS flagpayrollticket,
        C.reporden AS reporden,
        ISNULL(C.flagconceptdeclare, 'N') AS flagconceptdeclare,
        ISNULL(C.pdt, '') AS pdt,
        ISNULL(C.FLAGCONTRACT, 'N') AS flagcontract,
        ISNULL(C.Status, 'A') AS status,
        C.flaginsertar AS flaginsertar,
        ISNULL(C.flagafecto5ta, 'N') AS flagafecto5ta,
        ISNULL(C.flagafectoAFP, 'N') AS flagafectoafp,
        C.XLastUser AS xlastuser,
        C.XLastDate AS xlastdate
    FROM PR_Concept C (NOLOCK)
        LEFT JOIN PR_ConceptType T (NOLOCK)
            ON C.ConceptType = T.ConceptType
    WHERE C.Company = @company
      AND C.Concept = @concept;
END
GO



-- ============================================================================
-- [48/89] sp_pr_plame_sunat_eliminar_carga_web.sql
-- ============================================================================

/*
    Elimina la carga SUNAT existente (cabecera y filas) para reemplazarla.
    Usado por: POST /api/plame/validar/carga antes de insertar nueva carga.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_sunat_eliminar_carga_web]
    @cia VARCHAR(10),
    @period VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    DELETE FROM PR_PlameSunatCarga
    WHERE Company = @cia
      AND Period = @period;
END
GO



-- ============================================================================
-- [49/89] sp_pr_plame_sunat_obtener_carga_web.sql
-- ============================================================================

/*
    Estado de la carga SUNAT (R01/R04/R05) para compañía y periodo tributario.
    Usado por: GET /api/plame/validar/estado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_sunat_obtener_carga_web]
    @cia VARCHAR(10),
    @period VARCHAR(6)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    SELECT
        C.CargaId AS cargaid,
        LTRIM(RTRIM(C.Company)) AS company,
        LTRIM(RTRIM(C.Period)) AS period,
        LTRIM(RTRIM(C.Ruc)) AS ruc,
        LTRIM(RTRIM(ISNULL(C.EmployerName, ''))) AS employername,
        LTRIM(RTRIM(ISNULL(C.PeriodoSunat, ''))) AS periodosunat,
        LTRIM(RTRIM(ISNULL(C.FileR01Name, ''))) AS filer01name,
        LTRIM(RTRIM(ISNULL(C.FileR04Name, ''))) AS filer04name,
        LTRIM(RTRIM(ISNULL(C.FileR05Name, ''))) AS filer05name,
        ISNULL(C.RowsR01, 0) AS rowsr01,
        ISNULL(C.RowsR04, 0) AS rowsr04,
        ISNULL(C.RowsR05, 0) AS rowsr05,
        C.UploadedAt AS uploadedat,
        LTRIM(RTRIM(ISNULL(C.UploadedBy, ''))) AS uploadedby
    FROM PR_PlameSunatCarga C (NOLOCK)
    WHERE C.Company = @cia
      AND C.Period = @period;
END
GO



-- ============================================================================
-- [50/89] sp_pr_plame_validar_archivo14_web.sql
-- ============================================================================

/*
    PLAME Archivo 14 — Validaciones de incidencias (trabajadores y horas trabajadas).

    Usado por: POST /api/plame/archivo-14/listado

    Reglas:
      - Cantidad de trabajadores del Archivo 14 = planilla del periodo (fin / semana).
      - Todo trabajador de planilla debe tener horas trabajadas (conceptos PLAME 14 type WH).

    Parámetros: mismos que sp_pr_listado_plame14_web.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_validar_archivo14_web]
    @cia    VARCHAR(4),
    @period VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    CREATE TABLE #Trab (
        person          VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY,
        documentnumber  VARCHAR(30) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        name            VARCHAR(200) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        workinghours    NUMERIC(19, 4) NOT NULL,
        extrahours      NUMERIC(19, 4) NOT NULL
    );

    CREATE TABLE #msg (
        person  VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        mensaje VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
    );

    /* --- Misma población y cálculo que sp_pr_listado_plame14_web --- */
    INSERT INTO #Trab (person, documentnumber, name, workinghours, extrahours)
    SELECT
        T.person,
        MAX(T.documentnumber) AS documentnumber,
        MAX(T.name) AS name,
        MAX(T.workinghours) AS workinghours,
        MAX(T.extrahours) AS extrahours
    FROM (
        SELECT
            pr_employee.person AS person,
            sy_person.documentnumber AS documentnumber,
            LTRIM(RTRIM(
                ISNULL(sy_person.lastname1, '') + ' ' +
                ISNULL(sy_person.lastname2, '') + ' ' +
                ISNULL(sy_person.name1, '') + ' ' +
                ISNULL(sy_person.name2, '')
            )) AS name,
            ISNULL((
                SELECT SUM(ISNULL(E.ConceptValueLo, E.ConceptValue) * CASE WHEN P.applysum = 'P' THEN 1 ELSE -1 END)
                FROM PR_EmployeePayRollConcept E
                    INNER JOIN PR_Mapping M ON (E.Company = M.Company AND M.Company = @cia)
                    INNER JOIN PR_CompanyPlame P ON (
                        E.Concept = P.concept
                        AND E.Company = @cia
                        AND E.Person = pr_employeepayroll.Person
                        AND E.PRPeriod = pr_employeepayroll.PRPeriod
                        AND E.PayRollType = pr_employeepayroll.PayRollType
                        AND E.ProcessType IN (M.PlanillaProcess, M.PlanillaSemProcess)
                        AND P.plame = '14'
                        AND P.type = 'WH'
                    )
            ), 0) AS workinghours,
            ISNULL((
                SELECT SUM(ISNULL(E.ConceptValueLo, E.ConceptValue) * CASE WHEN P.applysum = 'P' THEN 1 ELSE -1 END)
                FROM PR_EmployeePayRollConcept E
                    INNER JOIN PR_Mapping M ON (E.Company = M.Company AND M.Company = @cia)
                    INNER JOIN PR_CompanyPlame P ON (
                        E.Concept = P.concept
                        AND E.Company = @cia
                        AND E.Person = pr_employeepayroll.Person
                        AND E.PRPeriod = pr_employeepayroll.PRPeriod
                        AND E.PayRollType = pr_employeepayroll.PayRollType
                        AND E.ProcessType IN (M.PlanillaProcess, M.PlanillaSemProcess)
                        AND P.plame = '14'
                        AND P.type = 'HE'
                    )
            ), 0) AS extrahours
        FROM pr_employee (NOLOCK)
            INNER JOIN SY_Company ON (PR_Employee.Company = SY_Company.Company AND pr_employee.company = @cia)
            INNER JOIN sy_person (NOLOCK) ON (sy_person.person = pr_employee.person)
            LEFT JOIN sy_persondocumenttype (NOLOCK) ON (sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype)
            INNER JOIN pr_employeecategory (NOLOCK) ON (pr_employee.employeecategory = pr_employeecategory.employeecategory)
            INNER JOIN pr_mapping (NOLOCK) ON (PR_Employee.Company = PR_Mapping.Company AND pr_mapping.company = @cia)
            INNER JOIN pr_employeepayroll (NOLOCK) ON (
                pr_employeepayroll.PayRollType = pr_employee.PayRollType
                AND pr_employeepayroll.Person = pr_employee.Person
                AND pr_employeepayroll.company = pr_employee.company
                AND pr_employeepayroll.ProcessType IN (pr_mapping.PlanillaProcess, pr_mapping.PlanillaSemProcess)
            )
        WHERE pr_employeecategory.PDT IN ('1')
          AND SUBSTRING(pr_employeepayroll.PRPeriod, 1, 6) = @period
    ) T
    GROUP BY T.person;

    /* --- Horas trabajadas en cero --- */
    INSERT INTO #msg (person, mensaje)
    SELECT
        person,
        'Trabajador sin horas trabajadas: '
        + LTRIM(RTRIM(ISNULL(name, '')))
        + ' (DNI '
        + LTRIM(RTRIM(ISNULL(documentnumber, '')))
        + ')'
    FROM #Trab
    WHERE ISNULL(workinghours, 0) <= 0;

    /* --- Cantidad de trabajadores: Archivo 14 exportable vs planilla --- */
    DECLARE @cnt_planilla INT;
    DECLARE @cnt_archivo14 INT;

    SELECT @cnt_planilla = COUNT(*) FROM #Trab;

    SELECT @cnt_archivo14 = COUNT(*)
    FROM #Trab
    WHERE ISNULL(workinghours, 0) > 0;

    IF @cnt_archivo14 <> @cnt_planilla
    BEGIN
        INSERT INTO #msg (person, mensaje)
        VALUES (
            NULL,
            'Cantidad de trabajadores no coincide: Archivo 14 tiene '
            + CAST(@cnt_archivo14 AS VARCHAR(10))
            + ', planilla tiene '
            + CAST(@cnt_planilla AS VARCHAR(10)) + '.'
        );
    END;

    SELECT person, mensaje
    FROM #msg
    ORDER BY CASE WHEN person IS NULL THEN 0 ELSE 1 END, mensaje;

    DROP TABLE #msg;
    DROP TABLE #Trab;
END
GO



-- ============================================================================
-- [51/89] sp_pr_plame_validar_archivo18_web.sql
-- ============================================================================

/*
    PLAME Archivo 18 — Validaciones de incidencias (código PDT y cantidad de trabajadores).

    Usado por: POST /api/plame/archivo-18/listado

    Reglas:
      - Conceptos I, D y A con movimiento en el periodo deben tener código PDT
        (excepto descuento ONP y aporte ESSALUD).
      - Cantidad de trabajadores distintos del Archivo 18 (#Empleados activos en el periodo)
        = trabajadores distintos en planilla activa del periodo.
      - El filtro de vigencia en el periodo solo aplica a la comparacion; el listado no cambia.

    Parámetros: mismos que sp_pr_listado_plame18_web.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_validar_archivo18_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(20),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL,
    @cesados     CHAR(1)     = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    DECLARE @fecha_inicio_mes DATE;
    DECLARE @fecha_fin_mes DATE;
    DECLARE @period_ym CHAR(6);

    SET @period_ym = LEFT(@period, 6);
    IF LEN(@period_ym) = 6 AND @period_ym NOT LIKE '%[^0-9]%'
    BEGIN
        SET @fecha_inicio_mes = CONVERT(DATE, @period_ym + '01', 112);
        SET @fecha_fin_mes = EOMONTH(@fecha_inicio_mes);
    END;

    CREATE TABLE #Empleados (
        person VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY
    );

    CREATE TABLE #msg (
        person  VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        mensaje VARCHAR(500) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
    );

    /* --- Misma población que sp_pr_listado_plame18_web --- */
    INSERT INTO #Empleados (person)
    SELECT DISTINCT pr_employee.person
    FROM pr_employee (NOLOCK)
        INNER JOIN sy_person (NOLOCK) ON sy_person.person = pr_employee.person
        LEFT JOIN sy_persondocumenttype (NOLOCK)
            ON sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype
        INNER JOIN pr_concept (NOLOCK) ON 1 = 1
        INNER JOIN pr_concepttype (NOLOCK) ON pr_concepttype.concepttype = pr_concept.concepttype
        INNER JOIN pr_employeepayrollconcept (NOLOCK) ON pr_employeepayrollconcept.concept = pr_concept.concept
        INNER JOIN pr_mapping (NOLOCK) ON pr_mapping.company = @cia
        INNER JOIN pr_employeecategory (NOLOCK) ON pr_employee.employeecategory = pr_employeecategory.employeecategory
    WHERE sy_person.person = pr_employee.person
      AND pr_mapping.company = @cia
      AND pr_employee.employeecategory = pr_employeecategory.employeecategory
      AND pr_employeecategory.PDT = '1'
      AND pr_employeepayrollconcept.concept = pr_concept.concept
      AND pr_concepttype.concepttype = pr_concept.concepttype
      AND pr_concepttype.shortname IN ('I', 'A')
      AND (@payroll_all = 'Y' OR pr_employeepayrollconcept.payrolltype = @payroll)
      AND pr_employeepayrollconcept.person = pr_employee.person
      AND pr_employeepayrollconcept.company = pr_employee.company
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND pr_employee.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND pr_employee.CeaseDate IS NULL)
      )
      AND pr_employeepayrollconcept.processtype IN (
            pr_mapping.CTSProcessType,
            pr_mapping.planillaprocess,
            pr_mapping.planillasemprocess,
            pr_mapping.VacationProcess,
            pr_mapping.liquidacionprocess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND LEFT(pr_employeepayrollconcept.prperiod, 6) = @period
      AND pr_employeepayrollconcept.conceptvaluelo IS NOT NULL
      AND pr_concept.flagismonetary = 'Y'
      AND pr_concept.FLAGPAYROLLTICKET = 'Y'
      AND (
            (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') = 0
         OR (
                (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') > 0
                AND ISNULL(sy_person.isrecruiter, 'N') = 'N'
            )
      );

    INSERT INTO #Empleados (person)
    SELECT A.person
    FROM PR_Employee A
        INNER JOIN SY_Person B ON A.Person = B.Person AND A.Status = 'N' AND A.Company = @cia
        LEFT JOIN sy_persondocumenttype S ON B.employeedocumenttype = S.persondocumenttype
        INNER JOIN PR_Mapping M ON A.Company = M.Company
    WHERE NOT EXISTS (
            SELECT 1
            FROM pr_employeepayrollconcept P
                INNER JOIN PR_Concept C ON P.Concept = C.Concept AND C.FormulaCode = 'TOTALINGRESO'
            WHERE P.Company = A.Company
              AND P.Person = A.Person
              AND LEFT(P.PRPeriod, 6) = @period
        )
      AND ISNULL((
            SELECT SUM(X.Days)
            FROM PR_EmployeeMedicalRest X
                INNER JOIN PR_MedicalRestType Y
                    ON X.person = A.person
                   AND X.MedicalRestType = Y.MedicalRestType
                   AND Y.pdt = '05'
                   AND LEFT(X.PRPeriod, 6) = @period
                   AND A.Company = @cia
        ), 0) >= 30
      AND NOT EXISTS (
            SELECT 1
            FROM PR_EmployeePayRoll P
            WHERE P.Person = A.Person
              AND P.Company = A.Company
              AND LEFT(P.PRPeriod, 6) = @period
              AND P.ProcessType = M.CTSProcessType
        )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND A.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND A.CeaseDate IS NULL)
      )
      AND NOT EXISTS (SELECT 1 FROM #Empleados E WHERE E.person = A.person);

    /* --- Conceptos I / D / A sin código PDT (excepto ONP y ESSALUD) --- */
    INSERT INTO #msg (person, mensaje)
    SELECT
        NULL,
        CASE T.ShortName
            WHEN 'I' THEN 'Concepto ingreso sin código PDT: '
            WHEN 'D' THEN 'Concepto descuento sin código PDT: '
            ELSE 'Concepto aporte sin código PDT: '
        END + T.Description
    FROM (
        SELECT DISTINCT CT.ShortName, C.Description
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK) ON EPC.Concept = C.Concept
            INNER JOIN PR_ConceptType CT (NOLOCK) ON C.ConceptType = CT.ConceptType
            INNER JOIN PR_Employee E (NOLOCK)
                ON EPC.Company = E.Company
               AND EPC.Person = E.Person
            INNER JOIN PR_EmployeeCategory EC (NOLOCK) ON E.EmployeeCategory = EC.EmployeeCategory
            INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = EPC.Company
            INNER JOIN SY_Person SP (NOLOCK) ON E.Person = SP.Person
        WHERE EPC.Company = @cia
          AND LEFT(EPC.PRPeriod, 6) = @period
          AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
          AND CT.ShortName IN ('I', 'D', 'A')
          AND C.FlagIsMonetary = 'Y'
          AND EPC.ConceptValueLo IS NOT NULL
          AND ABS(EPC.ConceptValueLo) >= 0.005
          AND ISNULL(LTRIM(RTRIM(C.PDT)), '') = ''
          AND NOT (CT.ShortName = 'D' AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'ONP')
          AND NOT (
                CT.ShortName = 'A'
                AND (
                    UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) LIKE '%ESSALUD%'
                    OR UPPER(C.Description) LIKE '%ESSALUD%'
                )
          )
          AND EC.PDT = '1'
          AND (
                @cesados = 'T'
             OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
             OR (@cesados = 'N' AND E.CeaseDate IS NULL)
          )
          AND (
                (SELECT COUNT(*) FROM SY_Company WHERE Company = @cia AND Description LIKE '%PLANINVES%') = 0
             OR ISNULL(SP.IsRecruiter, 'N') = 'N'
          )
          AND EPC.ProcessType IN (
                M.CTSProcessType,
                M.PlanillaProcess,
                M.PlanillaSemProcess,
                M.VacationProcess,
                M.LiquidacionProcess,
                (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
          )
          AND NOT EXISTS (
                SELECT 1
                FROM PR_ProcessType PT
                WHERE PT.ProcessType = EPC.ProcessType
                  AND PT.Company = @cia
                  AND PT.ShortName = 'QUINCENA'
          )
          AND EPC.ProcessType NOT IN ('LIMABGT 000000000010', 'LIMABGT 000000000011')
    ) T;

    /* --- Cantidad de trabajadores distintos: Archivo 18 vs planilla (activos en el periodo) --- */
    DECLARE @cnt_archivo18 INT;
    DECLARE @cnt_planilla INT;

    SELECT @cnt_archivo18 = COUNT(DISTINCT EM.person)
    FROM #Empleados EM
        INNER JOIN PR_Employee E (NOLOCK) ON E.Company = @cia AND E.Person = EM.person
    WHERE (
            @fecha_fin_mes IS NULL
         OR (
                CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)) <= @fecha_fin_mes
                AND (
                    E.CeaseDate IS NULL
                    OR CONVERT(DATE, E.CeaseDate) >= @fecha_inicio_mes
                )
            )
      );

    SELECT @cnt_planilla = COUNT(DISTINCT EP.Person)
    FROM PR_EmployeePayRoll EP (NOLOCK)
        INNER JOIN PR_Employee E (NOLOCK) ON E.Company = EP.Company AND E.Person = EP.Person
        INNER JOIN PR_EmployeeCategory EC (NOLOCK) ON E.EmployeeCategory = EC.EmployeeCategory
        INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = EP.Company
        INNER JOIN SY_Person SP (NOLOCK) ON E.Person = SP.Person
    WHERE EP.Company = @cia
      AND LEFT(EP.PRPeriod, 6) = @period
      AND EC.PDT = '1'
      AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
      AND EP.ProcessType IN (
            M.CTSProcessType,
            M.PlanillaProcess,
            M.PlanillaSemProcess,
            M.VacationProcess,
            M.LiquidacionProcess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND E.CeaseDate IS NULL)
      )
      AND (
            @fecha_fin_mes IS NULL
         OR (
                CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)) <= @fecha_fin_mes
                AND (
                    E.CeaseDate IS NULL
                    OR CONVERT(DATE, E.CeaseDate) >= @fecha_inicio_mes
                )
            )
      )
      AND (
            (SELECT COUNT(*) FROM SY_Company WHERE Company = @cia AND Description LIKE '%PLANINVES%') = 0
         OR ISNULL(SP.IsRecruiter, 'N') = 'N'
      );

    IF @cnt_archivo18 <> @cnt_planilla
    BEGIN
        INSERT INTO #msg (person, mensaje)
        VALUES (
            NULL,
            'Cantidad de trabajadores no coincide: Archivo 18 tiene '
            + CAST(@cnt_archivo18 AS VARCHAR(10))
            + ', planilla tiene '
            + CAST(@cnt_planilla AS VARCHAR(10)) + '.'
        );

        INSERT INTO #msg (person, mensaje)
        SELECT
            EP.Person,
            'Trabajador en planilla no incluido en Archivo 18: '
            + LTRIM(RTRIM(
                ISNULL(SP.LastName1, '') + ' ' +
                ISNULL(SP.LastName2, '') + ' ' +
                ISNULL(SP.Name1, '') + ' ' +
                ISNULL(SP.Name2, '')
            ))
            + ' (DNI '
            + LTRIM(RTRIM(ISNULL(SP.DocumentNumber, '')))
            + ')'
        FROM PR_EmployeePayRoll EP (NOLOCK)
            INNER JOIN PR_Employee E (NOLOCK) ON E.Company = EP.Company AND E.Person = EP.Person
            INNER JOIN PR_EmployeeCategory EC (NOLOCK) ON E.EmployeeCategory = EC.EmployeeCategory
            INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = EP.Company
            INNER JOIN SY_Person SP (NOLOCK) ON E.Person = SP.Person
        WHERE EP.Company = @cia
          AND LEFT(EP.PRPeriod, 6) = @period
          AND EC.PDT = '1'
          AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
          AND EP.ProcessType IN (
                M.CTSProcessType,
                M.PlanillaProcess,
                M.PlanillaSemProcess,
                M.VacationProcess,
                M.LiquidacionProcess,
                (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
          )
          AND (
                @cesados = 'T'
             OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
             OR (@cesados = 'N' AND E.CeaseDate IS NULL)
          )
          AND (
                @fecha_fin_mes IS NULL
             OR (
                    CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)) <= @fecha_fin_mes
                    AND (
                        E.CeaseDate IS NULL
                        OR CONVERT(DATE, E.CeaseDate) >= @fecha_inicio_mes
                    )
                )
          )
          AND (
                (SELECT COUNT(*) FROM SY_Company WHERE Company = @cia AND Description LIKE '%PLANINVES%') = 0
             OR ISNULL(SP.IsRecruiter, 'N') = 'N'
          )
          AND NOT EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = EP.Person);

        INSERT INTO #msg (person, mensaje)
        SELECT
            EM.person,
            'Trabajador en Archivo 18 no encontrado en planilla del periodo: '
            + LTRIM(RTRIM(
                ISNULL(SP.LastName1, '') + ' ' +
                ISNULL(SP.LastName2, '') + ' ' +
                ISNULL(SP.Name1, '') + ' ' +
                ISNULL(SP.Name2, '')
            ))
            + ' (DNI '
            + LTRIM(RTRIM(ISNULL(SP.DocumentNumber, '')))
            + ')'
        FROM #Empleados EM
            INNER JOIN PR_Employee E (NOLOCK) ON E.Company = @cia AND E.Person = EM.person
            INNER JOIN SY_Person SP (NOLOCK) ON E.Person = SP.Person
        WHERE (
                @fecha_fin_mes IS NULL
             OR (
                    CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)) <= @fecha_fin_mes
                    AND (
                        E.CeaseDate IS NULL
                        OR CONVERT(DATE, E.CeaseDate) >= @fecha_inicio_mes
                    )
                )
          )
          AND NOT EXISTS (
            SELECT 1
            FROM PR_EmployeePayRoll EP (NOLOCK)
                INNER JOIN PR_Employee EP_E (NOLOCK)
                    ON EP_E.Company = EP.Company
                   AND EP_E.Person = EP.Person
                INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = EP.Company
            WHERE EP.Company = @cia
              AND EP.Person = EM.person
              AND LEFT(EP.PRPeriod, 6) = @period
              AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
              AND EP.ProcessType IN (
                    M.CTSProcessType,
                    M.PlanillaProcess,
                    M.PlanillaSemProcess,
                    M.VacationProcess,
                    M.LiquidacionProcess,
                    (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
              )
              AND (
                    @fecha_fin_mes IS NULL
                 OR (
                        CONVERT(DATE, ISNULL(EP_E.ReEntryDate, EP_E.EntryDate)) <= @fecha_fin_mes
                        AND (
                            EP_E.CeaseDate IS NULL
                            OR CONVERT(DATE, EP_E.CeaseDate) >= @fecha_inicio_mes
                        )
                    )
              )
        );
    END;

    SELECT person, mensaje
    FROM #msg
    ORDER BY CASE WHEN person IS NULL THEN 0 ELSE 1 END, mensaje;

    DROP TABLE #msg;
    DROP TABLE #Empleados;
END
GO



-- ============================================================================
-- [52/89] sp_pr_plame_validar_neto_r01_web.sql
-- ============================================================================

/*
    Validación PLAME: Neto a pagar (R01 SUNAT) vs Neto a recibir (planilla, FormulaCode = NETO).

    Usado por: POST /api/plame/validar/neto-r01

    La población de planilla es la misma que Archivo 18 (sp_pr_listado_plame18_web):
      - Todas las planillas (@payroll_all = Y por defecto)
      - Procesos: CTS, fin de mes, semana, vacaciones, liquidación, utilidades
      - Categoría empleado PDT = 1 (+ rama descanso médico legacy)
      - Excluye QUINCENA y procesos LIMABGT 10/11 en el neto
      - Respeta flag PDT por planilla/proceso cuando está configurado
      - En liquidación: FormulaCode LIQ_NETO; en CTS: FormulaCode CTS; resto: NETO
      - Excluye planilla PRACTICANTES (no se declara en PLAME R01/R04/R05)

    Parámetros:
      @cia         — compañía
      @period      — periodo tributario YYYYMM
      @payroll_all — Y = todas las planillas (default, igual Archivo 18)
      @payroll     — tipo de planilla (si @payroll_all = N)
      @cesados     — T/Y/N (default T, igual Archivo 18)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_validar_neto_r01_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(6),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL,
    @cesados     CHAR(1)     = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    DECLARE @cargaid INT;

    SELECT @cargaid = C.CargaId
    FROM PR_PlameSunatCarga C (NOLOCK)
    WHERE C.Company = @cia
      AND C.Period = @period;

    IF @cargaid IS NULL
    BEGIN
        RAISERROR('No hay carga SUNAT para la compañía y periodo indicados.', 16, 1);
        RETURN;
    END

    CREATE TABLE #Empleados (
        person VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY
    );

    /* --- Misma población que Archivo 18 --- */
    INSERT INTO #Empleados (person)
    SELECT DISTINCT pr_employee.person
    FROM pr_employee (NOLOCK)
        INNER JOIN sy_person (NOLOCK) ON sy_person.person = pr_employee.person
        LEFT JOIN sy_persondocumenttype (NOLOCK)
            ON sy_person.employeedocumenttype = sy_persondocumenttype.persondocumenttype
        INNER JOIN pr_concept (NOLOCK) ON 1 = 1
        INNER JOIN pr_concepttype (NOLOCK) ON pr_concepttype.concepttype = pr_concept.concepttype
        INNER JOIN pr_employeepayrollconcept (NOLOCK) ON pr_employeepayrollconcept.concept = pr_concept.concept
        INNER JOIN pr_mapping (NOLOCK) ON pr_mapping.company = @cia
        INNER JOIN pr_employeecategory (NOLOCK) ON pr_employee.employeecategory = pr_employeecategory.employeecategory
    WHERE pr_employee.company = @cia
      AND pr_mapping.company = @cia
      AND pr_employeecategory.PDT = '1'
      AND pr_concepttype.shortname IN ('I', 'A')
      AND (@payroll_all = 'Y' OR pr_employeepayrollconcept.payrolltype = @payroll)
      AND pr_employeepayrollconcept.person = pr_employee.person
      AND pr_employeepayrollconcept.company = pr_employee.company
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND pr_employee.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND pr_employee.CeaseDate IS NULL)
      )
      AND pr_employeepayrollconcept.processtype IN (
            pr_mapping.CTSProcessType,
            pr_mapping.planillaprocess,
            pr_mapping.planillasemprocess,
            pr_mapping.VacationProcess,
            pr_mapping.liquidacionprocess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND LEFT(pr_employeepayrollconcept.prperiod, 6) = @period
      AND pr_employeepayrollconcept.conceptvaluelo IS NOT NULL
      AND pr_concept.flagismonetary = 'Y'
      AND pr_concept.FLAGPAYROLLTICKET = 'Y'
      AND (
            (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') = 0
         OR (
                (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') > 0
                AND ISNULL(sy_person.isrecruiter, 'N') = 'N'
            )
      );

    INSERT INTO #Empleados (person)
    SELECT A.person
    FROM PR_Employee A
        INNER JOIN SY_Person B ON A.Person = B.Person AND A.Status = 'N' AND A.Company = @cia
        INNER JOIN PR_Mapping M ON A.Company = M.Company
    WHERE NOT EXISTS (
            SELECT 1
            FROM pr_employeepayrollconcept P
                INNER JOIN PR_Concept C ON P.Concept = C.Concept AND C.FormulaCode = 'TOTALINGRESO'
            WHERE P.Company = A.Company
              AND P.Person = A.Person
              AND LEFT(P.PRPeriod, 6) = @period
        )
      AND ISNULL((
            SELECT SUM(X.Days)
            FROM PR_EmployeeMedicalRest X
                INNER JOIN PR_MedicalRestType Y
                    ON X.person = A.person
                   AND X.MedicalRestType = Y.MedicalRestType
                   AND Y.pdt = '05'
                   AND LEFT(X.PRPeriod, 6) = @period
                   AND A.Company = @cia
        ), 0) >= 30
      AND NOT EXISTS (
            SELECT 1
            FROM PR_EmployeePayRoll P
            WHERE P.Person = A.Person
              AND P.Company = A.Company
              AND LEFT(P.PRPeriod, 6) = @period
              AND P.ProcessType = M.CTSProcessType
        )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND A.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND A.CeaseDate IS NULL)
      )
      AND NOT EXISTS (SELECT 1 FROM #Empleados E WHERE E.person = A.person);

    /* --- Con neto en planilla (ej. semanal construcción civil) aunque no tenga I/A Archivo 18 --- */
    INSERT INTO #Empleados (person)
    SELECT DISTINCT EPC.Person
    FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK) ON EPC.Concept = C.Concept AND C.Company = @cia
        INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
        INNER JOIN PR_Employee E (NOLOCK) ON EPC.Person = E.Person AND EPC.Company = E.Company
    WHERE EPC.Company = @cia
      AND LEFT(EPC.PRPeriod, 6) = @period
      AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND E.CeaseDate IS NULL)
      )
      AND (
            (
                EPC.ProcessType NOT IN (M.CTSProcessType, M.LiquidacionProcess)
                AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'NETO'
            )
         OR (
                EPC.ProcessType = M.LiquidacionProcess
                AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'LIQ_NETO'
            )
         OR (
                EPC.ProcessType = M.CTSProcessType
                AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'CTS'
            )
      )
      AND EPC.ProcessType IN (
            M.CTSProcessType,
            M.PlanillaProcess,
            M.PlanillaSemProcess,
            M.VacationProcess,
            M.LiquidacionProcess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND NOT EXISTS (
            SELECT 1
            FROM PR_ProcessType PT
            WHERE PT.ProcessType = EPC.ProcessType
              AND PT.Company = @cia
              AND PT.ShortName = 'QUINCENA'
        )
      AND EPC.ProcessType NOT IN ('LIMABGT 000000000010', 'LIMABGT 000000000011')
      AND NOT EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = EPC.Person);

    /* --- Cualquier trabajador con planilla procesada en el periodo (incl. semanal) --- */
    INSERT INTO #Empleados (person)
    SELECT DISTINCT EP.Person
    FROM PR_EmployeePayRoll EP (NOLOCK)
        INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
        INNER JOIN PR_Employee E (NOLOCK) ON EP.Person = E.Person AND EP.Company = E.Company
    WHERE EP.Company = @cia
      AND LEFT(EP.PRPeriod, 6) = @period
      AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND E.CeaseDate IS NULL)
      )
      AND EP.ProcessType IN (
            M.CTSProcessType,
            M.PlanillaProcess,
            M.PlanillaSemProcess,
            M.VacationProcess,
            M.LiquidacionProcess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND NOT EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = EP.Person);

    /* --- Practicantes: no se declaran en PLAME R01/R04/R05 --- */
    DELETE EM
    FROM #Empleados EM
    WHERE EXISTS (
        SELECT 1
        FROM PR_EmployeePayRoll EP (NOLOCK)
            INNER JOIN PR_PayRollType PT (NOLOCK)
                ON PT.PayRollType = EP.PayRollType
               AND PT.Company = @cia
        WHERE EP.Company = @cia
          AND EP.Person = EM.person
          AND LEFT(EP.PRPeriod, 6) = @period
          AND UPPER(LTRIM(RTRIM(ISNULL(PT.ShortName, '')))) = 'PRACTICANTES'
    );

    ;WITH SunatR01 AS (
        SELECT
            LTRIM(RTRIM(ISNULL(F.TipoDoc, ''))) AS tipodoc,
            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) AS documentnumber,
            MAP.Person AS person,
            LTRIM(RTRIM(ISNULL(F.LastName1, ''))) AS lastname1,
            LTRIM(RTRIM(ISNULL(F.LastName2, ''))) AS lastname2,
            LTRIM(RTRIM(ISNULL(F.Names, ''))) AS names,
            TRY_CAST(JSON_VALUE(F.MontosJson, '$."Neto a pagar"') AS DECIMAL(18, 2)) AS neto_sunat
        FROM PR_PlameSunatFila F (NOLOCK)
            OUTER APPLY (
                SELECT TOP 1 E.Person
                FROM PR_Employee E (NOLOCK)
                    INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
                WHERE E.Company = @cia
                  AND EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = E.Person)
                  AND (
                        LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) = LTRIM(RTRIM(ISNULL(P.DocumentNumber, '')))
                     OR (
                            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND ABS(
                                LEN(LTRIM(RTRIM(F.DocumentNumber)))
                                - LEN(LTRIM(RTRIM(P.DocumentNumber)))
                            ) <= 1
                            AND (
                                LTRIM(RTRIM(P.DocumentNumber)) LIKE LTRIM(RTRIM(F.DocumentNumber)) + '%'
                                OR LTRIM(RTRIM(F.DocumentNumber)) LIKE LTRIM(RTRIM(P.DocumentNumber)) + '%'
                            )
                        )
                     OR (
                            UPPER(LTRIM(RTRIM(ISNULL(F.LastName1, '')))) = UPPER(LTRIM(RTRIM(ISNULL(P.LastName1, ''))))
                            AND (
                                ISNULL(NULLIF(LTRIM(RTRIM(F.LastName2)), ''), '') = ''
                                OR UPPER(LTRIM(RTRIM(ISNULL(F.LastName2, '')))) = UPPER(LTRIM(RTRIM(ISNULL(P.LastName2, ''))))
                            )
                            AND UPPER(LTRIM(RTRIM(ISNULL(P.Name1, '')))) = UPPER(LTRIM(LEFT(
                                LTRIM(RTRIM(ISNULL(F.Names, ''))) + ' ',
                                NULLIF(CHARINDEX(' ', LTRIM(RTRIM(ISNULL(F.Names, ''))) + ' '), 0) - 1
                            )))
                            AND LTRIM(RTRIM(ISNULL(F.LastName1, ''))) <> ''
                        )
                  )
                ORDER BY
                    CASE
                        WHEN LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) = LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) THEN 0
                        WHEN (
                            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND ABS(
                                LEN(LTRIM(RTRIM(F.DocumentNumber)))
                                - LEN(LTRIM(RTRIM(P.DocumentNumber)))
                            ) <= 1
                            AND (
                                LTRIM(RTRIM(P.DocumentNumber)) LIKE LTRIM(RTRIM(F.DocumentNumber)) + '%'
                                OR LTRIM(RTRIM(F.DocumentNumber)) LIKE LTRIM(RTRIM(P.DocumentNumber)) + '%'
                            )
                        ) THEN 1
                        ELSE 2
                    END
            ) MAP
        WHERE F.CargaId = @cargaid
          AND F.Archivo = 'R01'
          AND ISNULL(LTRIM(RTRIM(F.DocumentNumber)), '') <> ''
    ),
    PlanillaNeto AS (
        SELECT
            EM.person,
            LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) AS documentnumber,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS nombre,
            ISNULL((
                SELECT SUM(ISNULL(EPC.ConceptValueLo, 0))
                FROM PR_EmployeePayRollConcept EPC (NOLOCK)
                    INNER JOIN PR_Concept C (NOLOCK)
                        ON EPC.Concept = C.Concept
                       AND C.Company = @cia
                    INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
                WHERE EPC.Company = @cia
                  AND EPC.Person = EM.person
                  AND LEFT(EPC.PRPeriod, 6) = @period
                  AND (
                        (
                            EPC.ProcessType NOT IN (M.CTSProcessType, M.LiquidacionProcess)
                            AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'NETO'
                        )
                     OR (
                            EPC.ProcessType = M.LiquidacionProcess
                            AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'LIQ_NETO'
                        )
                     OR (
                            EPC.ProcessType = M.CTSProcessType
                            AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'CTS'
                        )
                  )
                  AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
                  AND EPC.ProcessType IN (
                        M.CTSProcessType,
                        M.PlanillaProcess,
                        M.PlanillaSemProcess,
                        M.VacationProcess,
                        M.LiquidacionProcess,
                        (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
                  )
                  AND NOT EXISTS (
                        SELECT 1
                        FROM PR_ProcessType PT
                        WHERE PT.ProcessType = EPC.ProcessType
                          AND PT.Company = @cia
                          AND PT.ShortName = 'QUINCENA'
                    )
                  AND EPC.ProcessType NOT IN ('LIMABGT 000000000010', 'LIMABGT 000000000011')
                  AND (
                        (SELECT COUNT(*) FROM pr_payrolltypeprocess WHERE company = @cia AND flagpdt = 'Y') = 0
                     OR EXISTS (
                            SELECT 1
                            FROM pr_payrolltypeprocess PTP
                            WHERE PTP.PayRollType = EPC.PayRollType
                              AND PTP.ProcessType = EPC.ProcessType
                              AND PTP.flagpdt = 'Y'
                        )
                    )
            ), 0) AS neto_planilla
        FROM #Empleados EM
            INNER JOIN SY_Person P (NOLOCK) ON EM.person = P.Person
        WHERE ISNULL(LTRIM(RTRIM(P.DocumentNumber)), '') <> ''
    )
    SELECT
        COALESCE(S.tipodoc, '') AS tipodoc,
        COALESCE(NULLIF(P.documentnumber, ''), S.documentnumber) AS documentnumber,
        COALESCE(
            NULLIF(LTRIM(RTRIM(
                COALESCE(S.lastname1, '') + ' ' +
                COALESCE(S.lastname2, '') + ' ' +
                COALESCE(S.names, '')
            )), ''),
            P.nombre
        ) AS nombre,
        ISNULL(S.neto_sunat, 0) AS neto_sunat,
        ISNULL(P.neto_planilla, 0) AS neto_planilla,
        ROUND(ISNULL(S.neto_sunat, 0) - ISNULL(P.neto_planilla, 0), 2) AS diferencia,
        CASE
            WHEN S.documentnumber IS NULL THEN 'SOLO_PLANILLA'
            WHEN P.person IS NULL THEN 'SOLO_SUNAT'
            WHEN ABS(ISNULL(S.neto_sunat, 0) - ISNULL(P.neto_planilla, 0)) < 0.005 THEN 'OK'
            ELSE 'DIFERENCIA'
        END AS estado
    INTO #Comparacion
    FROM SunatR01 S
        FULL OUTER JOIN PlanillaNeto P
            ON S.person IS NOT NULL
           AND P.person IS NOT NULL
           AND S.person = P.person;

    SELECT
        COUNT(*) AS total_filas,
        SUM(CASE WHEN estado = 'OK' THEN 1 ELSE 0 END) AS coinciden,
        SUM(CASE WHEN estado = 'DIFERENCIA' THEN 1 ELSE 0 END) AS con_diferencia,
        SUM(CASE WHEN estado = 'SOLO_SUNAT' THEN 1 ELSE 0 END) AS solo_sunat,
        SUM(CASE WHEN estado = 'SOLO_PLANILLA' THEN 1 ELSE 0 END) AS solo_planilla,
        ROUND(SUM(neto_sunat), 2) AS total_neto_sunat,
        ROUND(SUM(neto_planilla), 2) AS total_neto_planilla,
        ROUND(SUM(neto_sunat) - SUM(neto_planilla), 2) AS total_diferencia
    FROM #Comparacion;

    SELECT
        tipodoc,
        documentnumber,
        nombre,
        neto_sunat,
        neto_planilla,
        diferencia,
        estado
    FROM #Comparacion
    ORDER BY
        CASE estado
            WHEN 'DIFERENCIA' THEN 1
            WHEN 'SOLO_SUNAT' THEN 2
            WHEN 'SOLO_PLANILLA' THEN 3
            ELSE 4
        END,
        nombre,
        documentnumber;

    DROP TABLE #Comparacion;
    DROP TABLE #Empleados;
END
GO



-- ============================================================================
-- [53/89] sp_pr_plame_validar_r04_web.sql
-- ============================================================================

/*
    Validación PLAME R04: tributos del trabajador (AFP aporte/comisión/seguro, ONP, 5ta) vs planilla.

    Usado por: POST /api/plame/validar/r04

    Mapeo R04 SUNAT (MontosJson) → FormulaCode planilla:
      Aporte AFP     → AFP_APORTE_PORC_8      (S.P.P. Aporte Obligatorio)
      Comisión AFP   → AFP_COMISION_VARIABL   (S.P.P. Comisión)
      Seguro AFP     → AFP_SEGUROS            (S.P.P. Seguro)
      ONP            → ONP                    (S.N.P. D.Ley 19990 + Asegura tu pensión)
      5ta categoría  → RET_5TA_CATEGORIA      (Imp. Renta 5ta.categ.)

    Población planilla: misma que Archivo 18 / validación R01.
    Excluye planilla PRACTICANTES (no se declara en PLAME R01/R04/R05).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_validar_r04_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(6),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL,
    @cesados     CHAR(1)     = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    DECLARE @cargaid INT;

    SELECT @cargaid = C.CargaId
    FROM PR_PlameSunatCarga C (NOLOCK)
    WHERE C.Company = @cia
      AND C.Period = @period;

    IF @cargaid IS NULL
    BEGIN
        RAISERROR('No hay carga SUNAT para la compañía y periodo indicados.', 16, 1);
        RETURN;
    END

    CREATE TABLE #Empleados (
        person VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY
    );

    CREATE TABLE #ConceptosMap (
        concepto        VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY,
        concepto_nombre NVARCHAR(80) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        formula_code    VARCHAR(30) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
    );

    INSERT INTO #ConceptosMap (concepto, concepto_nombre, formula_code) VALUES
        ('APORTE',   'Aporte AFP',           'AFP_APORTE_PORC_8'),
        ('COMISION', 'Comisión AFP',         'AFP_COMISION_VARIABL'),
        ('SEGURO',   'Seguro AFP',           'AFP_SEGUROS'),
        ('ONP',      'ONP',                  'ONP'),
        ('5TA',      'Renta 5ta categoría',  'RET_5TA_CATEGORIA');

    /* --- Población planilla (Archivo 18) --- */
    INSERT INTO #Empleados (person)
    SELECT DISTINCT pr_employee.person
    FROM pr_employee (NOLOCK)
        INNER JOIN sy_person (NOLOCK) ON sy_person.person = pr_employee.person
        INNER JOIN pr_concept (NOLOCK) ON 1 = 1
        INNER JOIN pr_concepttype (NOLOCK) ON pr_concepttype.concepttype = pr_concept.concepttype
        INNER JOIN pr_employeepayrollconcept (NOLOCK) ON pr_employeepayrollconcept.concept = pr_concept.concept
        INNER JOIN pr_mapping (NOLOCK) ON pr_mapping.company = @cia
        INNER JOIN pr_employeecategory (NOLOCK) ON pr_employee.employeecategory = pr_employeecategory.employeecategory
    WHERE pr_employee.company = @cia
      AND pr_mapping.company = @cia
      AND pr_employeecategory.PDT = '1'
      AND pr_concepttype.shortname IN ('I', 'A')
      AND (@payroll_all = 'Y' OR pr_employeepayrollconcept.payrolltype = @payroll)
      AND pr_employeepayrollconcept.person = pr_employee.person
      AND pr_employeepayrollconcept.company = pr_employee.company
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND pr_employee.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND pr_employee.CeaseDate IS NULL)
      )
      AND pr_employeepayrollconcept.processtype IN (
            pr_mapping.CTSProcessType,
            pr_mapping.planillaprocess,
            pr_mapping.planillasemprocess,
            pr_mapping.VacationProcess,
            pr_mapping.liquidacionprocess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND LEFT(pr_employeepayrollconcept.prperiod, 6) = @period
      AND pr_employeepayrollconcept.conceptvaluelo IS NOT NULL
      AND pr_concept.flagismonetary = 'Y'
      AND pr_concept.FLAGPAYROLLTICKET = 'Y'
      AND (
            (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') = 0
         OR (
                (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') > 0
                AND ISNULL(sy_person.isrecruiter, 'N') = 'N'
            )
      );

    INSERT INTO #Empleados (person)
    SELECT A.person
    FROM PR_Employee A
        INNER JOIN SY_Person B ON A.Person = B.Person AND A.Status = 'N' AND A.Company = @cia
        INNER JOIN PR_Mapping M ON A.Company = M.Company
    WHERE NOT EXISTS (
            SELECT 1
            FROM pr_employeepayrollconcept P
                INNER JOIN PR_Concept C ON P.Concept = C.Concept AND C.FormulaCode = 'TOTALINGRESO'
            WHERE P.Company = A.Company
              AND P.Person = A.Person
              AND LEFT(P.PRPeriod, 6) = @period
        )
      AND ISNULL((
            SELECT SUM(X.Days)
            FROM PR_EmployeeMedicalRest X
                INNER JOIN PR_MedicalRestType Y
                    ON X.person = A.person
                   AND X.MedicalRestType = Y.MedicalRestType
                   AND Y.pdt = '05'
                   AND LEFT(X.PRPeriod, 6) = @period
                   AND A.Company = @cia
        ), 0) >= 30
      AND NOT EXISTS (
            SELECT 1
            FROM PR_EmployeePayRoll P
            WHERE P.Person = A.Person
              AND P.Company = A.Company
              AND LEFT(P.PRPeriod, 6) = @period
              AND P.ProcessType = M.CTSProcessType
        )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND A.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND A.CeaseDate IS NULL)
      )
      AND NOT EXISTS (SELECT 1 FROM #Empleados E WHERE E.person = A.person);

    /* --- Con tributos en planilla aunque no tenga I/A Archivo 18 --- */
    INSERT INTO #Empleados (person)
    SELECT DISTINCT EPC.Person
    FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK) ON EPC.Concept = C.Concept AND C.Company = @cia
        INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
        INNER JOIN PR_Employee E (NOLOCK) ON EPC.Person = E.Person AND EPC.Company = E.Company
    WHERE EPC.Company = @cia
      AND LEFT(EPC.PRPeriod, 6) = @period
      AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND E.CeaseDate IS NULL)
      )
      AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) IN (
            'AFP_APORTE_PORC_8',
            'AFP_COMISION_VARIABL',
            'AFP_SEGUROS',
            'ONP',
            'RET_5TA_CATEGORIA'
      )
      AND EPC.ProcessType IN (
            M.CTSProcessType,
            M.PlanillaProcess,
            M.PlanillaSemProcess,
            M.VacationProcess,
            M.LiquidacionProcess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND NOT EXISTS (
            SELECT 1
            FROM PR_ProcessType PT
            WHERE PT.ProcessType = EPC.ProcessType
              AND PT.Company = @cia
              AND PT.ShortName = 'QUINCENA'
        )
      AND EPC.ProcessType NOT IN ('LIMABGT 000000000010', 'LIMABGT 000000000011')
      AND NOT EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = EPC.Person);

    INSERT INTO #Empleados (person)
    SELECT DISTINCT EP.Person
    FROM PR_EmployeePayRoll EP (NOLOCK)
        INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
        INNER JOIN PR_Employee E (NOLOCK) ON EP.Person = E.Person AND EP.Company = E.Company
    WHERE EP.Company = @cia
      AND LEFT(EP.PRPeriod, 6) = @period
      AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND E.CeaseDate IS NULL)
      )
      AND EP.ProcessType IN (
            M.CTSProcessType,
            M.PlanillaProcess,
            M.PlanillaSemProcess,
            M.VacationProcess,
            M.LiquidacionProcess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND NOT EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = EP.Person);

    /* --- Practicantes: no se declaran en PLAME R01/R04/R05 --- */
    DELETE EM
    FROM #Empleados EM
    WHERE EXISTS (
        SELECT 1
        FROM PR_EmployeePayRoll EP (NOLOCK)
            INNER JOIN PR_PayRollType PT (NOLOCK)
                ON PT.PayRollType = EP.PayRollType
               AND PT.Company = @cia
        WHERE EP.Company = @cia
          AND EP.Person = EM.person
          AND LEFT(EP.PRPeriod, 6) = @period
          AND UPPER(LTRIM(RTRIM(ISNULL(PT.ShortName, '')))) = 'PRACTICANTES'
    );

    ;WITH SunatR04Base AS (
        SELECT
            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) AS documentnumber,
            MAP.Person AS person,
            LTRIM(RTRIM(
                ISNULL(F.LastName1, '') + ' ' +
                ISNULL(F.LastName2, '') + ' ' +
                ISNULL(F.Names, '')
            )) AS nombre,
            F.MontosJson
        FROM PR_PlameSunatFila F (NOLOCK)
            OUTER APPLY (
                SELECT TOP 1 E.Person
                FROM PR_Employee E (NOLOCK)
                    INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
                WHERE E.Company = @cia
                  AND EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = E.Person)
                  AND (
                        LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) = LTRIM(RTRIM(ISNULL(P.DocumentNumber, '')))
                     OR (
                            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND ABS(
                                LEN(LTRIM(RTRIM(F.DocumentNumber)))
                                - LEN(LTRIM(RTRIM(P.DocumentNumber)))
                            ) <= 1
                            AND (
                                LTRIM(RTRIM(P.DocumentNumber)) LIKE LTRIM(RTRIM(F.DocumentNumber)) + '%'
                                OR LTRIM(RTRIM(F.DocumentNumber)) LIKE LTRIM(RTRIM(P.DocumentNumber)) + '%'
                            )
                        )
                     OR (
                            UPPER(LTRIM(RTRIM(ISNULL(F.LastName1, '')))) = UPPER(LTRIM(RTRIM(ISNULL(P.LastName1, ''))))
                            AND (
                                ISNULL(NULLIF(LTRIM(RTRIM(F.LastName2)), ''), '') = ''
                                OR UPPER(LTRIM(RTRIM(ISNULL(F.LastName2, '')))) = UPPER(LTRIM(RTRIM(ISNULL(P.LastName2, ''))))
                            )
                            AND UPPER(LTRIM(RTRIM(ISNULL(P.Name1, '')))) = UPPER(LTRIM(LEFT(
                                LTRIM(RTRIM(ISNULL(F.Names, ''))) + ' ',
                                NULLIF(CHARINDEX(' ', LTRIM(RTRIM(ISNULL(F.Names, ''))) + ' '), 0) - 1
                            )))
                            AND LTRIM(RTRIM(ISNULL(F.LastName1, ''))) <> ''
                        )
                  )
                ORDER BY
                    CASE
                        WHEN LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) = LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) THEN 0
                        WHEN (
                            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND ABS(
                                LEN(LTRIM(RTRIM(F.DocumentNumber)))
                                - LEN(LTRIM(RTRIM(P.DocumentNumber)))
                            ) <= 1
                            AND (
                                LTRIM(RTRIM(P.DocumentNumber)) LIKE LTRIM(RTRIM(F.DocumentNumber)) + '%'
                                OR LTRIM(RTRIM(F.DocumentNumber)) LIKE LTRIM(RTRIM(P.DocumentNumber)) + '%'
                            )
                        ) THEN 1
                        ELSE 2
                    END
            ) MAP
        WHERE F.CargaId = @cargaid
          AND F.Archivo = 'R04'
          AND ISNULL(LTRIM(RTRIM(F.DocumentNumber)), '') <> ''
    ),
    SunatMontos AS (
        SELECT documentnumber, person, nombre, 'APORTE' AS concepto, 'Aporte AFP' AS concepto_nombre,
            ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."S.P.P. Aporte Obligatorio"') AS DECIMAL(18, 2)), 0) AS monto_sunat
        FROM SunatR04Base
        UNION ALL
        SELECT documentnumber, person, nombre, 'COMISION', 'Comisión AFP',
            ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."S.P.P. Comisión"') AS DECIMAL(18, 2)), 0)
        FROM SunatR04Base
        UNION ALL
        SELECT documentnumber, person, nombre, 'SEGURO', 'Seguro AFP',
            ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."S.P.P. Seguro"') AS DECIMAL(18, 2)), 0)
        FROM SunatR04Base
        UNION ALL
        SELECT documentnumber, person, nombre, 'ONP', 'ONP',
            ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."S.N.P. D.Ley 19990 (ONP)"') AS DECIMAL(18, 2)), 0)
          + ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."S.N.P. Asegura tu pensión (ONP)"') AS DECIMAL(18, 2)), 0)
        FROM SunatR04Base
        UNION ALL
        SELECT documentnumber, person, nombre, '5TA', 'Renta 5ta categoría',
            ISNULL(TRY_CAST(JSON_VALUE(MontosJson, '$."Imp. Renta 5ta.categ."') AS DECIMAL(18, 2)), 0)
        FROM SunatR04Base
    ),
    PlanillaMontos AS (
        SELECT
            EM.person,
            LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) AS documentnumber,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS nombre,
            CM.concepto,
            CM.concepto_nombre,
            ISNULL((
                SELECT SUM(ISNULL(EPC.ConceptValueLo, 0))
                FROM PR_EmployeePayRollConcept EPC (NOLOCK)
                    INNER JOIN PR_Concept C (NOLOCK)
                        ON EPC.Concept = C.Concept
                       AND C.Company = @cia
                    INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
                WHERE EPC.Company = @cia
                  AND EPC.Person = EM.person
                  AND LEFT(EPC.PRPeriod, 6) = @period
                  AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = UPPER(CM.formula_code)
                  AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
                  AND EPC.ProcessType IN (
                        M.CTSProcessType,
                        M.PlanillaProcess,
                        M.PlanillaSemProcess,
                        M.VacationProcess,
                        M.LiquidacionProcess,
                        (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
                  )
                  AND NOT EXISTS (
                        SELECT 1
                        FROM PR_ProcessType PT
                        WHERE PT.ProcessType = EPC.ProcessType
                          AND PT.Company = @cia
                          AND PT.ShortName = 'QUINCENA'
                    )
                  AND EPC.ProcessType NOT IN ('LIMABGT 000000000010', 'LIMABGT 000000000011')
                  AND (
                        (SELECT COUNT(*) FROM pr_payrolltypeprocess WHERE company = @cia AND flagpdt = 'Y') = 0
                     OR EXISTS (
                            SELECT 1
                            FROM pr_payrolltypeprocess PTP
                            WHERE PTP.PayRollType = EPC.PayRollType
                              AND PTP.ProcessType = EPC.ProcessType
                              AND PTP.flagpdt = 'Y'
                        )
                    )
            ), 0) AS monto_planilla
        FROM #Empleados EM
            INNER JOIN SY_Person P (NOLOCK) ON EM.person = P.Person
            CROSS JOIN #ConceptosMap CM
        WHERE ISNULL(LTRIM(RTRIM(P.DocumentNumber)), '') <> ''
    )
    SELECT
        COALESCE(S.concepto, P.concepto) AS concepto,
        COALESCE(S.concepto_nombre, P.concepto_nombre) AS concepto_nombre,
        COALESCE(NULLIF(P.documentnumber, ''), S.documentnumber) AS documentnumber,
        COALESCE(NULLIF(LTRIM(RTRIM(S.nombre)), ''), P.nombre) AS nombre,
        ISNULL(S.monto_sunat, 0) AS monto_sunat,
        ISNULL(P.monto_planilla, 0) AS monto_planilla,
        ROUND(ISNULL(S.monto_sunat, 0) - ISNULL(P.monto_planilla, 0), 2) AS diferencia,
        CASE
            WHEN S.documentnumber IS NULL THEN 'SOLO_PLANILLA'
            WHEN P.person IS NULL THEN 'SOLO_SUNAT'
            WHEN ABS(ISNULL(S.monto_sunat, 0) - ISNULL(P.monto_planilla, 0)) < 0.005 THEN 'OK'
            ELSE 'DIFERENCIA'
        END AS estado
    INTO #Comparacion
    FROM SunatMontos S
        FULL OUTER JOIN PlanillaMontos P
            ON S.person IS NOT NULL
           AND P.person IS NOT NULL
           AND S.person = P.person
           AND S.concepto = P.concepto;

    /* Resumen por concepto */
    SELECT
        concepto,
        concepto_nombre,
        COUNT(*) AS total_filas,
        SUM(CASE WHEN estado = 'OK' THEN 1 ELSE 0 END) AS coinciden,
        SUM(CASE WHEN estado = 'DIFERENCIA' THEN 1 ELSE 0 END) AS con_diferencia,
        SUM(CASE WHEN estado = 'SOLO_SUNAT' THEN 1 ELSE 0 END) AS solo_sunat,
        SUM(CASE WHEN estado = 'SOLO_PLANILLA' THEN 1 ELSE 0 END) AS solo_planilla,
        ROUND(SUM(monto_sunat), 2) AS total_sunat,
        ROUND(SUM(monto_planilla), 2) AS total_planilla,
        ROUND(SUM(monto_sunat) - SUM(monto_planilla), 2) AS total_diferencia
    FROM #Comparacion
    GROUP BY concepto, concepto_nombre
    ORDER BY
        CASE concepto
            WHEN 'APORTE' THEN 1
            WHEN 'COMISION' THEN 2
            WHEN 'SEGURO' THEN 3
            WHEN 'ONP' THEN 4
            WHEN '5TA' THEN 5
            ELSE 9
        END;

    /* Detalle */
    SELECT
        concepto,
        concepto_nombre,
        documentnumber,
        nombre,
        monto_sunat,
        monto_planilla,
        diferencia,
        estado
    FROM #Comparacion
    ORDER BY
        CASE concepto
            WHEN 'APORTE' THEN 1
            WHEN 'COMISION' THEN 2
            WHEN 'SEGURO' THEN 3
            WHEN 'ONP' THEN 4
            WHEN '5TA' THEN 5
            ELSE 9
        END,
        CASE estado
            WHEN 'DIFERENCIA' THEN 1
            WHEN 'SOLO_SUNAT' THEN 2
            WHEN 'SOLO_PLANILLA' THEN 3
            ELSE 4
        END,
        nombre,
        documentnumber;

    DROP TABLE #Comparacion;
    DROP TABLE #ConceptosMap;
    DROP TABLE #Empleados;
END
GO



-- ============================================================================
-- [54/89] sp_pr_plame_validar_r05_web.sql
-- ============================================================================

/*
    Validación PLAME R05: ESSALUD Seguro de Salud (SUNAT) vs planilla (FormulaCode = ESSALUD).

    Usado por: POST /api/plame/validar/r05

    Mapeo R05 SUNAT (MontosJson) → planilla:
      ESSALUD Seguro de Salud → FormulaCode ESSALUD

    Población planilla: misma que Archivo 18 / validación R01.
    Excluye planilla PRACTICANTES (no se declara en PLAME R01/R04/R05).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_plame_validar_r05_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(6),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL,
    @cesados     CHAR(1)     = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    DECLARE @cargaid INT;

    SELECT @cargaid = C.CargaId
    FROM PR_PlameSunatCarga C (NOLOCK)
    WHERE C.Company = @cia
      AND C.Period = @period;

    IF @cargaid IS NULL
    BEGIN
        RAISERROR('No hay carga SUNAT para la compañía y periodo indicados.', 16, 1);
        RETURN;
    END

    CREATE TABLE #Empleados (
        person VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL PRIMARY KEY
    );

    INSERT INTO #Empleados (person)
    SELECT DISTINCT pr_employee.person
    FROM pr_employee (NOLOCK)
        INNER JOIN sy_person (NOLOCK) ON sy_person.person = pr_employee.person
        INNER JOIN pr_concept (NOLOCK) ON 1 = 1
        INNER JOIN pr_concepttype (NOLOCK) ON pr_concepttype.concepttype = pr_concept.concepttype
        INNER JOIN pr_employeepayrollconcept (NOLOCK) ON pr_employeepayrollconcept.concept = pr_concept.concept
        INNER JOIN pr_mapping (NOLOCK) ON pr_mapping.company = @cia
        INNER JOIN pr_employeecategory (NOLOCK) ON pr_employee.employeecategory = pr_employeecategory.employeecategory
    WHERE pr_employee.company = @cia
      AND pr_mapping.company = @cia
      AND pr_employeecategory.PDT = '1'
      AND pr_concepttype.shortname IN ('I', 'A')
      AND (@payroll_all = 'Y' OR pr_employeepayrollconcept.payrolltype = @payroll)
      AND pr_employeepayrollconcept.person = pr_employee.person
      AND pr_employeepayrollconcept.company = pr_employee.company
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND pr_employee.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND pr_employee.CeaseDate IS NULL)
      )
      AND pr_employeepayrollconcept.processtype IN (
            pr_mapping.CTSProcessType,
            pr_mapping.planillaprocess,
            pr_mapping.planillasemprocess,
            pr_mapping.VacationProcess,
            pr_mapping.liquidacionprocess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND LEFT(pr_employeepayrollconcept.prperiod, 6) = @period
      AND pr_employeepayrollconcept.conceptvaluelo IS NOT NULL
      AND pr_concept.flagismonetary = 'Y'
      AND pr_concept.FLAGPAYROLLTICKET = 'Y'
      AND (
            (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') = 0
         OR (
                (SELECT COUNT(*) FROM sy_company WHERE company = @cia AND description LIKE '%PLANINVES%') > 0
                AND ISNULL(sy_person.isrecruiter, 'N') = 'N'
            )
      );

    INSERT INTO #Empleados (person)
    SELECT A.person
    FROM PR_Employee A
        INNER JOIN SY_Person B ON A.Person = B.Person AND A.Status = 'N' AND A.Company = @cia
        INNER JOIN PR_Mapping M ON A.Company = M.Company
    WHERE NOT EXISTS (
            SELECT 1
            FROM pr_employeepayrollconcept P
                INNER JOIN PR_Concept C ON P.Concept = C.Concept AND C.FormulaCode = 'TOTALINGRESO'
            WHERE P.Company = A.Company
              AND P.Person = A.Person
              AND LEFT(P.PRPeriod, 6) = @period
        )
      AND ISNULL((
            SELECT SUM(X.Days)
            FROM PR_EmployeeMedicalRest X
                INNER JOIN PR_MedicalRestType Y
                    ON X.person = A.person
                   AND X.MedicalRestType = Y.MedicalRestType
                   AND Y.pdt = '05'
                   AND LEFT(X.PRPeriod, 6) = @period
                   AND A.Company = @cia
        ), 0) >= 30
      AND NOT EXISTS (
            SELECT 1
            FROM PR_EmployeePayRoll P
            WHERE P.Person = A.Person
              AND P.Company = A.Company
              AND LEFT(P.PRPeriod, 6) = @period
              AND P.ProcessType = M.CTSProcessType
        )
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND A.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND A.CeaseDate IS NULL)
      )
      AND NOT EXISTS (SELECT 1 FROM #Empleados E WHERE E.person = A.person);

    INSERT INTO #Empleados (person)
    SELECT DISTINCT EPC.Person
    FROM PR_EmployeePayRollConcept EPC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK) ON EPC.Concept = C.Concept AND C.Company = @cia
        INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
        INNER JOIN PR_Employee E (NOLOCK) ON EPC.Person = E.Person AND EPC.Company = E.Company
    WHERE EPC.Company = @cia
      AND LEFT(EPC.PRPeriod, 6) = @period
      AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND E.CeaseDate IS NULL)
      )
      AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'ESSALUD'
      AND EPC.ProcessType IN (
            M.CTSProcessType,
            M.PlanillaProcess,
            M.PlanillaSemProcess,
            M.VacationProcess,
            M.LiquidacionProcess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND NOT EXISTS (
            SELECT 1
            FROM PR_ProcessType PT
            WHERE PT.ProcessType = EPC.ProcessType
              AND PT.Company = @cia
              AND PT.ShortName = 'QUINCENA'
        )
      AND EPC.ProcessType NOT IN ('LIMABGT 000000000010', 'LIMABGT 000000000011')
      AND NOT EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = EPC.Person);

    INSERT INTO #Empleados (person)
    SELECT DISTINCT EP.Person
    FROM PR_EmployeePayRoll EP (NOLOCK)
        INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
        INNER JOIN PR_Employee E (NOLOCK) ON EP.Person = E.Person AND EP.Company = E.Company
    WHERE EP.Company = @cia
      AND LEFT(EP.PRPeriod, 6) = @period
      AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND E.CeaseDate IS NULL)
      )
      AND EP.ProcessType IN (
            M.CTSProcessType,
            M.PlanillaProcess,
            M.PlanillaSemProcess,
            M.VacationProcess,
            M.LiquidacionProcess,
            (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
      )
      AND NOT EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = EP.Person);

    DELETE EM
    FROM #Empleados EM
    WHERE EXISTS (
        SELECT 1
        FROM PR_EmployeePayRoll EP (NOLOCK)
            INNER JOIN PR_PayRollType PT (NOLOCK)
                ON PT.PayRollType = EP.PayRollType
               AND PT.Company = @cia
        WHERE EP.Company = @cia
          AND EP.Person = EM.person
          AND LEFT(EP.PRPeriod, 6) = @period
          AND UPPER(LTRIM(RTRIM(ISNULL(PT.ShortName, '')))) = 'PRACTICANTES'
    );

    ;WITH SunatR05 AS (
        SELECT
            LTRIM(RTRIM(ISNULL(F.TipoDoc, ''))) AS tipodoc,
            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) AS documentnumber,
            MAP.Person AS person,
            LTRIM(RTRIM(ISNULL(F.LastName1, ''))) AS lastname1,
            LTRIM(RTRIM(ISNULL(F.LastName2, ''))) AS lastname2,
            LTRIM(RTRIM(ISNULL(F.Names, ''))) AS names,
            ISNULL(TRY_CAST(JSON_VALUE(F.MontosJson, '$."ESSALUD Seguro de Salud"') AS DECIMAL(18, 2)), 0) AS essalud_sunat
        FROM PR_PlameSunatFila F (NOLOCK)
            OUTER APPLY (
                SELECT TOP 1 E.Person
                FROM PR_Employee E (NOLOCK)
                    INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
                WHERE E.Company = @cia
                  AND EXISTS (SELECT 1 FROM #Empleados EM WHERE EM.person = E.Person)
                  AND (
                        LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) = LTRIM(RTRIM(ISNULL(P.DocumentNumber, '')))
                     OR (
                            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND ABS(
                                LEN(LTRIM(RTRIM(F.DocumentNumber)))
                                - LEN(LTRIM(RTRIM(P.DocumentNumber)))
                            ) <= 1
                            AND (
                                LTRIM(RTRIM(P.DocumentNumber)) LIKE LTRIM(RTRIM(F.DocumentNumber)) + '%'
                                OR LTRIM(RTRIM(F.DocumentNumber)) LIKE LTRIM(RTRIM(P.DocumentNumber)) + '%'
                            )
                        )
                     OR (
                            UPPER(LTRIM(RTRIM(ISNULL(F.LastName1, '')))) = UPPER(LTRIM(RTRIM(ISNULL(P.LastName1, ''))))
                            AND (
                                ISNULL(NULLIF(LTRIM(RTRIM(F.LastName2)), ''), '') = ''
                                OR UPPER(LTRIM(RTRIM(ISNULL(F.LastName2, '')))) = UPPER(LTRIM(RTRIM(ISNULL(P.LastName2, ''))))
                            )
                            AND UPPER(LTRIM(RTRIM(ISNULL(P.Name1, '')))) = UPPER(LTRIM(LEFT(
                                LTRIM(RTRIM(ISNULL(F.Names, ''))) + ' ',
                                NULLIF(CHARINDEX(' ', LTRIM(RTRIM(ISNULL(F.Names, ''))) + ' '), 0) - 1
                            )))
                            AND LTRIM(RTRIM(ISNULL(F.LastName1, ''))) <> ''
                        )
                  )
                ORDER BY
                    CASE
                        WHEN LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) = LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) THEN 0
                        WHEN (
                            LTRIM(RTRIM(ISNULL(F.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) NOT LIKE '%[^0-9]%'
                            AND ABS(
                                LEN(LTRIM(RTRIM(F.DocumentNumber)))
                                - LEN(LTRIM(RTRIM(P.DocumentNumber)))
                            ) <= 1
                            AND (
                                LTRIM(RTRIM(P.DocumentNumber)) LIKE LTRIM(RTRIM(F.DocumentNumber)) + '%'
                                OR LTRIM(RTRIM(F.DocumentNumber)) LIKE LTRIM(RTRIM(P.DocumentNumber)) + '%'
                            )
                        ) THEN 1
                        ELSE 2
                    END
            ) MAP
        WHERE F.CargaId = @cargaid
          AND F.Archivo = 'R05'
          AND ISNULL(LTRIM(RTRIM(F.DocumentNumber)), '') <> ''
    ),
    PlanillaEssalud AS (
        SELECT
            EM.person,
            LTRIM(RTRIM(ISNULL(P.DocumentNumber, ''))) AS documentnumber,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS nombre,
            ISNULL((
                SELECT SUM(ISNULL(EPC.ConceptValueLo, 0))
                FROM PR_EmployeePayRollConcept EPC (NOLOCK)
                    INNER JOIN PR_Concept C (NOLOCK)
                        ON EPC.Concept = C.Concept
                       AND C.Company = @cia
                    INNER JOIN PR_Mapping M (NOLOCK) ON M.Company = @cia
                WHERE EPC.Company = @cia
                  AND EPC.Person = EM.person
                  AND LEFT(EPC.PRPeriod, 6) = @period
                  AND UPPER(LTRIM(RTRIM(ISNULL(C.FormulaCode, '')))) = 'ESSALUD'
                  AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
                  AND EPC.ProcessType IN (
                        M.CTSProcessType,
                        M.PlanillaProcess,
                        M.PlanillaSemProcess,
                        M.VacationProcess,
                        M.LiquidacionProcess,
                        (SELECT TOP 1 ProcessType FROM PR_ProcessType WHERE ShortName = 'UTILIDADES' AND Company = @cia)
                  )
                  AND NOT EXISTS (
                        SELECT 1
                        FROM PR_ProcessType PT
                        WHERE PT.ProcessType = EPC.ProcessType
                          AND PT.Company = @cia
                          AND PT.ShortName = 'QUINCENA'
                    )
                  AND EPC.ProcessType NOT IN ('LIMABGT 000000000010', 'LIMABGT 000000000011')
                  AND (
                        (SELECT COUNT(*) FROM pr_payrolltypeprocess WHERE company = @cia AND flagpdt = 'Y') = 0
                     OR EXISTS (
                            SELECT 1
                            FROM pr_payrolltypeprocess PTP
                            WHERE PTP.PayRollType = EPC.PayRollType
                              AND PTP.ProcessType = EPC.ProcessType
                              AND PTP.flagpdt = 'Y'
                        )
                    )
            ), 0) AS essalud_planilla
        FROM #Empleados EM
            INNER JOIN SY_Person P (NOLOCK) ON EM.person = P.Person
        WHERE ISNULL(LTRIM(RTRIM(P.DocumentNumber)), '') <> ''
    )
    SELECT
        COALESCE(S.tipodoc, '') AS tipodoc,
        COALESCE(NULLIF(P.documentnumber, ''), S.documentnumber) AS documentnumber,
        COALESCE(
            NULLIF(LTRIM(RTRIM(
                COALESCE(S.lastname1, '') + ' ' +
                COALESCE(S.lastname2, '') + ' ' +
                COALESCE(S.names, '')
            )), ''),
            P.nombre
        ) AS nombre,
        ISNULL(S.essalud_sunat, 0) AS essalud_sunat,
        ISNULL(P.essalud_planilla, 0) AS essalud_planilla,
        ROUND(ISNULL(S.essalud_sunat, 0) - ISNULL(P.essalud_planilla, 0), 2) AS diferencia,
        CASE
            WHEN S.documentnumber IS NULL THEN 'SOLO_PLANILLA'
            WHEN P.person IS NULL THEN 'SOLO_SUNAT'
            WHEN ABS(ISNULL(S.essalud_sunat, 0) - ISNULL(P.essalud_planilla, 0)) < 0.005 THEN 'OK'
            ELSE 'DIFERENCIA'
        END AS estado
    INTO #Comparacion
    FROM SunatR05 S
        FULL OUTER JOIN PlanillaEssalud P
            ON S.person IS NOT NULL
           AND P.person IS NOT NULL
           AND S.person = P.person;

    SELECT
        COUNT(*) AS total_filas,
        SUM(CASE WHEN estado = 'OK' THEN 1 ELSE 0 END) AS coinciden,
        SUM(CASE WHEN estado = 'DIFERENCIA' THEN 1 ELSE 0 END) AS con_diferencia,
        SUM(CASE WHEN estado = 'SOLO_SUNAT' THEN 1 ELSE 0 END) AS solo_sunat,
        SUM(CASE WHEN estado = 'SOLO_PLANILLA' THEN 1 ELSE 0 END) AS solo_planilla,
        ROUND(SUM(essalud_sunat), 2) AS total_essalud_sunat,
        ROUND(SUM(essalud_planilla), 2) AS total_essalud_planilla,
        ROUND(SUM(essalud_sunat) - SUM(essalud_planilla), 2) AS total_diferencia
    FROM #Comparacion;

    SELECT
        tipodoc,
        documentnumber,
        nombre,
        essalud_sunat,
        essalud_planilla,
        diferencia,
        estado
    FROM #Comparacion
    ORDER BY
        CASE estado
            WHEN 'DIFERENCIA' THEN 1
            WHEN 'SOLO_SUNAT' THEN 2
            WHEN 'SOLO_PLANILLA' THEN 3
            ELSE 4
        END,
        nombre,
        documentnumber;

    DROP TABLE #Comparacion;
    DROP TABLE #Empleados;
END
GO



-- ============================================================================
-- [55/89] sp_pr_r019_vacationdetail_web.sql
-- ============================================================================

/*
    Detalle de vacaciones por trabajador (reporte R019).
    Usado por: POST /reporte_vacaciones_detalle (reporte_vacaciones_detalle.html).

    Parámetros:
      @cia, @payrolltype — obligatorios.
      @period — '0' = todos los periodos; otro valor filtra por YYYYMM (primeros 6 caracteres).
      @person — '0' = todos los trabajadores; otro valor filtra por código person.

    Solo trabajadores activos (PR_Employee.Status = 'N').
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_r019_vacationdetail_web]
    @cia          VARCHAR(20),
    @payrolltype  VARCHAR(20),
    @period       VARCHAR(20),
    @person       VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF RTRIM(ISNULL(@period, '')) = '' SET @period = '0';

    SELECT
        vd.PRPeriod AS prperiod,
        e.Person AS person,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS name,
        vd.DateBegin AS datebegin,
        vd.DateEnd AS dateend,
        vd.Days AS days,
        v.ControlYear AS controlyear,
        sp.DocumentNumber AS documentnumber,
        pos.Description AS cargo
    FROM PR_VacationDetail vd
        INNER JOIN PR_Vacation v (NOLOCK)
            ON vd.Person = v.Person
           AND vd.Company = v.Company
           AND vd.Line = v.Line
        INNER JOIN PR_Employee e (NOLOCK)
            ON vd.Person = e.Person
           AND vd.Company = e.Company
        INNER JOIN SY_Person sp (NOLOCK)
            ON vd.Person = sp.Person
        INNER JOIN PR_PayRollType pt (NOLOCK)
            ON e.PayRollType = pt.PayRollType
        LEFT JOIN PR_Position pos (NOLOCK)
            ON e.Position = pos.Position
    WHERE vd.Company = @cia
      AND e.PayRollType = @payrolltype
      AND (@person = '0' OR e.Person = @person)
      AND (@period = '0' OR LEFT(vd.PRPeriod, 6) = LEFT(@period, 6))
      AND e.Status = 'N'
    ORDER BY name, person, vd.DateBegin;
END
GO



-- ============================================================================
-- [56/89] sp_pr_reportelistadopagos_web.sql
-- ============================================================================

/*
    Listado de pagos por trabajador (reporte RPR001 / Listado de pago).
    Usado por: POST /api/reportes/listado-pagos (reporte_listado_pagos.html).

    Filtros (mismos que Telecrédito, sin fecha de pago) + banco haberes opcional:
      @par_company, @par_payrolltype, @par_processtype, @par_period,
      @par_concept, @par_currency (LO/EX), @cesados, @salarybank (0 = todos).

    Columnas alineadas al DataWindow ReportePagos (PowerBuilder).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportelistadopagos_web]
    @par_company     VARCHAR(10),
    @par_currency    VARCHAR(2),
    @par_concept     VARCHAR(20),
    @par_payrolltype VARCHAR(20),
    @par_period      VARCHAR(8),
    @par_processtype VARCHAR(20),
    @cesados         CHAR(1),
    @salarybank      VARCHAR(20) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@par_currency, '')) = '' SET @par_currency = 'LO';
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';
    IF RTRIM(ISNULL(@salarybank, '')) = '' SET @salarybank = '0';

    ;WITH Importes AS (
        SELECT
            epc.person,
            SUM(
                CASE
                    WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                    ELSE ISNULL(epc.conceptvaluelo, 0)
                END
            ) AS importe
        FROM PR_EmployeePayRollConcept epc
        WHERE epc.company = @par_company
          AND epc.payrolltype = @par_payrolltype
          AND epc.processtype = @par_processtype
          AND epc.concept = @par_concept
          AND epc.prperiod = @par_period
        GROUP BY epc.person
        HAVING SUM(
            CASE
                WHEN @par_currency = 'EX' THEN ISNULL(epc.conceptvalueex, 0)
                ELSE ISNULL(epc.conceptvaluelo, 0)
            END
        ) <> 0
    )
    SELECT
        e.EmployeeCode AS employeecode,
        LTRIM(RTRIM(
            ISNULL(sp.LastName1, '') + ' ' +
            ISNULL(sp.LastName2, '') + ' ' +
            ISNULL(sp.Name1, '') + ' ' +
            ISNULL(sp.Name2, '')
        )) AS nombre,
        CASE
            WHEN pt.ShortName = 'CTS'
              OR UPPER(LTRIM(RTRIM(pt.Description))) IN ('CTS', 'PAGO DE CTS', 'PAGO DE  CTS')
                THEN b_cts.Name
            ELSE b_sal.Name
        END AS banco,
        CASE
            WHEN CHARINDEX('TACAR', sc.Description) > 0 THEN ru_pay.Description
            ELSE ru_per.Description
        END AS obra,
        cc.Name AS costcenter,
        CASE
            WHEN pt.ShortName = 'CTS'
              OR UPPER(LTRIM(RTRIM(pt.Description))) IN ('CTS', 'PAGO DE CTS', 'PAGO DE  CTS')
                THEN e.CTSAccount
            ELSE e.SalaryAccount
        END AS cuenta,
        CASE
            WHEN pt.ShortName = 'CTS'
              OR UPPER(LTRIM(RTRIM(pt.Description))) IN ('CTS', 'PAGO DE CTS', 'PAGO DE  CTS')
                THEN e.CTSCurrency
            ELSE e.SalaryCurrency
        END AS moneda,
        i.importe
    FROM Importes i
        INNER JOIN PR_Employee e
            ON e.Person = i.person
           AND e.Company = @par_company
        INNER JOIN SY_Person sp
            ON sp.Person = e.Person
        INNER JOIN SY_Company sc
            ON sc.Company = e.Company
        INNER JOIN PR_ProcessType pt
            ON pt.ProcessType = @par_processtype
           AND pt.Company = @par_company
        LEFT JOIN PR_EmployeePayRoll epr
            ON epr.Company = e.Company
           AND epr.Person = e.Person
           AND epr.PayRollType = @par_payrolltype
           AND epr.ProcessType = @par_processtype
           AND epr.PRPeriod = @par_period
        LEFT JOIN SY_ReplicationUnit ru_pay
            ON ru_pay.ReplicationUnit = epr.ReplicationUnit
        LEFT JOIN SY_ReplicationUnit ru_per
            ON ru_per.ReplicationUnit = sp.ReplicationUnit
        LEFT JOIN AC_CostCenter cc
            ON cc.CostCenter = e.CostCenter
        LEFT JOIN ERP_Bank b_sal
            ON b_sal.Bank = e.SalaryBank
           AND b_sal.Company = e.Company
        LEFT JOIN ERP_Bank b_cts
            ON b_cts.Bank = e.CTSBank
           AND b_cts.Company = e.Company
    WHERE e.PayRollType = @par_payrolltype
      AND (@salarybank = '0' OR e.SalaryBank = @salarybank)
      AND (
            @cesados = 'T'
         OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
         OR (@cesados = 'N' AND e.CeaseDate IS NULL)
      )
    ORDER BY
        CASE
            WHEN pt.ShortName = 'CTS'
              OR UPPER(LTRIM(RTRIM(pt.Description))) IN ('CTS', 'PAGO DE CTS', 'PAGO DE  CTS')
                THEN b_cts.Name
            ELSE b_sal.Name
        END,
        nombre,
        e.EmployeeCode;
END
GO



-- ============================================================================
-- [57/89] sp_pr_reportelog_calculo_web.sql
-- ============================================================================

/*
    Log de cálculo de planillas — detalle por persona y concepto.
    Usado por: POST /reporte_log_calculo (reporte_log_calculo.html).

    Basado en sp_pr_reportelog_calculo legacy (PowerBuilder).

    Parámetros (mismo criterio que planilla vertical):
      @cia         — compañía
      @payrolltype — tipo de planilla
      @process     — tipo de proceso
      @period      — periodo (YYYYMMDD)
      @person      — código persona; '0' = todos

    Ejemplo:
      EXEC sp_pr_reportelog_calculo_web
           @cia = 'BGT',
           @payrolltype = 'LIMABGT 000000000005',
           @process = 'LIMABGT 000000000001',
           @period = '20260404',
           @person = '0';
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportelog_calculo_web]
    @cia         CHAR(4),
    @payrolltype VARCHAR(20),
    @process     VARCHAR(20),
    @period      VARCHAR(8),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @person = LTRIM(RTRIM(ISNULL(@person, '0')));
    IF @person = '' SET @person = '0';

    SELECT
        SY_Person.Person AS person,
        SY_Person.Name AS name,
        PR_LOG_CALCULO_PLANILLAS.fecha AS fecha,
        PR_Concept.Description AS concepto,
        PR_Concept.FormulaCode AS formulacode,
        PR_LOG_CALCULO_PLANILLAS.importe AS importe,
        PR_ConceptType.Description AS tipoconcepto,
        CASE
            WHEN PR_LOG_CALCULO_PLANILLAS.tipo = 'F' THEN 'Formula'
            ELSE 'De Asignación'
        END AS tipocalculo,
        ISNULL(PR_Concept.flaginsertar, 'N') AS flaginsertar,
        ISNULL(PR_Concept.flagafecto5ta, 'N') AS flagafecto5ta,
        ISNULL(PR_Concept.flagafectoAFP, 'N') AS flagafectoafp,
        (
            SELECT TOP 1 epc.periodbegin
            FROM PR_EmployeePayRollConcept epc
            WHERE epc.Person = PR_LOG_CALCULO_PLANILLAS.person
              AND epc.Company = @cia
              AND epc.PayRollType = @payrolltype
              AND epc.ProcessType = @process
              AND epc.PRPeriod = @period
              AND EXISTS (
                  SELECT 1
                  FROM PR_Concept c
                  WHERE c.Company = @cia
                    AND c.FormulaCode = PR_LOG_CALCULO_PLANILLAS.concepto
                    AND c.Concept = epc.Concept
              )
        ) AS periodbegin
    FROM PR_LOG_CALCULO_PLANILLAS
    LEFT JOIN PR_Concept
        ON PR_LOG_CALCULO_PLANILLAS.concepto = PR_Concept.FormulaCode
       AND PR_Concept.Company = @cia
    LEFT JOIN PR_ConceptType
        ON PR_Concept.ConceptType = PR_ConceptType.ConceptType
    INNER JOIN SY_Person
        ON PR_LOG_CALCULO_PLANILLAS.person = SY_Person.Person
    WHERE PR_LOG_CALCULO_PLANILLAS.Company = @cia
      AND PR_LOG_CALCULO_PLANILLAS.payrolltype = @payrolltype
      AND PR_LOG_CALCULO_PLANILLAS.process = @process
      AND PR_LOG_CALCULO_PLANILLAS.period = @period
      AND (@person = '0' OR PR_LOG_CALCULO_PLANILLAS.person = @person)
    ORDER BY
        PR_ConceptType.Description,
        SY_Person.Name,
        PR_LOG_CALCULO_PLANILLAS.fecha;
END

GO


-- ============================================================================
-- [58/89] sp_pr_reporteplame_total_web.sql
-- ============================================================================

/*
    Resumen planilla total (PLAME) por concepto y tipo de proceso.
    Usado por: POST /reporte_resumen_total (reporte_resumen_total.html).

    Agrupa importes monetarios con flag de boleta por:
    Mensual (FIN_DE_MES), Semanal, Vacaciones, Liquidación, CTS y Gratificación.

    Filtro de periodo:
      - Mensual (FIN_DE_MES): periodo exacto (@period).
      - Semanal: año-mes LEFT(prperiod, 6) = LEFT(@period, 6), proceso PR_Mapping.PlanillaSemProcess.
      - Demás columnas: año-mes LEFT(prperiod, 6) = LEFT(@period, 6).

    Parámetros:
      @cia, @payrolltype, @period — obligatorios para filtrar.
      @person — reservado (la web envía NULL).

    Ejemplo:
      EXEC sp_pr_reporteplame_total_web 'BGT', 'LIMABGT 000000000005', '20260404', NULL;
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteplame_total_web]
    @cia          VARCHAR(20),
    @payrolltype  VARCHAR(20),
    @period       VARCHAR(20),
    @person       VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    CREATE TABLE [#Temporal] (
        [Tipo]         VARCHAR(50) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [PDT]          VARCHAR(20) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [Concepto]     VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [TipoPlanilla] VARCHAR(255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
        [Mensual]      NUMERIC(19, 4),
        [Semanal]      NUMERIC(19, 4),
        [Liquida]      NUMERIC(19, 4),
        [Vacaciones]   NUMERIC(19, 4),
        [CTS]          NUMERIC(19, 4),
        [Grati]        NUMERIC(19, 4) NULL
    ) ON [PRIMARY];

    /* Catálogo de conceptos presentes en el periodo (todas las columnas en cero). */
    INSERT INTO #Temporal (Tipo, PDT, Concepto, Mensual, Semanal, Liquida, Vacaciones, CTS)
    SELECT DISTINCT
        tipo,
        pdt,
        concepto,
        0, 0, 0, 0, 0
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('FIN_DE_MES', 'SEMANAL', 'VACACIONES', 'LIQUIDACION', 'CTS')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T;

    /* FIN DE MES → Mensual */
    UPDATE #Temporal
    SET Mensual = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LTRIM(RTRIM(PR_EmployeePayRollConcept.PRPeriod)) = @period
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('FIN_DE_MES')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* SEMANAL */
    UPDATE #Temporal
    SET Semanal = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(LTRIM(RTRIM(PR_EmployeePayRollConcept.PRPeriod)), 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.ProcessType = PR_Mapping.PlanillaSemProcess
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* VACACIONES */
    UPDATE #Temporal
    SET Vacaciones = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('VACACIONES')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* LIQUIDACION */
    UPDATE #Temporal
    SET Liquida = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('LIQUIDACION')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* CTS */
    UPDATE #Temporal
    SET CTS = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('CTS')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    /* GRATIFICACION */
    UPDATE #Temporal
    SET Grati = T.importe
    FROM (
        SELECT
            UPPER(PR_ConceptType.Description) AS tipo,
            ISNULL(PR_Concept.PDT, '') AS pdt,
            PR_Concept.PrintText AS concepto,
            PR_ProcessType.ShortName AS proceso,
            SUM(PR_EmployeePayRollConcept.ConceptValue) AS importe
        FROM PR_Employee (NOLOCK)
            INNER JOIN SY_Person (NOLOCK)
                ON SY_Person.Person = PR_Employee.Person
            LEFT JOIN SY_PersonDocumentType (NOLOCK)
                ON SY_Person.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
            LEFT JOIN PR_EmployeeCategory (NOLOCK)
                ON PR_Employee.EmployeeCategory = PR_EmployeeCategory.EmployeeCategory
            INNER JOIN PR_EmployeePayRollConcept (NOLOCK)
                ON PR_EmployeePayRollConcept.Person = PR_Employee.Person
               AND PR_EmployeePayRollConcept.Company = PR_Employee.Company
            INNER JOIN PR_Concept (NOLOCK)
                ON PR_EmployeePayRollConcept.Concept = PR_Concept.Concept
            INNER JOIN PR_ConceptType (NOLOCK)
                ON PR_ConceptType.ConceptType = PR_Concept.ConceptType
            INNER JOIN PR_Mapping (NOLOCK)
                ON PR_EmployeePayRollConcept.Company = PR_Mapping.Company
            INNER JOIN PR_PayRollType
                ON PR_EmployeePayRollConcept.PayRollType = PR_PayRollType.PayRollType
            INNER JOIN PR_ProcessType
                ON PR_EmployeePayRollConcept.ProcessType = PR_ProcessType.ProcessType
            INNER JOIN PR_EmployeePayRoll
                ON PR_EmployeePayRoll.Company = PR_EmployeePayRollConcept.Company
               AND PR_EmployeePayRoll.PRPeriod = PR_EmployeePayRollConcept.PRPeriod
               AND PR_EmployeePayRoll.ProcessType = PR_EmployeePayRollConcept.ProcessType
               AND PR_EmployeePayRoll.PayRollType = PR_EmployeePayRollConcept.PayRollType
               AND PR_EmployeePayRoll.Person = PR_EmployeePayRollConcept.Person
        WHERE PR_Mapping.Company = @cia
          AND LEFT(PR_EmployeePayRollConcept.PRPeriod, 6) = LEFT(@period, 6)
          AND ISNULL(PR_Concept.FlagPayRollTicket, 'N') = 'Y'
          AND PR_ConceptType.ShortName IN ('I', 'D', 'A', 'T')
          AND PR_Concept.FlagIsMonetary = 'Y'
          AND PR_EmployeePayRollConcept.PayRollType = @payrolltype
          AND EXISTS (
                SELECT 1
                FROM PR_ProcessType pt
                WHERE pt.ProcessType = PR_EmployeePayRollConcept.ProcessType
                  AND pt.ShortName IN ('GRATIFICACION')
          )
        GROUP BY
            PR_ConceptType.ORDEN,
            UPPER(PR_ConceptType.Description),
            ISNULL(PR_Concept.PDT, ''),
            PR_Concept.PrintText,
            PR_ProcessType.ShortName
    ) T
    WHERE #Temporal.Tipo = T.tipo
      AND ISNULL(#Temporal.PDT, '') = ISNULL(T.pdt, '')
      AND #Temporal.Concepto = T.concepto;

    SELECT #Temporal.*
    FROM #Temporal
        INNER JOIN PR_ConceptType
            ON #Temporal.Tipo = PR_ConceptType.Description
           AND PR_ConceptType.Company = @cia
    ORDER BY PR_ConceptType.ORDEN, 3;
END
GO



-- ============================================================================
-- [59/89] sp_pr_reporteplamevertical_web.sql
-- ============================================================================

/*
    Reporte planilla vertical (PLAME) — conceptos en columnas dinámicas.
    Usado por: POST /reporte_planilla_vertical (reporte_planilla_vertical.html).

    Basado en sp_pr_reporteplamevertical legacy (PowerBuilder).

    Tablas de trabajo (deben existir en la BD):
      xx_plamevertical2  — detalle persona × concepto
      xx_reporteplanilla — matriz persona × concept01..concept65

    Parámetros:
      @cia         — compañía
      @payrolltype — tipo de planilla
      @process     — tipo de proceso
      @period      — periodo (YYYYMM o YYYYMMDD; filtra por LEFT 6)
      @person      — código persona; '0' = todos
      @salarybank  — banco haberes; '' = todos
      @fecha_ingreso_all   — Y = todas las fechas, N = filtrar por rango
      @fecha_ingreso_desde — YYYY-MM-DD (fecha efectiva ISNULL(ReEntryDate, EntryDate))
      @fecha_ingreso_hasta — YYYY-MM-DD

    Resultado final: una fila por trabajador con columnas fijas + concept01..concept65.

    Ejemplo:
      EXEC sp_pr_reporteplamevertical_web
           @cia = 'BGT',
           @payrolltype = 'LIMABGT 000000000005',
           @process = 'LIMABGT 000000000001',
           @period = '202604',
           @person = '0',
           @salarybank = '';
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteplamevertical_web]
    @cia         CHAR(4),
    @payrolltype VARCHAR(20),
    @process     VARCHAR(20),
    @period      VARCHAR(8),
    @person      VARCHAR(20),
    @salarybank  VARCHAR(20),
    @fecha_ingreso_all    CHAR(1)     = 'Y',
    @fecha_ingreso_desde  VARCHAR(10) = '',
    @fecha_ingreso_hasta  VARCHAR(10) = ''
AS
BEGIN
    SET NOCOUNT ON;

    SET @fecha_ingreso_all = UPPER(LTRIM(RTRIM(ISNULL(@fecha_ingreso_all, 'Y'))));
    IF @fecha_ingreso_all NOT IN ('Y', 'N') SET @fecha_ingreso_all = 'Y';
    SET @fecha_ingreso_desde = LTRIM(RTRIM(ISNULL(@fecha_ingreso_desde, '')));
    SET @fecha_ingreso_hasta = LTRIM(RTRIM(ISNULL(@fecha_ingreso_hasta, '')));

    DECLARE @fd DATE = NULL;
    DECLARE @fh DATE = NULL;
    IF @fecha_ingreso_desde <> ''
        SET @fd = TRY_CONVERT(DATE, @fecha_ingreso_desde, 23);
    IF @fecha_ingreso_hasta <> ''
        SET @fh = TRY_CONVERT(DATE, @fecha_ingreso_hasta, 23);

    DECLARE @personid     VARCHAR(20);
    DECLARE @name         VARCHAR(255);
    DECLARE @conceptname  VARCHAR(255);
    DECLARE @columna      VARCHAR(50);
    DECLARE @currency     CHAR(2);
    DECLARE @grupo        CHAR(1);
    DECLARE @conceptvalue NUMERIC(19, 4);
    DECLARE @orden        INT;
    DECLARE @k            INT;
    DECLARE @col          CHAR(20);
    DECLARE @query1       VARCHAR(255);
    DECLARE @concepto     VARCHAR(100);

    SET @currency = 'LO';
    SET @grupo = 'N';

    CREATE TABLE [#Temporal] (
        [concepto] VARCHAR(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
        [columna]  VARCHAR(100) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL
    ) ON [PRIMARY];

    DELETE FROM xx_plamevertical2;
    DELETE FROM xx_reporteplanilla;

    INSERT INTO xx_plamevertical2
    SELECT
        PR.description AS processname,
        p.description AS payrolltypename,
        T.description AS concepttypename,
        c.description AS conceptname,
        c.pdt AS pdt,
        epc.person,
        sy_person.name AS name,
        MAX(ISNULL(E.ReEntryDate, E.EntryDate)) AS entrydate,
        MAX(ep.ceasedate) AS ceasedate,
        MAX(ep.position) AS position,
        CASE
            WHEN ISNULL((
                SELECT TOP 1 description
                FROM pr_afp
                WHERE pr_afp.afp = MAX(ep.afp)
            ), '') = '' THEN 'ONP'
            ELSE (
                SELECT TOP 1 description
                FROM pr_afp
                WHERE pr_afp.afp = MAX(ep.afp)
            )
        END,
        MAX(ep.costcenter) AS costcenter,
        CASE
            WHEN @currency = 'LO' THEN SUM(ROUND(EPC.conceptvalue, 2))
            ELSE SUM(ROUND(EPC.ConceptValueEx, 2))
        END AS conceptvalue
    FROM pr_employeepayrollconcept EPC
        INNER JOIN PR_EmployeePayRoll EP
            ON epc.Company = ep.Company
           AND epc.ProcessType = ep.ProcessType
           AND epc.PayRollType = ep.PayRollType
           AND epc.PRPeriod = ep.PRPeriod
           AND epc.Person = ep.Person
        INNER JOIN PR_Employee E
            ON EPC.Company = E.Company
           AND EPC.Person = E.Person
        INNER JOIN pr_payrolltype P ON epc.payrolltype = p.payrolltype
        INNER JOIN pr_concept C ON epc.concept = c.concept
        INNER JOIN pr_concepttype T ON c.concepttype = T.concepttype
        INNER JOIN pr_processtype PR ON epc.processtype = pr.processtype
        INNER JOIN SY_PERSON ON EPC.person = SY_Person.person
    WHERE EPC.company = @cia
      AND LEFT(EPC.prperiod, 6) = LEFT(@period, 6)
      AND ISNULL(c.reporden, 0) <> 0
      AND t.shortname IN ('I', 'D', 'A', 'T', 'G', 'X')
      AND EPC.PayRollType = @payrolltype
      AND EPC.ProcessType = @process
      AND (@salarybank = '' OR E.SalaryBank = @salarybank)
      AND (@person = '0' OR SY_PERSON.person = @person)
      AND (
            @fecha_ingreso_all = 'Y'
         OR (
                ISNULL(E.ReEntryDate, E.EntryDate) IS NOT NULL
            AND (@fd IS NULL
                 OR CAST(ISNULL(E.ReEntryDate, E.EntryDate) AS DATE) >= @fd)
            AND (@fh IS NULL
                 OR CAST(ISNULL(E.ReEntryDate, E.EntryDate) AS DATE) <= @fh)
            )
      )
      AND epc.Person <> 'T3549'
    GROUP BY
        PR.description,
        p.description,
        T.description,
        c.description,
        c.pdt,
        epc.person,
        sy_person.name
    ORDER BY 7;

    INSERT INTO xx_reporteplanilla (
        person, name, entrydate, ceasedate, position, afp, costcenter,
        concept01, concept02, concept03, concept04, concept05, concept06, concept07, concept08, concept09, concept10,
        concept11, concept12, concept13, concept14, concept15, concept16, concept17, concept18, concept19, concept20,
        concept21, concept22, concept23, concept24, concept25, concept26, concept27, concept28, concept29, concept30,
        concept31, concept32, concept33, concept34, concept35, concept36, concept37, concept38, concept39, concept40,
        concept41, concept42, concept43, concept44, concept45, concept46, concept47, concept48, concept49, concept50,
        concept51, concept52, concept53, concept54, concept55, concept56, concept57, concept58, concept59, concept60,
        concept61, concept62, concept63, concept64, concept65
    )
    SELECT DISTINCT
        person, name, entrydate, ceasedate, position, afp, costcenter,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0
    FROM xx_plamevertical2
    ORDER BY name;

    SET @k = 0;

    DECLARE lista CURSOR FOR
        SELECT DISTINCT conceptname, reporden
        FROM xx_plamevertical2
            INNER JOIN PR_Concept
                ON xx_plamevertical2.conceptname = PR_Concept.Description
               AND PR_Concept.Company = @cia
        ORDER BY reporden, conceptname ASC;

    OPEN lista;
    FETCH NEXT FROM lista INTO @concepto, @orden;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @query1 = '';
        SET @k = @k + 1;
        SET @col = 'concept' + REPLICATE('0', 2 - LEN(CONVERT(CHAR(2), @k))) + CONVERT(CHAR(2), @k);
        INSERT INTO #Temporal VALUES (@concepto, @col);
        FETCH NEXT FROM lista INTO @concepto, @orden;
    END;
    CLOSE lista;
    DEALLOCATE lista;

    DECLARE listareporte CURSOR FOR
        SELECT person, name, conceptname, ISNULL(conceptvalue, 0)
        FROM xx_plamevertical2;

    OPEN listareporte;
    FETCH NEXT FROM listareporte INTO @personid, @name, @conceptname, @conceptvalue;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @query1 = '';
        SELECT @columna = columna FROM #Temporal WHERE concepto = @conceptname;
        SET @query1 = 'UPDATE xx_reporteplanilla SET ' + @columna + ' = ' + CONVERT(VARCHAR(20), @conceptvalue)
                    + ' WHERE person = ' + CHAR(39) + @personid + CHAR(39);
        EXECUTE(@query1);
        FETCH NEXT FROM listareporte INTO @personid, @name, @conceptname, @conceptvalue;
    END;
    CLOSE listareporte;
    DEALLOCATE listareporte;

    IF @grupo = 'N'
    BEGIN
        SELECT
            person,
            name,
            entrydate,
            ceasedate,
            (SELECT Description FROM PR_Position WHERE Position = xx_reporteplanilla.position) AS position,
            afp,
            (SELECT Description FROM AC_CostCenter WHERE CostCenter = xx_reporteplanilla.costcenter) AS ccname,
            (SELECT CCCode FROM AC_CostCenter WHERE CostCenter = xx_reporteplanilla.costcenter) AS costcenter,
            (
                SELECT Description
                FROM SY_ReplicationUnit
                    INNER JOIN SY_Person ON SY_ReplicationUnit.ReplicationUnit = SY_Person.ReplicationUnit
                WHERE SY_Person.Person = xx_reporteplanilla.person
            ) AS unidad,
            (
                SELECT CASE WHEN ISNULL(SY_Person.isrecruiter, 'N') = 'Y' THEN 'H' ELSE 'P' END
                FROM sy_person
                WHERE person = xx_reporteplanilla.person
            ) AS tipopago,
            (
                SELECT description
                FROM PR_AccountProfile
                    INNER JOIN PR_Employee
                        ON PR_AccountProfile.AccountProfile = PR_Employee.AccountProfile
                       AND PR_AccountProfile.company = @cia
                       AND PR_Employee.Person = xx_reporteplanilla.person
            ) AS profile,
            (
                SELECT SUM(hourday)
                FROM PR_REGISTERHOUR
                WHERE period = @period
                  AND Company = @cia
                  AND person = xx_reporteplanilla.person
            ) AS horas,
            CASE
                WHEN (
                    SELECT ShortName
                    FROM PR_ProcessType
                    WHERE Company = @cia AND ProcessType = @process
                ) = 'CTS' THEN (
                    SELECT name
                    FROM ERP_Bank
                        INNER JOIN PR_Employee
                            ON ERP_Bank.Bank = PR_Employee.CTSBank
                           AND ERP_Bank.company = @cia
                           AND PR_Employee.Person = xx_reporteplanilla.person
                )
                ELSE (
                    SELECT name
                    FROM ERP_Bank
                        INNER JOIN PR_Employee
                            ON ERP_Bank.Bank = PR_Employee.SalaryBank
                           AND ERP_Bank.company = @cia
                           AND PR_Employee.Person = xx_reporteplanilla.person
                )
            END AS banco,
            CASE
                WHEN (
                    SELECT ShortName
                    FROM PR_ProcessType
                    WHERE Company = @cia AND ProcessType = @process
                ) = 'CTS' THEN (
                    SELECT CTSAccount
                    FROM PR_Employee
                    WHERE PR_Employee.Person = xx_reporteplanilla.person
                      AND PR_Employee.Company = @cia
                )
                ELSE (
                    SELECT salaryaccount
                    FROM PR_Employee
                    WHERE PR_Employee.Person = xx_reporteplanilla.person
                      AND PR_Employee.Company = @cia
                )
            END AS numcuenta,
            concept01, concept02, concept03, concept04, concept05, concept06, concept07, concept08, concept09, concept10,
            concept11, concept12, concept13, concept14, concept15, concept16, concept17, concept18, concept19, concept20,
            concept21, concept22, concept23, concept24, concept25, concept26, concept27, concept28, concept29, concept30,
            concept31, concept32, concept33, concept34, concept35, concept36, concept37, concept38, concept39, concept40,
            concept41, concept42, concept43, concept44, concept45, concept46, concept47, concept48, concept49, concept50,
            concept51, concept52, concept53, concept54, concept55, concept56, concept57, concept58, concept59, concept60,
            concept61, concept62, concept63, concept64, concept65
        FROM xx_reporteplanilla
        ORDER BY 2;
    END
    ELSE
    BEGIN
        SELECT
            person,
            name,
            MAX(entrydate),
            MAX(ceasedate),
            (SELECT Description FROM PR_Position WHERE Position = xx_reporteplanilla.position) AS position,
            MAX(afp),
            (SELECT Description FROM AC_CostCenter WHERE CostCenter = xx_reporteplanilla.costcenter) AS ccname,
            (SELECT CCCode FROM AC_CostCenter WHERE CostCenter = xx_reporteplanilla.costcenter) AS costcenter,
            '' AS unidad,
            '' AS tipopago,
            '' AS profile,
            0 AS horas,
            '' AS banco,
            '' AS numcuenta,
            SUM(concept01), SUM(concept02), SUM(concept03), SUM(concept04), SUM(concept05), SUM(concept06), SUM(concept07), SUM(concept08), SUM(concept09), SUM(concept10),
            SUM(concept11), SUM(concept12), SUM(concept13), SUM(concept14), SUM(concept15), SUM(concept16), SUM(concept17), SUM(concept18), SUM(concept19), SUM(concept20),
            SUM(concept21), SUM(concept22), SUM(concept23), SUM(concept24), SUM(concept25), SUM(concept26), SUM(concept27), SUM(concept28), SUM(concept29), SUM(concept30),
            SUM(concept31), SUM(concept32), SUM(concept33), SUM(concept34), SUM(concept35), SUM(concept36), SUM(concept37), SUM(concept38), SUM(concept39), SUM(concept40),
            SUM(concept41), SUM(concept42), SUM(concept43), SUM(concept44), SUM(concept45), SUM(concept46), SUM(concept47), SUM(concept48), SUM(concept49), SUM(concept50),
            SUM(concept51), SUM(concept52), SUM(concept53), SUM(concept54), SUM(concept55), SUM(concept56), SUM(concept57), SUM(concept58), SUM(concept59), SUM(concept60),
            SUM(concept61), SUM(concept62), SUM(concept63), SUM(concept64), SUM(concept65)
        FROM xx_reporteplanilla
        GROUP BY person, name, xx_reporteplanilla.position, xx_reporteplanilla.costcenter
        ORDER BY name;
    END;

    DROP TABLE #Temporal;
END
GO



-- ============================================================================
-- [60/89] sp_pr_reportesdescansos_medicos_web.sql
-- ============================================================================

/*
    Detalle de descansos médicos por trabajador.
    Usado por: POST /reporte_descansos_medicos_detalle (reporte_descansos_medicos_detalle.html).

    Parámetros:
      @cia, @payrolltype — obligatorios.
      @period — '0' = todos los periodos; otro valor filtra por YYYYMM (primeros 6 caracteres).
      @person — '0' = todos los trabajadores; otro valor filtra por código person.
      @medicalresttype — '0' = todos los tipos; otro valor filtra por PR_MedicalRestType.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportesdescansos_medicos_web]
    @cia               VARCHAR(20),
    @payrolltype       VARCHAR(20),
    @period            VARCHAR(20),
    @person            VARCHAR(20),
    @medicalresttype   VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF RTRIM(ISNULL(@period, '')) = '' SET @period = '0';
    IF RTRIM(ISNULL(@medicalresttype, '')) = '' SET @medicalresttype = '0';

    SELECT
        PR_EmployeeMedicalRest.PRPeriod AS prperiod,
        SY_Person.Person AS person,
        LTRIM(RTRIM(
            ISNULL(SY_Person.LastName1, '') + ' ' +
            ISNULL(SY_Person.LastName2, '') + ' ' +
            ISNULL(SY_Person.Name1, '') + ' ' +
            ISNULL(SY_Person.Name2, '')
        )) AS name,
        PR_EmployeeMedicalRest.DateBegin AS datebegin,
        PR_EmployeeMedicalRest.DateEnd AS dateend,
        PR_EmployeeMedicalRest.Days AS days,
        PR_MedicalRestType.Description AS description,
        PR_EmployeeMedicalRest.CITT AS citt
    FROM SY_Company
        INNER JOIN PR_Employee
            ON SY_Company.Company = PR_Employee.Company
        INNER JOIN SY_Person
            ON SY_Person.Person = PR_Employee.Person
        INNER JOIN PR_EmployeeMedicalRest
            ON PR_EmployeeMedicalRest.Person = PR_Employee.Person
           AND PR_EmployeeMedicalRest.Company = PR_Employee.Company
        INNER JOIN PR_MedicalRestType
            ON PR_MedicalRestType.MedicalRestType = PR_EmployeeMedicalRest.MedicalRestType
    WHERE PR_EmployeeMedicalRest.Company = @cia
      AND PR_Employee.PayRollType = @payrolltype
      AND (@person = '0' OR PR_Employee.Person = @person)
      AND (@medicalresttype = '0' OR PR_EmployeeMedicalRest.MedicalRestType = @medicalresttype)
      AND (@period = '0' OR LEFT(PR_EmployeeMedicalRest.PRPeriod, 6) = LEFT(@period, 6))
    ORDER BY name, person, PR_EmployeeMedicalRest.DateBegin;
END
GO



-- ============================================================================
-- [61/89] sp_pr_resumen_declaracion_afp_web.sql
-- ============================================================================

/*
    Resumen Declaración AFP — cuadros de verificación post-generación AFPnet.

    Usado por: POST /api/declaracion-afp/generar-xlsx

    Criterio planilla manda: régimen AFP, ingreso y cese según PR_EmployeePayRoll del periodo.

    Resultset 1 — Montos TOTAL_REM_AFP por proceso (FIN_DE_MES, LIQUIDACION, SEMANAL).
              Jubilados (FLAG_JUBILADO) no suman: en AFPnet su remuneración asegurable es 0.
    Resultset 2 — Conteo trabajadores en planilla (nuevos / cesados / antiguos).
    Resultset 3 — Detalle trabajadores en planilla (para identificar diferencias AFPnet).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_resumen_declaracion_afp_web]
    @cia              VARCHAR(10),
    @period           VARCHAR(20),
    @payroll_all      CHAR(1)     = 'Y',
    @payroll          VARCHAR(20) = NULL,
    @afp_all          CHAR(1)     = 'Y',
    @afp              VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 6);
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @afp_all = UPPER(LTRIM(RTRIM(ISNULL(@afp_all, 'Y'))));
    SET @afp = LTRIM(RTRIM(ISNULL(@afp, '')));
    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';
    IF @afp_all NOT IN ('Y', 'N') SET @afp_all = 'Y';
    IF @payroll_all = 'Y' SET @payroll = '';
    IF @afp_all = 'Y' SET @afp = '';

    CREATE TABLE #AfpPlanilla (
        person VARCHAR(20) NOT NULL PRIMARY KEY
    );

    CREATE TABLE #PlanillaFechas (
        person VARCHAR(20) NOT NULL PRIMARY KEY,
        entrydate DATETIME NULL,
        ceasedate DATETIME NULL
    );

    INSERT INTO #AfpPlanilla (person)
    SELECT DISTINCT LTRIM(RTRIM(EP.Person))
    FROM PR_EmployeePayRoll EP (NOLOCK)
    WHERE EP.Company = @cia
      AND LEFT(EP.PRPeriod, 6) = @period
      AND ISNULL(LTRIM(RTRIM(EP.AFP)), '') <> ''
      AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
      AND (@afp_all = 'Y' OR LTRIM(RTRIM(EP.AFP)) = @afp);

    INSERT INTO #PlanillaFechas (person, entrydate, ceasedate)
    SELECT
        LTRIM(RTRIM(EP.Person)),
        MAX(CASE WHEN LTRIM(RTRIM(PT.ShortName)) = 'FIN_DE_MES' THEN EP.EntryDate END),
        MAX(CASE WHEN LTRIM(RTRIM(PT.ShortName)) = 'FIN_DE_MES' THEN EP.CeaseDate END)
    FROM PR_EmployeePayRoll EP (NOLOCK)
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PT.ProcessType = EP.ProcessType
           AND PT.Company = EP.Company
    WHERE EP.Company = @cia
      AND LEFT(EP.PRPeriod, 6) = @period
      AND ISNULL(LTRIM(RTRIM(EP.AFP)), '') <> ''
      AND LTRIM(RTRIM(PT.ShortName)) = 'FIN_DE_MES'
      AND (@payroll_all = 'Y' OR EP.PayRollType = @payroll)
      AND (@afp_all = 'Y' OR LTRIM(RTRIM(EP.AFP)) = @afp)
    GROUP BY LTRIM(RTRIM(EP.Person));

    /* --- Resultset 1: montos por proceso --- */
    SELECT
        P.proceso,
        CAST(ISNULL(M.monto, 0) AS DECIMAL(19, 2)) AS monto
    FROM (
        SELECT 'FIN_DE_MES' AS proceso, 1 AS orden
        UNION ALL SELECT 'LIQUIDACION', 2
        UNION ALL SELECT 'SEMANAL', 3
    ) P
    LEFT JOIN (
        SELECT
            LTRIM(RTRIM(PT.ShortName)) AS proceso,
            SUM(CAST(ISNULL(EPC.ConceptValueLo, 0) AS DECIMAL(19, 2))) AS monto
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK)
                ON EPC.Concept = C.Concept
               AND EPC.Company = C.Company
            INNER JOIN PR_ProcessType PT (NOLOCK)
                ON EPC.ProcessType = PT.ProcessType
               AND PT.Company = @cia
            INNER JOIN PR_EmployeePayRoll EP (NOLOCK)
                ON EP.Company = EPC.Company
               AND EP.Person = EPC.Person
               AND EP.PayRollType = EPC.PayRollType
               AND EP.ProcessType = EPC.ProcessType
               AND EP.PRPeriod = EPC.PRPeriod
            INNER JOIN #AfpPlanilla AP
                ON AP.person = LTRIM(RTRIM(EPC.Person))
        WHERE EPC.Company = @cia
          AND LEFT(EPC.PRPeriod, 6) = @period
          AND C.FormulaCode = 'TOTAL_REM_AFP'
          AND LTRIM(RTRIM(PT.ShortName)) IN ('FIN_DE_MES', 'LIQUIDACION', 'SEMANAL')
          AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
          AND ISNULL(LTRIM(RTRIM(EP.AFP)), '') <> ''
          AND (@afp_all = 'Y' OR LTRIM(RTRIM(EP.AFP)) = @afp)
          AND NOT EXISTS (
                SELECT 1
                FROM PR_EmployeeConcept EC (NOLOCK)
                    INNER JOIN PR_Concept Cj (NOLOCK)
                        ON EC.Concept = Cj.Concept
                       AND Cj.Company = @cia
                WHERE EC.Company = @cia
                  AND EC.Person = EPC.Person
                  AND Cj.FormulaCode = 'FLAG_JUBILADO'
                  AND EC.FlagFrecuencyType IN ('P', 'T')
                  AND (
                        EC.FlagFrecuencyType = 'P'
                        OR (EC.FlagFrecuencyType = 'T' AND LEFT(EC.PRPeriodStart, 6) = @period)
                      )
                  AND (@payroll_all = 'Y' OR EC.PayRollType = @payroll)
          )
        GROUP BY LTRIM(RTRIM(PT.ShortName))
    ) M ON M.proceso = P.proceso
    ORDER BY P.orden;

    CREATE TABLE #TrabajadoresPlanilla (
        person VARCHAR(20) NOT NULL PRIMARY KEY,
        es_jubilado CHAR(1) NOT NULL DEFAULT 'N'
    );

    INSERT INTO #TrabajadoresPlanilla (person, es_jubilado)
    SELECT DISTINCT
        LTRIM(RTRIM(A.person)),
        'N'
    FROM PR_EmployeeAFP A (NOLOCK)
        INNER JOIN PR_EmployeeAFPHeader H (NOLOCK)
            ON H.company = A.company
           AND H.prperiod = A.prperiod
           AND H.afp = A.afp
           AND H.replicationunit = A.replicationunit
           AND H.costcenter = A.costcenter
           AND H.payrolltype = A.payrolltype
        INNER JOIN #AfpPlanilla AP
            ON AP.person = LTRIM(RTRIM(A.person))
    WHERE A.company = @cia
      AND LEFT(A.prperiod, 6) = @period
      AND (@payroll_all = 'Y' OR H.payrolltype = @payroll)
      AND (@afp_all = 'Y' OR LTRIM(RTRIM(A.afp)) = @afp);

    INSERT INTO #TrabajadoresPlanilla (person, es_jubilado)
    SELECT DISTINCT
        LTRIM(RTRIM(EC.Person)),
        'S'
    FROM PR_EmployeeConcept EC (NOLOCK)
        INNER JOIN PR_Concept C (NOLOCK)
            ON EC.Concept = C.Concept
           AND C.Company = @cia
        INNER JOIN #AfpPlanilla AP
            ON AP.person = LTRIM(RTRIM(EC.Person))
    WHERE EC.Company = @cia
      AND C.FormulaCode = 'FLAG_JUBILADO'
      AND EC.FlagFrecuencyType IN ('P', 'T')
      AND (
            EC.FlagFrecuencyType = 'P'
            OR (EC.FlagFrecuencyType = 'T' AND LEFT(EC.PRPeriodStart, 6) = @period)
          )
      AND (@payroll_all = 'Y' OR EC.PayRollType = @payroll)
      AND NOT EXISTS (
            SELECT 1
            FROM #TrabajadoresPlanilla T
            WHERE T.person = LTRIM(RTRIM(EC.Person))
      );

    SELECT
        SUM(CASE WHEN inicio_en_periodo = 1 THEN 1 ELSE 0 END) AS nuevos,
        SUM(CASE WHEN cese_en_periodo = 1 THEN 1 ELSE 0 END) AS cesados,
        SUM(CASE WHEN inicio_en_periodo = 0 AND cese_en_periodo = 0 THEN 1 ELSE 0 END) AS antiguos,
        COUNT(*) AS total_planilla
    FROM (
        SELECT
            T.person,
            CASE
                WHEN PL.entrydate IS NOT NULL
                 AND LEFT(CONVERT(VARCHAR(8), PL.entrydate, 112), 6) = @period THEN 1
                ELSE 0
            END AS inicio_en_periodo,
            CASE
                WHEN PL.ceasedate IS NOT NULL
                 AND LEFT(CONVERT(VARCHAR(8), PL.ceasedate, 112), 6) = @period THEN 1
                ELSE 0
            END AS cese_en_periodo
        FROM #TrabajadoresPlanilla T
            INNER JOIN #PlanillaFechas PL
                ON PL.person = T.person
    ) X;

    SELECT
        LTRIM(RTRIM(T.person)) AS person,
        LTRIM(RTRIM(ISNULL(P.documentnumber, ''))) AS documentnumber,
        LTRIM(RTRIM(ISNULL(P.lastname1, ''))) AS lastname1,
        LTRIM(RTRIM(ISNULL(P.lastname2, ''))) AS lastname2,
        LTRIM(RTRIM(ISNULL(P.name1, '') + ' ' + ISNULL(P.name2, ''))) AS names,
        T.es_jubilado,
        CASE
            WHEN PL.entrydate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), PL.entrydate, 112), 6) = @period THEN 1
            ELSE 0
        END AS inicio_en_periodo,
        CASE
            WHEN PL.ceasedate IS NOT NULL
             AND LEFT(CONVERT(VARCHAR(8), PL.ceasedate, 112), 6) = @period THEN 1
            ELSE 0
        END AS cese_en_periodo
    FROM #TrabajadoresPlanilla T
        INNER JOIN #PlanillaFechas PL
            ON PL.person = T.person
        INNER JOIN sy_person P (NOLOCK)
            ON P.person = T.person
    ORDER BY P.lastname1, P.lastname2, P.name1, T.person;

    DROP TABLE #TrabajadoresPlanilla;
    DROP TABLE #PlanillaFechas;
    DROP TABLE #AfpPlanilla;
END
GO



-- ============================================================================
-- [62/89] sp_pr_saldovacaciones_web.sql
-- ============================================================================

/*
    Saldo de vacaciones por trabajador y año de control.
    Usado por: POST /reporte_saldo_vacaciones (reporte_saldo_vacaciones.html).

    Calcula saldos pendientes (saldo1..saldo5), faltas, licencias y descansos
    a una fecha de corte. Usa tabla de trabajo xx_saldovacaciones y función f_getDias360.

    Parámetros:
      @company, @payrolltype — obligatorios.
      @date — fecha de corte del saldo.
      @person — '0' = todos; otro valor filtra por código person.
      @cesados — T = Todos, Y = solo con fecha de cese, N = sin fecha de cese.

    Nota: actualiza PR_Vacation.consumeddays2 al inicio (lógica heredada del ERP).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_saldovacaciones_web]
    @company      CHAR(4),
    @payrolltype  VARCHAR(20),
    @date         DATETIME,
    @person       VARCHAR(20),
    @cesados      CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @year           NUMERIC(9, 0);
    DECLARE @actualyear     NUMERIC(9, 0);
    DECLARE @consumo        NUMERIC(9, 4);
    DECLARE @faltas         INT;
    DECLARE @licencias      INT;
    DECLARE @descansos      INT;
    DECLARE @documentnumber VARCHAR(20);
    DECLARE @name           VARCHAR(255);
    DECLARE @fecha          VARCHAR(20);
    DECLARE @inicio         DATETIME;
    DECLARE @inicioProvision DATETIME;
    DECLARE @finProvision   DATETIME;

    IF RTRIM(ISNULL(@person, '')) = '' SET @person = '0';
    IF RTRIM(ISNULL(@cesados, '')) = '' SET @cesados = 'T';

    /* Ajuste de días consumidos considerando vacaciones con inicio posterior a la fecha de corte. */
    UPDATE PR_Vacation
    SET consumeddays2 = consumeddays;

    UPDATE PR_Vacation
    SET consumeddays2 = consumeddays2 - (
            SELECT SUM(Days)
            FROM PR_VacationDetail
            WHERE Person = PR_Vacation.Person
              AND Line = PR_Vacation.Line
              AND Company = PR_Vacation.Company
              AND DateBegin > @date
        )
    WHERE EXISTS (
            SELECT 1
            FROM PR_VacationDetail
            WHERE Person = PR_Vacation.Person
              AND Line = PR_Vacation.Line
              AND Company = PR_Vacation.Company
              AND DateBegin > @date
        );

    SET @descansos = 0;
    DELETE FROM xx_saldovacaciones;

    SET @year = YEAR(@date) + 1;

    INSERT INTO xx_saldovacaciones (company, person, name, entrydate, payrolltype)
    SELECT DISTINCT
        compania,
        DocumentNumber,
        Name,
        CONVERT(VARCHAR(8), entrydate, 112) AS fechaingreso,
        PayRollType
    FROM (
        SELECT
            @company AS compania,
            SY_Person.Person AS DocumentNumber,
            SY_Person.Name,
            ISNULL(PR_Employee.ReEntryDate, PR_Employee.EntryDate) AS entrydate,
            ControlYear,
            CASE
                WHEN CONVERT(VARCHAR(8), DateBeginProvision, 112) <= CONVERT(VARCHAR(8), @date, 112) THEN
                    CASE
                        WHEN CONVERT(VARCHAR(8), DateBeginRights, 112) <= CONVERT(VARCHAR(8), @date, 112) THEN
                            ABS(consumeddays2 - acquireddays)
                        ELSE
                            ROUND((dbo.f_getDias360(DateBeginProvision, @date) * 2.5) / 30, 2) - consumeddays2
                    END
                ELSE 0
            END AS porconsumir,
            PR_Employee.PayRollType AS PayRollType
        FROM PR_Vacation
            INNER JOIN PR_Employee
                ON PR_Vacation.Person = PR_Employee.Person
               AND PR_Employee.Status = 'N'
            INNER JOIN SY_Person
                ON PR_Employee.Person = SY_Person.Person
            INNER JOIN SY_Company
                ON PR_Vacation.Company = SY_Company.Company
        WHERE ControlYear < YEAR(@date) + 1
          AND ControlYear >= YEAR(ISNULL(ReEntryDate, EntryDate))
          AND PR_Employee.PayRollType = @payrolltype
          AND (@person = '0' OR PR_Vacation.Person = @person)
          AND (
                @cesados = 'T'
             OR (@cesados = 'Y' AND PR_Employee.CeaseDate IS NOT NULL)
             OR (@cesados = 'N' AND PR_Employee.CeaseDate IS NULL)
          )
          AND PR_Vacation.Company = @company
          AND ABS(consumeddays2 - acquireddays) > 0
    ) X
    ORDER BY 1, 3;

    DECLARE Vacaciones CURSOR FOR
    SELECT
        DocumentNumber,
        Name,
        CONVERT(VARCHAR(8), entrydate, 112) AS fechaingreso,
        controlyear,
        porconsumir,
        X.inicioProvision,
        X.finProvision
    FROM (
        SELECT
            SY_Company.Description AS compania,
            SY_Person.Person AS DocumentNumber,
            SY_Person.Name,
            ISNULL(PR_Employee.ReEntryDate, PR_Employee.EntryDate) AS entrydate,
            ControlYear,
            CASE
                WHEN CONVERT(VARCHAR(8), DateBeginProvision, 112) <= CONVERT(VARCHAR(8), @date, 112) THEN
                    CASE
                        WHEN CONVERT(VARCHAR(8), DateBeginRights, 112) <= CONVERT(VARCHAR(8), @date, 112) THEN
                            ABS(consumeddays2 - acquireddays)
                        ELSE
                            ROUND((dbo.f_getDias360(DateBeginProvision, @date) * 2.5) / 30, 2) - consumeddays2
                    END
                ELSE 0
            END AS porconsumir,
            PR_Vacation.DateBeginProvision AS inicioProvision,
            PR_Vacation.DateBeginRights AS finProvision
        FROM PR_Vacation
            INNER JOIN PR_Employee
                ON PR_Vacation.Person = PR_Employee.Person
               AND PR_Employee.Status = 'N'
            INNER JOIN SY_Person
                ON PR_Employee.Person = SY_Person.Person
            INNER JOIN SY_Company
                ON PR_Vacation.Company = SY_Company.Company
        WHERE ControlYear < YEAR(@date) + 1
          AND ControlYear >= YEAR(ISNULL(ReEntryDate, EntryDate))
          AND PR_Employee.PayRollType = @payrolltype
          AND PR_Vacation.Company = @company
          AND (@person = '0' OR PR_Vacation.Person = @person)
          AND (
                @cesados = 'T'
             OR (@cesados = 'Y' AND PR_Employee.CeaseDate IS NOT NULL)
             OR (@cesados = 'N' AND PR_Employee.CeaseDate IS NULL)
          )
          AND ABS(consumeddays2 - acquireddays) > 0
    ) X
    ORDER BY 2;

    OPEN Vacaciones;
    FETCH NEXT FROM Vacaciones
        INTO @documentnumber, @name, @fecha, @actualyear, @consumo, @inicioProvision, @finProvision;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        IF @actualyear = @year - 5
            UPDATE xx_saldovacaciones SET saldo1 = @consumo WHERE person = @documentnumber;

        IF @actualyear = @year - 4
            UPDATE xx_saldovacaciones SET saldo2 = @consumo WHERE person = @documentnumber;

        IF @actualyear = @year - 3
            UPDATE xx_saldovacaciones SET saldo3 = @consumo WHERE person = @documentnumber;

        IF @actualyear = @year - 2
            UPDATE xx_saldovacaciones SET saldo4 = @consumo WHERE person = @documentnumber;

        IF @actualyear = @year - 1
            UPDATE xx_saldovacaciones SET saldo5 = @consumo WHERE person = @documentnumber;

        SET @faltas = 0;
        SET @inicio = @fecha;
        WHILE @inicio < @date
        BEGIN
            SET @faltas = @faltas + CASE
                WHEN ISNULL((
                    SELECT COUNT(*)
                    FROM PR_EmployeeMedicalRest
                        INNER JOIN PR_MedicalRestType
                            ON PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
                           AND PR_MedicalRestType.PDT = '07'
                    WHERE PR_EmployeeMedicalRest.Person = @documentnumber
                      AND PR_EmployeeMedicalRest.Company = @company
                      AND @inicio BETWEEN PR_EmployeeMedicalRest.DateBegin AND PR_EmployeeMedicalRest.DateEnd
                ), 0) > 0 THEN 1
                ELSE 0
            END;
            SET @inicio = DATEADD(DD, 1, @inicio);
        END;
        UPDATE xx_saldovacaciones SET faltas = @faltas WHERE person = @documentnumber;

        SET @licencias = 0;
        SET @inicio = @fecha;
        WHILE @inicio <= @date
        BEGIN
            SET @licencias = @licencias + CASE
                WHEN ISNULL((
                    SELECT COUNT(*)
                    FROM PR_EmployeeMedicalRest
                        INNER JOIN PR_MedicalRestType
                            ON PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
                           AND PR_MedicalRestType.PDT = '05'
                    WHERE PR_EmployeeMedicalRest.Person = @documentnumber
                      AND PR_EmployeeMedicalRest.Company = @company
                      AND @inicio BETWEEN PR_EmployeeMedicalRest.DateBegin AND PR_EmployeeMedicalRest.DateEnd
                ), 0) > 0 THEN 1
                ELSE 0
            END;
            SET @inicio = DATEADD(DD, 1, @inicio);
        END;
        UPDATE xx_saldovacaciones SET licencias = @licencias WHERE person = @documentnumber;

        SET @descansos = 0;
        SET @inicio = @inicioProvision;
        WHILE @inicio < @finProvision
        BEGIN
            SET @descansos = @descansos + CASE
                WHEN ISNULL((
                    SELECT COUNT(*)
                    FROM PR_EmployeeMedicalRest
                        INNER JOIN PR_MedicalRestType
                            ON PR_EmployeeMedicalRest.MedicalRestType = PR_MedicalRestType.MedicalRestType
                           AND PR_MedicalRestType.PDT = '20'
                    WHERE PR_EmployeeMedicalRest.Person = @documentnumber
                      AND PR_EmployeeMedicalRest.Company = @company
                      AND @inicio BETWEEN PR_EmployeeMedicalRest.DateBegin AND PR_EmployeeMedicalRest.DateEnd
                ), 0) > 0 THEN 1
                ELSE 0
            END;
            SET @inicio = DATEADD(DD, 1, @inicio);
        END;
        UPDATE xx_saldovacaciones
        SET descansos = ISNULL(descansos, 0) + @descansos
        WHERE person = @documentnumber;

        FETCH NEXT FROM Vacaciones
            INTO @documentnumber, @name, @fecha, @actualyear, @consumo, @inicioProvision, @finProvision;
    END;

    CLOSE Vacaciones;
    DEALLOCATE Vacaciones;

    SELECT
        PR_PayRollType.ShortName AS tipoplanillas,
        xx_saldovacaciones.person AS person,
        xx_saldovacaciones.name,
        SY_ReplicationUnit.Description AS description,
        CONVERT(DATETIME, ISNULL(PR_Employee.ReEntryDate, PR_Employee.EntryDate)) AS entrydate,
        PR_Employee.CeaseDate AS ceasedate,
        ISNULL(saldo1, 0) AS saldo1,
        ISNULL(saldo2, 0) AS saldo2,
        ISNULL(saldo3, 0) AS saldo3,
        ISNULL(saldo4, 0) AS saldo4,
        ISNULL(saldo5, 0) AS saldo5,
        ISNULL(xx_saldovacaciones.faltas, 0) AS faltas,
        ISNULL(xx_saldovacaciones.licencias, 0) AS licencias,
        ISNULL(xx_saldovacaciones.descansos, 0) AS descansos,
        ROUND(
            ISNULL(saldo1, 0) + ISNULL(saldo2, 0) + ISNULL(saldo3, 0) + ISNULL(saldo4, 0) + ISNULL(saldo5, 0)
            - ROUND(ISNULL(xx_saldovacaciones.faltas, 0) * 2.5 / 30.0, 2)
            - ROUND(ISNULL(xx_saldovacaciones.licencias, 0) * 2.5 / 30.0, 2)
            - CASE
                WHEN ISNULL(xx_saldovacaciones.descansos, 0) >= 60
                THEN ROUND(ISNULL(xx_saldovacaciones.descansos, 0) * 2.5 / 30.0, 2)
                ELSE 0
              END,
            2
        ) AS saldo
    FROM xx_saldovacaciones
        INNER JOIN PR_PayRollType
            ON xx_saldovacaciones.payrolltype = PR_PayRollType.PayRollType
        INNER JOIN PR_Employee
            ON xx_saldovacaciones.person = PR_Employee.Person
           AND xx_saldovacaciones.company = PR_Employee.Company
        INNER JOIN SY_Person
            ON xx_saldovacaciones.person = SY_Person.Person
        LEFT JOIN SY_ReplicationUnit
            ON SY_Person.ReplicationUnit = SY_ReplicationUnit.ReplicationUnit
    ORDER BY xx_saldovacaciones.name;
END
GO



-- ============================================================================
-- [63/89] sp_pr_selectorafp_web.sql
-- ============================================================================

/*
    Selector AFP por compañía.

    Usado por: GET /api/selectores/afp?cia=...
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorafp_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(A.AFP)) AS id,
        LTRIM(RTRIM(ISNULL(A.Description, A.AFP))) AS text
    FROM PR_AFP A (NOLOCK)
    WHERE
        @cia = ''
        OR LTRIM(RTRIM(ISNULL(A.Company, ''))) = ''
        OR LTRIM(RTRIM(A.Company)) = @cia
    ORDER BY text ASC;
END
GO



-- ============================================================================
-- [64/89] sp_pr_selectorbancos_web.sql
-- ============================================================================

/*
    Selector de bancos activos por compañía (ERP_Bank).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorbancos_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ERP_Bank.Bank AS bank,
        ERP_Bank.Name AS name
    FROM ERP_Bank
    WHERE ERP_Bank.status = 'A'
      AND ERP_Bank.Company = @cia
    ORDER BY ERP_Bank.Name ASC;
END
GO



-- ============================================================================
-- [65/89] sp_pr_selectorcompanias_web.sql
-- ============================================================================

/*
    Selector de compañías activas (SY_Company).
    Usado por: GET /api/selectores/companias (PLAME, reportes, trabajadores, etc.).

    id: Company
    text: description
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorcompanias_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        Company,
        description
    FROM SY_Company (NOLOCK)
    WHERE status = 'A'
    ORDER BY Company ASC;
END
GO



-- ============================================================================
-- [66/89] sp_pr_selectorconceptoneto_web.sql
-- ============================================================================

/*
    Concepto por defecto para Pago de haberes: Neto a recibir (FormulaCode = NETO).
    Usado por: GET /api/selectores/concepto-neto

    Parámetros:
      @cia — compañía (obligatorio).

    Retorna una fila con concept y description, o vacío si no existe.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorconceptoneto_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        LTRIM(RTRIM(PR_CONCEPT.CONCEPT)) AS concept,
        LTRIM(RTRIM(PR_CONCEPT.DESCRIPTION)) AS description
    FROM PR_CONCEPT
    WHERE PR_CONCEPT.STATUS = 'A'
      AND PR_CONCEPT.COMPANY = @cia
      AND UPPER(LTRIM(RTRIM(PR_CONCEPT.FormulaCode))) = 'NETO'
    ORDER BY PR_CONCEPT.CONCEPT;
END
GO



-- ============================================================================
-- [67/89] sp_pr_selectorconceptos_web.sql
-- ============================================================================

/*
    Selector de conceptos activos por compañía.
    Retorna CONCEPT (código) y DESCRIPTION (texto visible).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorconceptos_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        PR_CONCEPT.CONCEPT AS concept,
        PR_CONCEPT.DESCRIPTION AS description
    FROM PR_CONCEPT
    WHERE PR_CONCEPT.STATUS = 'A'
      AND PR_CONCEPT.COMPANY = @cia
    ORDER BY PR_CONCEPT.DESCRIPTION ASC;
END
GO



-- ============================================================================
-- [68/89] sp_pr_selectorconcepttype_web.sql
-- ============================================================================

/*
    Selector de tipos de concepto.
    Usado por: GET /api/selectores/concept-types
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorconcepttype_web]
    @cia VARCHAR(4) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = NULLIF(LTRIM(RTRIM(ISNULL(@cia, ''))), '');

    SELECT
        T.ConceptType AS id,
        LTRIM(RTRIM(
            ISNULL(T.Description, T.ConceptType) +
            CASE WHEN ISNULL(T.ShortName, '') <> ''
                 THEN ' (' + T.ShortName + ')'
                 ELSE ''
            END
        )) AS text,
        T.ShortName AS shortname
    FROM PR_ConceptType T (NOLOCK)
    WHERE @cia IS NULL
       OR T.Company = @cia
       OR T.Company IS NULL
       OR LTRIM(RTRIM(ISNULL(T.Company, ''))) = ''
    ORDER BY
        T.ORDEN,
        T.Description;
END
GO



-- ============================================================================
-- [69/89] sp_pr_selectorformapago_web.sql
-- ============================================================================

/*
    Selector de formas de pago (TE_CollectionForm) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorformapago_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        cf.collectionform AS id,
        LTRIM(RTRIM(ISNULL(cf.description, cf.name))) AS text
    FROM te_collectionform cf
    WHERE cf.status = 'A'
      AND cf.company = @cia
    ORDER BY cf.description ASC;
END
GO



-- ============================================================================
-- [70/89] sp_pr_selectorpensiontype_web.sql
-- ============================================================================

/*
    Selector de régimen de pensión (PR_PensionType) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorpensiontype_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(P.PensionType)) AS id,
        LTRIM(RTRIM(ISNULL(P.Description, P.PensionType))) AS text
    FROM PR_PensionType P (NOLOCK)
    WHERE
        @cia = ''
        OR LTRIM(RTRIM(ISNULL(P.Company, ''))) = ''
        OR LTRIM(RTRIM(P.Company)) = @cia
    ORDER BY text ASC;
END
GO



-- ============================================================================
-- [71/89] sp_pr_selectorperiodoactivo_planilla_web.sql
-- ============================================================================

/*
    Periodo activo más reciente entre todos los procesos de una planilla.
    Usado por: GET /api/aperturar-periodos/periodo-sugerido
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodoactivo_planilla_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        LTRIM(RTRIM(pc.PRPeriod)) AS prperiod
    FROM PR_ProcessControl pc WITH (NOLOCK)
    WHERE pc.Company = @cia
      AND pc.PayRollType = @payrolltype
      AND pc.Status IN ('A', 'G')
    ORDER BY pc.PRPeriod DESC;
END
GO



-- ============================================================================
-- [72/89] sp_pr_selectorperiodoactivo_web.sql
-- ============================================================================

/*
    Periodo activo del proceso (PR_ProcessControl, Status = 'A').
    Usado por: GET /api/selectores/periodo-activo (reporte resumen total y similares).

    Parámetros:
      @cia, @payrolltype, @processtype — obligatorios.

    Retorna una fila con prperiod o vacío si no hay periodo activo.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodoactivo_web]
    @cia         VARCHAR(10),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP 1
        LTRIM(RTRIM(PRPeriod)) AS prperiod
    FROM PR_ProcessControl
    WHERE Company = @cia
      AND PayRollType = @payrolltype
      AND ProcessType = @processtype
      AND Status = 'A'
    ORDER BY PRPeriod DESC;
END
GO



-- ============================================================================
-- [73/89] sp_pr_selectorperiodocalculo_web.sql
-- ============================================================================

/*
    Selector de periodos de cálculo por compañía y proceso.
    Periodos abiertos o cerrados en PR_ProcessControl (status A, C, G).
    Usado por: GET /api/procesar-planilla/periodos-calculo (procesar_planilla.html).

    processtype, prperiod, description, company
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodocalculo_web]
    @cia         VARCHAR(4),
    @processtype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));

    SELECT DISTINCT
        PC.ProcessType AS processtype,
        PC.PRPeriod AS prperiod,
        SUBSTRING(PC.PRPeriod, 1, 4) + '-'
            + SUBSTRING(PC.PRPeriod, 5, 2) + '-'
            + SUBSTRING(PC.PRPeriod, 7, 2) AS description,
        PC.Company AS company
    FROM PR_ProcessControl PC (NOLOCK)
    WHERE PC.Status IN ('A', 'C', 'G')
      AND PC.Company = @cia
      AND PC.ProcessType = @processtype
    ORDER BY PC.PRPeriod DESC;
END
GO



-- ============================================================================
-- [74/89] sp_pr_selectorperiodos_apertura_web.sql
-- ============================================================================

/*
    Periodos configurados para apertura (PR_Period).
    Usado por: GET /api/aperturar-periodos/periodos
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_apertura_web]
    @cia         VARCHAR(20),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT
        LTRIM(RTRIM(p.PRPeriod)) AS prperiod,
        CASE
            WHEN LEN(LTRIM(RTRIM(p.PRPeriod))) >= 8
                THEN STUFF(STUFF(LTRIM(RTRIM(p.PRPeriod)), 5, 0, '-'), 8, 0, '-')
            WHEN LEN(LTRIM(RTRIM(p.PRPeriod))) >= 6
                THEN STUFF(LTRIM(RTRIM(p.PRPeriod)), 5, 0, '-')
            ELSE LTRIM(RTRIM(p.PRPeriod))
        END AS description
    FROM PR_Period p WITH (NOLOCK)
    WHERE p.Company = @cia
      AND p.PayRollType = @payrolltype
    ORDER BY p.PRPeriod DESC;
END
GO



-- ============================================================================
-- [75/89] sp_pr_selectorperiodos_plame_web.sql
-- ============================================================================

/*
    Periodos tributarios PLAME por compañía (YYYY-MM).
    Usado por: GET /api/selectores/periodos-plame (plame_archivo14.html y otros).

    id (prperiod): YYYYMM — se envía al listado/generación PLAME.
    text (description): YYYY-MM — etiqueta en el selector.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_plame_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        SUBSTRING(pr_period.prperiod, 1, 4) + '-' + SUBSTRING(pr_period.prperiod, 5, 2) AS description,
        SUBSTRING(pr_period.prperiod, 1, 4) + SUBSTRING(pr_period.prperiod, 5, 2) AS prperiod,
        pr_period.company AS company
    FROM PR_Period pr_period (NOLOCK)
    WHERE SUBSTRING(pr_period.prperiod, 1, 4) <= CONVERT(VARCHAR(4), DATEADD(YEAR, 1, GETDATE()), 112)
      AND pr_period.company = @cia
    ORDER BY description DESC;
END
GO



-- ============================================================================
-- [76/89] sp_pr_selectorperiodos_web.sql
-- ============================================================================

/*
    Selector de periodos por compañía, planilla y proceso (PR_ProcessControl).
    Usado por: GET /api/selectores/periodos (reportes, procesar planilla, etc.).

    id: period (PRPERIOD)
    text: periodo (YYYY-MM-DD)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorperiodos_web]
    @cia VARCHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));

    SELECT
        PC.ProcessType AS processtype,
        PC.PayRollType AS payrolltype,
        PC.PRPeriod AS period,
        SUBSTRING(PC.PRPeriod, 1, 4) + '-'
            + SUBSTRING(PC.PRPeriod, 5, 2) + '-'
            + SUBSTRING(PC.PRPeriod, 7, 2) AS periodo,
        PC.Company AS company
    FROM PR_ProcessControl PC (NOLOCK)
    WHERE PC.Status IN ('A', 'C', 'G')
      AND PC.Company = @cia
      AND PC.PayRollType = @payrolltype
      AND PC.ProcessType = @processtype
    ORDER BY PC.PRPeriod DESC;
END
GO



-- ============================================================================
-- [77/89] sp_pr_selectorplanillas_web.sql
-- ============================================================================

/*
    Selector de tipos de planilla por compañía (PR_PayRollType).
    Usado por: GET /api/selectores/planillas (reportes, procesar planilla, etc.).

    id: payrolltype
    text: tipoplanilla (description)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorplanillas_web]
    @cia VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        PR_PayRollType.PayRollType AS payrolltype,
        PR_PayRollType.Description AS tipoplanilla
    FROM PR_PayRollType (NOLOCK)
    WHERE PR_PayRollType.Company = @cia
    ORDER BY PR_PayRollType.Description ASC;
END
GO



-- ============================================================================
-- [78/89] sp_pr_selectorprocesos_web.sql
-- ============================================================================

/*
    Selector de procesos por compañía y tipo de planilla.
    Usado por: GET /api/selectores/procesos (reportes, procesar planilla, etc.).

    id: processtype
    text: proceso (PR_ProcessType.Description)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorprocesos_web]
    @cia VARCHAR(4),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT
        PTP.ProcessType AS processtype,
        PTP.PayRollType AS payrolltype,
        PTP.Company AS company,
        PT.Description AS proceso
    FROM PR_PayRollTypeProcess PTP (NOLOCK)
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PTP.ProcessType = PT.ProcessType
           AND PTP.Company = PT.Company
    WHERE PTP.Company = @cia
      AND PTP.PayRollType = @payrolltype
    ORDER BY PT.Description ASC;
END
GO



-- ============================================================================
-- [79/89] sp_pr_selectorprocesoscalculo_web.sql
-- ============================================================================

/*
    Selector de procesos de cálculo por compañía y tipo de planilla.
    Filtra procesos habilitados en PR_WindowProcess y shortname de cálculo.
    Usado por: POST /api/procesar-planilla/procesos-calculo (procesar_planilla.html).

    processtype, payrolltype, company, description
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorprocesoscalculo_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));

    SELECT DISTINCT
        PTP.ProcessType AS processtype,
        PTP.PayRollType AS payrolltype,
        PTP.Company AS company,
        PT.Description AS description
    FROM PR_PayRollTypeProcess PTP (NOLOCK)
        INNER JOIN PR_ProcessType PT (NOLOCK)
            ON PTP.ProcessType = PT.ProcessType
           AND PTP.Company = PT.Company
        INNER JOIN PR_WindowProcess WP (NOLOCK)
            ON WP.ProcessType = PT.ProcessType
    WHERE PTP.Company = @cia
      AND PTP.PayRollType = @payrolltype
      AND PT.ShortName IN (
            'CTS',
            'FIN_DE_MES',
            'LIQUIDACION',
            'VACACIONES',
            'QUINCENA',
            'PROVISION_CTS',
            'PROVISION_VACACIONES',
            'PROVISION_GRATIF'
        )
    ORDER BY PT.Description ASC;
END
GO



-- ============================================================================
-- [80/89] sp_pr_selectorregimehealth_web.sql
-- ============================================================================

/*
    Selector de régimen de aseguramiento de salud (PR_RegimeHealth) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorregimehealth_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(R.RegimeHealth)) AS id,
        LTRIM(RTRIM(ISNULL(R.Description, R.RegimeHealth))) AS text
    FROM PR_RegimeHealth R (NOLOCK)
    WHERE
        @cia = ''
        OR LTRIM(RTRIM(ISNULL(R.Company, ''))) = ''
        OR LTRIM(RTRIM(R.Company)) = @cia
    ORDER BY text ASC;
END
GO



-- ============================================================================
-- [81/89] sp_pr_selectorsctrpension_web.sql
-- ============================================================================

/*
    Selector SCTR Pensión (PR_SCTR con SCTRType = 'P').
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorsctrpension_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));

    SELECT
        LTRIM(RTRIM(S.SCTR)) AS id,
        LTRIM(RTRIM(ISNULL(S.Description, S.SCTR))) AS text
    FROM PR_SCTR S (NOLOCK)
    WHERE LTRIM(RTRIM(ISNULL(S.SCTRType, ''))) = 'P'
      AND (
            @cia = ''
            OR LTRIM(RTRIM(ISNULL(S.Company, ''))) = ''
            OR LTRIM(RTRIM(S.Company)) = @cia
          )
    ORDER BY text ASC;
END
GO



-- ============================================================================
-- [82/89] sp_pr_selectortipocuenta_web.sql
-- ============================================================================

/*
    Selector de tipos de cuenta (TE_AccountType) por compañía.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectortipocuenta_web]
    @cia VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        tat.accounttype AS id,
        LTRIM(RTRIM(tat.description)) AS text
    FROM te_accounttype tat
    WHERE tat.company = @cia
    ORDER BY tat.description ASC;
END
GO



-- ============================================================================
-- [83/89] sp_pr_selectorunidades_web.sql
-- ============================================================================

/*
    Selector de unidades de replicación activas (SY_ReplicationUnit).
    Usado por: GET /api/selectores/unidades (asignacion_conceptos.html y otros).
    Campo en persona: SY_Person.ReplicationUnit.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorunidades_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        SY_ReplicationUnit.ReplicationUnit AS replicationunit,
        SY_ReplicationUnit.Description AS description
    FROM SY_ReplicationUnit
    WHERE SY_ReplicationUnit.status = 'A'
    ORDER BY SY_ReplicationUnit.Description ASC;
END
GO



-- ============================================================================
-- [84/89] sp_pr_trabajadores_sin_regimen_pension_afp_web.sql
-- ============================================================================

/*
    Trabajadores de la planilla del periodo sin régimen de pensión (ONP/AFP).
    Usado por validaciones del reporte Declaración AFP / AFPnet.

    Sin régimen: PensionType vacío o PR_PensionType.PDT = '99' (sin régimen pensionario).
    Alcance: trabajadores con conceptos de planilla en el periodo (@period YYYYMM).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_trabajadores_sin_regimen_pension_afp_web]
    @cia         VARCHAR(10),
    @period      VARCHAR(20),
    @payroll_all CHAR(1)     = 'Y',
    @payroll     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @period = LEFT(LTRIM(RTRIM(ISNULL(@period, ''))), 6);
    SET @payroll_all = UPPER(LTRIM(RTRIM(ISNULL(@payroll_all, 'Y'))));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));

    IF @payroll_all NOT IN ('Y', 'N') SET @payroll_all = 'Y';

    SELECT DISTINCT
        LTRIM(RTRIM(E.person)) AS person,
        LTRIM(RTRIM(ISNULL(P.documentnumber, ''))) AS documentnumber,
        LTRIM(RTRIM(
            ISNULL(P.lastname1, '') + ' ' +
            ISNULL(P.lastname2, '') + ' ' +
            ISNULL(P.name1, '') + ' ' +
            ISNULL(P.name2, '')
        )) AS nombre,
        LTRIM(RTRIM(ISNULL(E.pensiontype, ''))) AS pensiontype,
        LTRIM(RTRIM(ISNULL(PT.description, ''))) AS pensiontype_desc,
        LTRIM(RTRIM(ISNULL(PT.pdt, ''))) AS pension_pdt
    FROM PR_Employee E (NOLOCK)
        INNER JOIN SY_Person P (NOLOCK)
            ON P.person = E.person
        LEFT JOIN PR_PensionType PT (NOLOCK)
            ON PT.PensionType = E.PensionType
           AND (
                LTRIM(RTRIM(ISNULL(PT.Company, ''))) = ''
                OR LTRIM(RTRIM(PT.Company)) = E.Company
           )
    WHERE E.Company = @cia
      AND EXISTS (
            SELECT 1
            FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            WHERE EPC.Company = @cia
              AND EPC.Person = E.person
              AND LEFT(EPC.PRPeriod, 6) = @period
              AND (@payroll_all = 'Y' OR EPC.PayRollType = @payroll)
      )
      AND (
            LTRIM(RTRIM(ISNULL(E.PensionType, ''))) = ''
            OR LTRIM(RTRIM(ISNULL(PT.PDT, ''))) = '99'
      )
    ORDER BY nombre, person;
END
GO



-- ============================================================================
-- [85/89] sp_pr_vacaciones_eliminar_detalle_web.sql
-- ============================================================================

/*
    Elimina un registro de PR_VacationDetail y PR_VacationPay;
    recalcula consumeddays en PR_Vacation.
    Usado por: POST /api/vacaciones/eliminar-detalle (registro_vacaciones.html).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_vacaciones_eliminar_detalle_web]
    @company   VARCHAR(4),
    @person    VARCHAR(20),
    @line      INT,
    @secuence  INT,
    @xlastuser VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_VacationDetail
        WHERE company = @company
          AND person = @person
          AND line = @line
          AND Secuence = @secuence
    )
    BEGIN
        RAISERROR('No se encontró el registro de utilización.', 16, 1);
        RETURN;
    END;

    DELETE FROM PR_VacationPay
    WHERE company = @company
      AND person = @person
      AND line = @line
      AND Secuence = @secuence;

    DELETE FROM PR_VacationDetail
    WHERE company = @company
      AND person = @person
      AND line = @line
      AND Secuence = @secuence;

    UPDATE PR_Vacation
    SET consumeddays = (
            SELECT ISNULL(SUM(Days), 0)
            FROM PR_VacationDetail
            WHERE Person = @person
              AND Company = @company
              AND line = @line
        ),
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE company = @company
      AND person = @person
      AND line = @line;

    SELECT 1 AS ok;
END
GO



-- ============================================================================
-- [86/89] sp_pr_vacaciones_guardar_detalle_web.sql
-- ============================================================================

/*
    Alta de registro en PR_VacationDetail y PR_VacationPay;
    actualización de consumeddays en PR_Vacation.
    Usado por: POST /api/vacaciones/guardar-detalle (registro_vacaciones.html).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_vacaciones_guardar_detalle_web]
    @company       VARCHAR(4),
    @person        VARCHAR(20),
    @line          INT,
    @prperiod      VARCHAR(10),
    @datebegin     DATETIME,
    @dateend       DATETIME,
    @days          INT = NULL,
    @vacationtype  CHAR(1) = 'D',
    @xlastuser     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @secuence        INT;
    DECLARE @acquireddays    INT;
    DECLARE @consumeddays    INT;
    DECLARE @pendientes      INT;
    DECLARE @dias_nuevos     INT;
    DECLARE @replicationunit VARCHAR(4);

    IF @datebegin IS NULL OR @dateend IS NULL
    BEGIN
        RAISERROR('Indique fecha de inicio y término.', 16, 1);
        RETURN;
    END;

    IF @dateend < @datebegin
    BEGIN
        RAISERROR('La fecha de término no puede ser anterior a la de inicio.', 16, 1);
        RETURN;
    END;

    IF RTRIM(ISNULL(@prperiod, '')) = ''
    BEGIN
        RAISERROR('Seleccione el periodo de consumo efectivo.', 16, 1);
        RETURN;
    END;

    /* Normalizar y resolver periodo completo (YYYYMMDD) desde PR_Period. */
    DECLARE @prperiod_digits VARCHAR(10);
    DECLARE @prperiod_full   VARCHAR(10);

    SET @prperiod_digits = REPLACE(REPLACE(LTRIM(RTRIM(@prperiod)), '-', ''), '/', '');
    SET @prperiod_full = @prperiod_digits;

    IF LEN(@prperiod_digits) = 6 AND @prperiod_digits NOT LIKE '%[^0-9]%'
    BEGIN
        SELECT TOP 1 @prperiod_full = p.prperiod
        FROM PR_Period p
            INNER JOIN PR_Employee e
                ON e.company = @company
               AND e.person = @person
        WHERE p.company = @company
          AND p.payrolltype = e.payrolltype
          AND LEFT(p.prperiod, 6) = @prperiod_digits
        ORDER BY p.prperiod DESC;

        IF RTRIM(ISNULL(@prperiod_full, '')) = ''
        BEGIN
            SELECT TOP 1 @prperiod_full = prperiod
            FROM PR_Period
            WHERE company = @company
              AND LEFT(prperiod, 6) = @prperiod_digits
            ORDER BY prperiod DESC;
        END
    END
    ELSE IF LEN(@prperiod_digits) >= 8 AND @prperiod_digits NOT LIKE '%[^0-9]%'
    BEGIN
        SET @prperiod_full = LEFT(@prperiod_digits, 8);
    END;

    IF RTRIM(ISNULL(@prperiod_full, '')) = ''
       OR LEN(@prperiod_full) < 8
       OR @prperiod_full LIKE '%[^0-9]%'
    BEGIN
        RAISERROR('No se encontró el periodo de consumo efectivo en PR_Period.', 16, 1);
        RETURN;
    END;

    SET @prperiod = @prperiod_full;

    SET @vacationtype = UPPER(LTRIM(RTRIM(ISNULL(@vacationtype, 'D'))));
    IF @vacationtype NOT IN ('D', 'V', 'X') SET @vacationtype = 'D';

    SET @dias_nuevos = ISNULL(@days, DATEDIFF(DAY, @datebegin, @dateend) + 1);
    IF @dias_nuevos <= 0
    BEGIN
        RAISERROR('El rango de fechas debe generar al menos 1 día.', 16, 1);
        RETURN;
    END;

    SELECT
        @acquireddays = ISNULL(AcquiredDays, 0),
        @consumeddays = ISNULL(consumeddays, 0)
    FROM PR_Vacation
    WHERE company = @company
      AND person = @person
      AND line = @line;

    IF @acquireddays IS NULL
    BEGIN
        RAISERROR('No se encontró el periodo vacacional seleccionado.', 16, 1);
        RETURN;
    END;

    SET @pendientes = ABS(@consumeddays - @acquireddays);
    IF (@consumeddays + @dias_nuevos) > @acquireddays
    BEGIN
        RAISERROR('Los días solicitados superan el saldo pendiente del periodo (%d día(s)).', 16, 1, @pendientes);
        RETURN;
    END;

    SELECT @secuence = ISNULL(MAX(Secuence), 0) + 1
    FROM PR_VacationDetail
    WHERE company = @company
      AND person = @person
      AND line = @line;

    SELECT @replicationunit = ISNULL(ReplicationUnit, @company)
    FROM PR_Employee
    WHERE company = @company
      AND person = @person;

    INSERT INTO PR_VacationDetail (
        Person, Company, line, Secuence,
        prperiod, Datebegin, Dateend, Days,
        VacationType, ReplicationUnit, XLastUser, XLastDate
    )
    VALUES (
        @person, @company, @line, @secuence,
        @prperiod, @datebegin, @dateend, @dias_nuevos,
        @vacationtype, @replicationunit, @xlastuser, GETDATE()
    );

    INSERT INTO PR_VacationPay (
        Person, Company, line, Secuence,
        Datebegin, Dateend, Days, PRPeriod,
        VacationType, Status, ReplicationUnit,
        XLastUser, XLastDate
    )
    VALUES (
        @person, @company, @line, @secuence,
        @datebegin, @dateend, @dias_nuevos, @prperiod,
        @vacationtype, 'A', @replicationunit,
        @xlastuser, GETDATE()
    );

    UPDATE PR_Vacation
    SET consumeddays = (
            SELECT ISNULL(SUM(Days), 0)
            FROM PR_VacationDetail
            WHERE Person = @person
              AND Company = @company
              AND line = @line
        ),
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE company = @company
      AND person = @person
      AND line = @line;

    SELECT
        @secuence AS secuence,
        @dias_nuevos AS dias,
        @pendientes - @dias_nuevos AS pendientes_restantes;
END
GO



-- ============================================================================
-- [87/89] sp_pr_vacaciones_listar_trabajadores_web.sql
-- ============================================================================

/*
    Listado de trabajadores activos para el módulo Registro de Vacaciones.
    Usado por: POST /api/vacaciones/trabajadores (registro_vacaciones.html).

    Parámetros:
      @company     — obligatorio.
      @payrolltype — '0' = todos los tipos de planilla.
      @busqueda    — filtro opcional por nombre o documento.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_vacaciones_listar_trabajadores_web]
    @company     VARCHAR(4),
    @payrolltype VARCHAR(20) = '0',
    @busqueda    VARCHAR(100) = ''
AS
BEGIN
    SET NOCOUNT ON;

    IF RTRIM(ISNULL(@payrolltype, '')) = '' SET @payrolltype = '0';
    SET @busqueda = LTRIM(RTRIM(ISNULL(@busqueda, '')));

    SELECT
        PR_EMPLOYEE.PERSON AS person,
        PR_EMPLOYEE.EMPLOYEECODE AS codigo,
        LTRIM(RTRIM(
            ISNULL(SY_PERSON.LASTNAME1, '') + ' ' +
            ISNULL(SY_PERSON.LASTNAME2, '') + ' ' +
            ISNULL(SY_PERSON.NAME1, '') + ' ' +
            ISNULL(SY_PERSON.NAME2, '')
        )) AS nombre,
        SY_PERSON.DOCUMENTNUMBER AS documento,
        ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS fechaingreso,
        PR_EMPLOYEE.PAYROLLTYPE AS payrolltype,
        PR_PAYROLLTYPE.DESCRIPTION AS tipoplanilla
    FROM PR_EMPLOYEE
        INNER JOIN SY_PERSON
            ON PR_EMPLOYEE.PERSON = SY_PERSON.PERSON
        LEFT JOIN PR_PAYROLLTYPE
            ON PR_EMPLOYEE.PAYROLLTYPE = PR_PAYROLLTYPE.PAYROLLTYPE
    WHERE PR_EMPLOYEE.COMPANY = @company
      AND PR_EMPLOYEE.STATUS = 'N'
      AND PR_EMPLOYEE.CEASEDATE IS NULL
      AND (@payrolltype = '0' OR PR_EMPLOYEE.PAYROLLTYPE = @payrolltype)
      AND (
            @busqueda = ''
         OR SY_PERSON.DOCUMENTNUMBER LIKE '%' + @busqueda + '%'
         OR LTRIM(RTRIM(
                ISNULL(SY_PERSON.LASTNAME1, '') + ' ' +
                ISNULL(SY_PERSON.LASTNAME2, '') + ' ' +
                ISNULL(SY_PERSON.NAME1, '') + ' ' +
                ISNULL(SY_PERSON.NAME2, '')
            )) LIKE '%' + @busqueda + '%'
         OR PR_EMPLOYEE.EMPLOYEECODE LIKE '%' + @busqueda + '%'
      )
    ORDER BY nombre;
END
GO



-- ============================================================================
-- [88/89] sp_pr_vacaciones_obtener_trabajador_web.sql
-- ============================================================================

/*
    Datos de vacaciones de un trabajador para Registro de Vacaciones.
    Usado por: POST /api/vacaciones/obtener (registro_vacaciones.html).

    Devuelve 4 resultsets:
      1) Datos del empleado
      2) Resumen de saldo (acumulados, gozados, pendientes)
      3) Periodos vacacionales (PR_Vacation)
      4) Detalle de utilización (PR_VacationDetail)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_vacaciones_obtener_trabajador_web]
    @company VARCHAR(4),
    @person  VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    /* 1) Empleado */
    SELECT
        PR_EMPLOYEE.PERSON AS person,
        PR_EMPLOYEE.EMPLOYEECODE AS codigo,
        LTRIM(RTRIM(
            ISNULL(SY_PERSON.LASTNAME1, '') + ' ' +
            ISNULL(SY_PERSON.LASTNAME2, '') + ' ' +
            ISNULL(SY_PERSON.NAME1, '') + ' ' +
            ISNULL(SY_PERSON.NAME2, '')
        )) AS nombre,
        SY_PERSON.DOCUMENTNUMBER AS documento,
        ISNULL(PR_EMPLOYEE.REENTRYDATE, PR_EMPLOYEE.ENTRYDATE) AS fechaingreso,
        PR_EMPLOYEE.PAYROLLTYPE AS payrolltype,
        PR_PAYROLLTYPE.DESCRIPTION AS tipoplanilla
    FROM PR_EMPLOYEE
        INNER JOIN SY_PERSON
            ON PR_EMPLOYEE.PERSON = SY_PERSON.PERSON
        LEFT JOIN PR_PAYROLLTYPE
            ON PR_EMPLOYEE.PAYROLLTYPE = PR_PAYROLLTYPE.PAYROLLTYPE
    WHERE PR_EMPLOYEE.COMPANY = @company
      AND PR_EMPLOYEE.PERSON = @person;

    /* 2) Resumen */
    SELECT
        ISNULL(SUM(CASE WHEN v.status = 'A' THEN ISNULL(v.AcquiredDays, 0) ELSE 0 END), 0) AS dias_acumulados,
        ISNULL(SUM(CASE WHEN v.status = 'A' THEN ISNULL(v.consumeddays, 0) ELSE 0 END), 0) AS dias_gozados,
        ISNULL(SUM(
            CASE
                WHEN v.status = 'A' THEN ABS(ISNULL(v.consumeddays, 0) - ISNULL(v.AcquiredDays, 0))
                ELSE 0
            END
        ), 0) AS dias_pendientes
    FROM PR_Vacation v
    WHERE v.company = @company
      AND v.person = @person;

    /* 3) Periodos vacacionales */
    SELECT
        v.line,
        v.controlyear,
        CAST(v.controlyear AS VARCHAR(4)) + '-' + CAST(CAST(v.controlyear AS INT) + 1 AS VARCHAR(4)) AS periodo,
        ISNULL(v.days, 0) AS dias,
        ISNULL(v.AcquiredDays, 0) AS dias_adquiridos,
        ISNULL(v.consumeddays, 0) AS consumidos,
        ABS(ISNULL(v.consumeddays, 0) - ISNULL(v.AcquiredDays, 0)) AS pendientes,
        ISNULL(v.payeddays, 0) AS pagados,
        ISNULL(v.AcquiredDays, 0) - ISNULL(v.payeddays, 0) AS por_pagar,
        v.DateBeginProvision AS inicio_provision,
        v.DateBeginRights AS inicio_derecho,
        v.DateEndRights AS fin_derecho,
        v.DateEndNormal AS limite_sin_indemnizacion,
        v.status,
        CASE v.status WHEN 'A' THEN 'Activo' WHEN 'I' THEN 'Inactivo' ELSE v.status END AS estado_texto,
        v.XLastUser AS usuario,
        v.XLastDate AS fecha_modificacion
    FROM PR_Vacation v
    WHERE v.company = @company
      AND v.person = @person
    ORDER BY v.controlyear DESC;

    /* 4) Detalle de utilización */
    SELECT
        d.line,
        d.secuence,
        d.prperiod,
        CASE
            WHEN LEN(LTRIM(RTRIM(ISNULL(d.prperiod, '')))) >= 6
                 AND SUBSTRING(d.prperiod, 1, 6) NOT LIKE '%[^0-9]%'
            THEN SUBSTRING(d.prperiod, 1, 4) + '-' + SUBSTRING(d.prperiod, 5, 2)
            ELSE d.prperiod
        END AS consumo_efectivo,
        d.datebegin AS fecha_inicio,
        d.dateend AS fecha_fin,
        ISNULL(d.days, 0) AS dias,
        d.vacationtype,
        CASE d.vacationtype
            WHEN 'D' THEN 'Descanso'
            WHEN 'V' THEN 'Venta'
            WHEN 'X' THEN 'No Remunerada'
            ELSE d.vacationtype
        END AS tipo_texto,
        d.XLastUser AS usuario,
        d.XLastDate AS fecha_modificacion
    FROM PR_VacationDetail d
    WHERE d.company = @company
      AND d.person = @person
    ORDER BY d.datebegin ASC;
END
GO



-- ============================================================================
-- [89/89] sp_pr_validar_calculo_web.sql
-- ============================================================================

/*
    Validaciones post-cálculo de planilla (módulo Procesar planilla).

    Usado por: POST /api/procesar-planilla/validar-calculo
    y al finalizar /ejecutar_calculo_streaming.

    Basado en: sp_pr_validar_calculo (legacy).

    Parámetros:
      @cia         — compañía
      @payrolltype — tipo de planilla
      @processtype — proceso
      @period      — periodo PRPeriod (ej. 20260505)

    Solo valida trabajadores con ingreso/reingreso <= ultimo dia del mes del periodo.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_validar_calculo_web]
    @cia         VARCHAR(10),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    DECLARE @fecha_fin_mes DATE;
    DECLARE @period_ym CHAR(6);

    SET @period_ym = LEFT(@period, 6);
    IF LEN(@period_ym) = 6 AND @period_ym NOT LIKE '%[^0-9]%'
        SET @fecha_fin_mes = EOMONTH(CONVERT(DATE, @period_ym + '01', 112));

    CREATE TABLE #errores (
        person      VARCHAR(20) NULL,
        name        VARCHAR(200) NULL,
        observacion VARCHAR(500) NOT NULL
    );

    CREATE TABLE #lista_rem_basica (
        person VARCHAR(20) NOT NULL PRIMARY KEY
    );

    CREATE TABLE #empleados_periodo (
        person VARCHAR(20) NOT NULL PRIMARY KEY
    );

    INSERT INTO #empleados_periodo (person)
    SELECT E.Person
    FROM PR_Employee E (NOLOCK)
    WHERE E.Company = @cia
      AND E.PayRollType = @payrolltype
      AND E.Status = 'N'
      AND (
            @fecha_fin_mes IS NULL
            OR CONVERT(DATE, ISNULL(E.ReEntryDate, E.EntryDate)) <= @fecha_fin_mes
          );

    INSERT INTO #lista_rem_basica (person)
    SELECT EC.Person
    FROM PR_EmployeeConcept EC (NOLOCK)
        INNER JOIN #empleados_periodo EP ON EC.Person = EP.person
        INNER JOIN PR_Concept C (NOLOCK)
            ON EC.Concept = C.Concept
           AND C.Company = @cia
    WHERE EC.Company = @cia
      AND EC.PayRollType = @payrolltype
      AND C.FormulaCode = 'REM_BASICA'
      AND EC.FlagFrecuencyType IN ('P', 'T')
      AND (
            (EC.FlagFrecuencyType = 'P' AND EC.PRPeriodStart <= @period)
            OR (EC.FlagFrecuencyType = 'T' AND @period BETWEEN EC.PRPeriodStart AND ISNULL(EC.PRPeriodEnd, EC.PRPeriodStart))
          )
      AND (
            EC.FlagFrecuencyType = 'T'
            OR (
                EC.FlagFrecuencyType = 'P'
                AND EC.PRPeriodStart = (
                    SELECT MAX(T.PRPeriodStart)
                    FROM PR_EmployeeConcept T (NOLOCK)
                    WHERE T.Company = EC.Company
                      AND T.Person = EC.Person
                      AND T.Concept = EC.Concept
                      AND T.PayRollType = EC.PayRollType
                )
            )
          )
    GROUP BY EC.Person;

    INSERT INTO #errores (person, name, observacion)
    SELECT
        E.Person,
        LTRIM(RTRIM(
            ISNULL(P.LastName1, '') + ' ' +
            ISNULL(P.LastName2, '') + ' ' +
            ISNULL(P.Name1, '') + ' ' +
            ISNULL(P.Name2, '')
        )),
        'No registra Remuneración Básica'
    FROM PR_Employee E (NOLOCK)
        INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
        INNER JOIN #empleados_periodo EP ON E.Person = EP.person
    WHERE E.Company = @cia
      AND E.PayRollType = @payrolltype
      AND E.Status = 'N'
      AND NOT EXISTS (
            SELECT 1 FROM #lista_rem_basica L WHERE L.person = E.Person
      );

    ;WITH Totales AS (
        SELECT
            EPC.Person,
            SUM(CASE WHEN C.FormulaCode = 'TOTALINGRESO' THEN ISNULL(EPC.ConceptValueLo, 0) ELSE 0 END) AS total_ingresos,
            SUM(CASE WHEN C.FormulaCode = 'TOTALEGRESOS' THEN ISNULL(EPC.ConceptValueLo, 0) ELSE 0 END) AS total_egresos,
            SUM(CASE WHEN C.FormulaCode = 'NETO' THEN ISNULL(EPC.ConceptValueLo, 0) ELSE 0 END) AS neto
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK)
                ON EPC.Concept = C.Concept
               AND C.Company = @cia
        WHERE EPC.Company = @cia
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND EPC.PRPeriod = @period
        GROUP BY EPC.Person
    )
    INSERT INTO #errores (person, name, observacion)
    SELECT
        E.Person,
        LTRIM(RTRIM(
            ISNULL(P.LastName1, '') + ' ' +
            ISNULL(P.LastName2, '') + ' ' +
            ISNULL(P.Name1, '') + ' ' +
            ISNULL(P.Name2, '')
        )),
        'Neto no coincide con Ingresos - Egresos'
    FROM Totales T
        INNER JOIN PR_Employee E (NOLOCK)
            ON T.Person = E.Person
           AND E.Company = @cia
           AND E.PayRollType = @payrolltype
           AND E.Status = 'N'
        INNER JOIN #empleados_periodo EP ON E.Person = EP.person
        INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
    WHERE ROUND(T.total_ingresos, 2) - ROUND(T.total_egresos, 2) <> ROUND(T.neto, 2);

    INSERT INTO #errores (person, name, observacion)
    SELECT NULL, NULL, T.Description + ' no tiene código PDT'
    FROM (
        SELECT DISTINCT C.Description
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK) ON EPC.Concept = C.Concept
            INNER JOIN PR_ConceptType CT (NOLOCK)
                ON C.ConceptType = CT.ConceptType
               AND CT.ShortName = 'I'
        WHERE EPC.Company = @cia
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND EPC.PRPeriod = @period
          AND ISNULL(C.pdt, '') = ''
        UNION
        SELECT DISTINCT C.Description
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_Concept C (NOLOCK) ON EPC.Concept = C.Concept
            INNER JOIN PR_ConceptType CT (NOLOCK)
                ON C.ConceptType = CT.ConceptType
               AND CT.ShortName = 'D'
               AND ISNULL(C.FormulaCode, '') <> 'ONP'
        WHERE EPC.Company = @cia
          AND EPC.PayRollType = @payrolltype
          AND EPC.ProcessType = @processtype
          AND EPC.PRPeriod = @period
          AND ISNULL(C.pdt, '') = ''
    ) T;

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene régimen de pensión'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.PensionType,
            PT.PDT
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
            INNER JOIN #empleados_periodo EP ON E.Person = EP.person
            INNER JOIN PR_EmployeeCategory ECAT (NOLOCK)
                ON E.EmployeeCategory = ECAT.EmployeeCategory
               AND ECAT.PDT = '1'
            LEFT JOIN PR_PensionType PT (NOLOCK)
                ON E.PensionType = PT.PensionType
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.PensionType, '') = '' OR T.PDT = '99';

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene cargo'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.Position
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
            INNER JOIN #empleados_periodo EP ON E.Person = EP.person
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.Position, '') = '';

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene cuenta bancaria'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.SalaryAccount
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
            INNER JOIN #empleados_periodo EP ON E.Person = EP.person
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.SalaryAccount, '') = '';

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene banco de haberes'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.SalaryBank
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
            INNER JOIN #empleados_periodo EP ON E.Person = EP.person
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.SalaryBank, '') = '';

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene tipo cuenta de haberes'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.SalaryAccountType
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
            INNER JOIN #empleados_periodo EP ON E.Person = EP.person
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.SalaryAccountType, '') = '';

    INSERT INTO #errores (person, name, observacion)
    SELECT T.Person, T.Name, 'Trabajador no tiene perfil contable'
    FROM (
        SELECT
            E.Person,
            LTRIM(RTRIM(
                ISNULL(P.LastName1, '') + ' ' +
                ISNULL(P.LastName2, '') + ' ' +
                ISNULL(P.Name1, '') + ' ' +
                ISNULL(P.Name2, '')
            )) AS Name,
            E.AccountProfile
        FROM PR_Employee E (NOLOCK)
            INNER JOIN SY_Person P (NOLOCK) ON E.Person = P.Person
            INNER JOIN #empleados_periodo EP ON E.Person = EP.person
        WHERE E.Company = @cia
          AND E.PayRollType = @payrolltype
          AND E.Status = 'N'
    ) T
    WHERE ISNULL(T.AccountProfile, '') = '';

    SELECT
        LTRIM(RTRIM(ISNULL(person, ''))) AS person,
        LTRIM(RTRIM(ISNULL(name, ''))) AS name,
        LTRIM(RTRIM(observacion)) AS observacion
    FROM #errores
    ORDER BY name, observacion;
END
GO

