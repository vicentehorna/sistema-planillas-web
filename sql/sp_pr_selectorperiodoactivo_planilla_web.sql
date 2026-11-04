Vamos a crear un nuevo grupo dentro de procesos: AFP y dentro AFPnet

Actúa como experto en la normativa de AFPnet en Perú. Necesito implementar la pantalla de 'Declaración de AFP'. El proceso consta de dos partes:

1. Vista Web (Frontend): Réplica un reporte analítico similar a un DataWindow que muestre en una tabla: Ítem, CUSPP, Tipo DOI, Documento, Nombres y Apellidos, Remuneración, Aporte Obligatorio, Comisión, Seguro y Total Neto AFP. Agrega en la parte superior un botón llamado 'Generar Archivo AFPnet'.

El query de referencia para este reporte es el siguiente:

 

	SELECT
			pr_employee.person as person, 
			CASE 
				WHEN sy_person.lastname1 IS null THEN ''
				ELSE sy_person.lastname1 
			END + ' ' + 
			CASE 
				WHEN sy_person.lastname2 IS null THEN ''
				ELSE sy_person.lastname2 
			END  + ' ' + 
			CASE 
				WHEN sy_person.name1 IS null THEN ''
				ELSE sy_person.name1 
			END  + ' ' + 
			CASE 
				WHEN sy_person.name2 IS null THEN '' 
				ELSE sy_person.name2 
			END name,
			sy_person.documentnumber,
			 pr_employeeafp.prperiod,
			 pr_employeeafp.afp,
			 pr_employeeafp.afpcard,
			 pr_employeeafpheader.payrolltype,
			 Pr_employeeafpheader.CostCentername,
			 sy_company.address,
			 sy_company.telephone,
			 pr_employeeafp.assureableremamountlo,
			 pr_employeeafp.fixedamountlo,
			 pr_employeeafp.variableamountlo,
			 pr_employeeafp.insuredamountlo,
			 pr_employeeafp.arcomisionamountlo,
  	 		 case when convert(varchar(4),year(isnull(pr_employeeafp.ceasedate,pr_employeeafp.entrydate))) +	 right('00' + convert(varchar(2),month(isnull(pr_employeeafp.ceasedate,pr_employeeafp.entrydate))),2) <> LEFT(pr_employeeafp.prperiod,6) then '' else (case when isnull(pr_employeeafp.ceasedate,'')= '' then '01 ' + convert(Char(10), pr_employeeafp.entrydate,103) else '02 ' + convert(Char(10), pr_employeeafp.ceasedate,103) end ) end As Fecha_Cese,
			 pr_afp.description,
			 sy_company.description,
			 sy_company.ruc,
			CASE WHEN sy_person.name1 IS null THEN '' ELSE sy_person.name1 END AS name1,
			CASE WHEN sy_person.name2 IS null THEN '' ELSE sy_person.name2 END AS name2,
			CASE WHEN sy_person.lastname1 IS null THEN '' ELSE sy_person.lastname1 END AS lastname1,
			CASE WHEN sy_person.lastname2 IS null THEN '' ELSE sy_person.lastname2 END AS lastname2,
			pr_employeeafpheader.InteresPercentage,
			pr_employeeafpheader.InteresDays,

			(SELECT isnull(CONCEPTVALUE,0.00) as total
		  FROM PR_EMPLOYEEPAYROLLCONCEPT, pr_concept  
		  WHERE ( PR_EMPLOYEEPAYROLLCONCEPT.COMPANY = :par_company ) AND  
		( pr_concept.COMPANY = :par_company ) AND 
		( pr_employeepayrollconcept.concept = pr_concept.concept) AND 
      ( PROCESSTYPE = (select processtype from pr_processtype where shortname = 'FIN_DE_MES' and company = :par_company) ) AND  
      ( PAYROLLTYPE = pr_employee.payrolltype ) AND 
      ( substring(PRPERIOD,1,8) = :par_period ) AND  
      ( pr_concept.formulacode = 'AFP2APORTE' ) AND  
      ( PERSON = pr_employee.person )) as aporte2,

'' as a 
	FROM  pr_employeeafp,
			pr_employeeafpheader,
		 pr_afp,
		 sy_person,
		 sy_company,
		 pr_employee 
	WHERE	 (pr_employeeafp.person  = sy_person.person)
	 AND	(pr_employeeafp.company  = sy_company.company)
	 AND	(pr_employeeafp.person  = pr_employee.person)
	 AND	(pr_employeeafp.company  = pr_employee.company)
	 AND	(pr_employeeafp.company  = :par_company)
	 AND  (pr_employeeafpheader.company = pr_employeeafp.company)
	 AND  (pr_employeeafpheader.prperiod = pr_employeeafp.prperiod)
	 AND  (pr_employeeafpheader.afp = pr_employeeafp.afp)
	 AND  (pr_employeeafpheader.replicationunit = pr_employeeafp.replicationunit)
	 AND  (pr_employeeafpheader.costcenter = pr_employeeafp.costcenter)
	 AND  (pr_employeeafpheader.payrolltype = pr_employeeafp.payrolltype)
	 AND	(pr_employeeafp.afp = pr_afp.afp)
	 AND	(:par_afp_all  = 'Y'
	 OR	pr_employeeafp.afp  = :par_afp)
	 AND	(:par_payrolltype_all  = 'Y'
	 OR	pr_employeeafpheader.payrolltype  = :par_payrolltype)
	 AND	(left(pr_employeeafp.prperiod, 6)  = :par_period)
	 AND	(:par_employee_all  = 'Y'
	 OR	pr_employeeafp.person  = :par_employee)
    AND        (:par_repunit_all  = 'Y' or pr_employeeafpheader.replicationunit = :par_repunit)
 	 AND 			(:par_flagcostcenter = 'Y' or (pr_employeeafpheader.costcenter = :par_costcenter)) 
	ORDER BY pr_afp.description,22
		 
	
	Tablas de AFP:
	
	
CREATE TABLE [dbo].[PR_AFP](
	[AFP] [varchar](20) NOT NULL,
	[Description] [varchar](20) NULL,
	[Vendor] [varchar](20) NULL,
	[PensionPercentage] [decimal](19, 4) NULL,
	[TopAFP] [decimal](19, 4) NULL,
	[TopAFPCurrency] [char](2) NULL,
	[FixedAmount] [numeric](18, 4) NULL,
	[VariablePercentage] [numeric](18, 4) NULL,
	[InsuredPercentage] [numeric](18, 4) NULL,
	[Company] [varchar](4) NULL,
	[ReplicationUnit] [varchar](4) NULL,
	[XLastUser] [varchar](20) NULL,
	[XLastDate] [datetime] NULL,
	[AFPCode] [varchar](20) NULL,
	[pdt] [varchar](20) NULL,
	[afpcodenet] [varchar](20) NULL,
 CONSTRAINT [PK__PR_AFP__7226EDCC] PRIMARY KEY CLUSTERED 
(
	[AFP] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO



CREATE TABLE [dbo].[PR_EmployeeAFP](
	[Person] [varchar](20) NOT NULL,
	[Company] [varchar](4) NOT NULL,
	[PRperiod] [varchar](20) NOT NULL,
	[AFP] [varchar](20) NULL,
	[AFPCurrency] [char](2) NULL,
	[AFPExchangerate] [numeric](18, 4) NULL,
	[AssureableRemAmount] [numeric](18, 4) NULL,
	[AssureableRemAmountLo] [numeric](18, 4) NULL,
	[AssureableRemAmountEx] [numeric](18, 4) NULL,
	[FixedAmount] [numeric](18, 4) NULL,
	[FixedAmountLo] [numeric](18, 4) NULL,
	[FixedAmountEx] [numeric](18, 4) NULL,
	[VariableAmount] [numeric](18, 4) NULL,
	[VariableAmountLo] [numeric](18, 4) NULL,
	[VariableAmountEx] [numeric](18, 4) NULL,
	[InsuredAmount] [numeric](18, 4) NULL,
	[InsuredAmountLo] [numeric](18, 4) NULL,
	[InsuredAmountEx] [numeric](18, 4) NULL,
	[ARComisionAmount] [numeric](18, 4) NULL,
	[ARComisionAmountLo] [numeric](18, 4) NULL,
	[ARComisionAmountEx] [numeric](18, 4) NULL,
	[ReplicationUnit] [varchar](4) NULL,
	[XLastUser] [varchar](20) NULL,
	[XLastDate] [datetime] NULL,
	[Costcenter] [varchar](20) NULL,
	[Costcentername] [varchar](20) NULL,
	[payrolltype] [varchar](20) NULL,
	[ceasedate] [datetime] NULL,
	[afpcard] [varchar](20) NULL,
	[entrydate] [datetime] NULL,
	[EmployerContribution] [decimal](19, 4) NULL,
	[EmployerContributionLo] [decimal](19, 4) NULL,
	[EmployerContributionEx] [decimal](19, 4) NULL,
 CONSTRAINT [PK__PR_EmployeeAFP__6A1BB7B0] PRIMARY KEY CLUSTERED 
(
	[Person] ASC,
	[Company] ASC,
	[PRperiod] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[PR_EmployeeAFP]  WITH NOCHECK ADD  CONSTRAINT [FK__PR_Employee__AFP__3E5D3103] FOREIGN KEY([AFP])
REFERENCES [dbo].[PR_AFP] ([AFP])
GO

ALTER TABLE [dbo].[PR_EmployeeAFP] CHECK CONSTRAINT [FK__PR_Employee__AFP__3E5D3103]
GO

ALTER TABLE [dbo].[PR_EmployeeAFP]  WITH NOCHECK ADD  CONSTRAINT [FK__PR_EmployeeAFP__3F51553C] FOREIGN KEY([Person], [Company])
REFERENCES [dbo].[PR_Employee] ([Person], [Company])
GO

ALTER TABLE [dbo].[PR_EmployeeAFP] CHECK CONSTRAINT [FK__PR_EmployeeAFP__3F51553C]
GO


CREATE TABLE [dbo].[PR_EmployeeAFPHeader](
	[Company] [varchar](4) NOT NULL,
	[ReplicationUnit] [varchar](4) NOT NULL,
	[PRPeriod] [varchar](20) NOT NULL,
	[PayrollType] [varchar](20) NOT NULL,
	[AFP] [varchar](20) NOT NULL,
	[PaymentDate] [datetime] NULL,
	[PaymentStatus] [varchar](1) NULL,
	[XLastUser] [varchar](20) NULL,
	[XLastDate] [datetime] NULL,
	[InteresPercentage] [decimal](19, 4) NULL,
	[InteresDays] [decimal](19, 4) NULL,
	[payrollnumber] [varchar](20) NULL,
	[costcenter] [varchar](20) NOT NULL,
	[costcentername] [varchar](20) NULL,
PRIMARY KEY CLUSTERED 
(
	[Company] ASC,
	[ReplicationUnit] ASC,
	[PRPeriod] ASC,
	[PayrollType] ASC,
	[AFP] ASC,
	[costcenter] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO

El query siguiente son los datos que se usaban para la AFPnet en un sistema antiguo

	SELECT
			 
			CASE 
				WHEN sy_person.lastname1 IS null THEN ''
				ELSE sy_person.lastname1 
			END + ' ' + 
			CASE 
				WHEN sy_person.lastname2 IS null THEN ''
				ELSE sy_person.lastname2 
			END  + ' ' + 
			CASE 
				WHEN sy_person.name1 IS null THEN ''
				ELSE sy_person.name1 
			END  + ' ' + 
			CASE 
				WHEN sy_person.name2 IS null THEN ''
				ELSE sy_person.name2 
			END name,
			pr_employeeafp.prperiod,

			pr_employeeafp.afp,
			isnull(pr_employeeafp.afpcard,'') as cuspp,
			pr_employeeafpheader.payrolltype,
			Pr_employeeafpheader.CostCentername,
			sy_company.address,
			sy_company.telephone,
			pr_employeeafp.assureableremamountlo as RemAsegurable,
			pr_employeeafp.fixedamountlo as AporteVoluntarioC,
			0.00 as AporteVoluntarioS,
			isnull(pr_employeeafp.variableamountlo, 0.00) as AporteEmpleador,
			pr_employeeafp.insuredamountlo,
			pr_employeeafp.arcomisionamountlo,
			case 				
				when 
					isnull((select sum(Days) as dias from PR_EmployeeMedicalRest A inner join PR_MedicalRestType B on (A.person = pr_employee.person and A.MedicalRestType = B.MedicalRestType and B.pdt = '05' AND left(A.PRPeriod,6) = left(:par_period,6) and A.Company = :par_company )),0) >= 30 
				AND not exists (select * from PR_EmployeePayRollConcept x inner join PR_Concept y on (x.Concept = y.Concept and y.formulacode = 'TOTAL_REM_AFP'
				and x.Person = pr_employee.person and x.Company = :par_company AND LEFT(X.PRPeriod,6) = left(:par_period,6) )) then 'L'
				else '' end As Excepcion,
  	 		case 
				when left((select top 1  prperiod from pr_period where company = :par_company and pr_period.payrolltype = pr_employee.payrolltype and case when isnull(pr_employee.reentrydate, '') = '' then pr_employee.entrydate else isnull(pr_employee.reentrydate,pr_employee.entrydate) end between pr_period.datebegin and pr_period.dateend),6) = :par_period then '1'
				when left((select top 1  prperiod from pr_period where company = :par_company and pr_period.payrolltype = pr_employee.payrolltype and pr_employee.ceasedate between pr_period.datebegin and pr_period.dateend),6) = :par_period then '2'

				when left((select  top 1  prperiod from PR_EmployeeMedicalRest where person = pr_employee.person and company = :par_company and payreponsableflag = 'S' and prperiod = :par_period),6) = :par_period then '3'
				when left((select  top 1  prperiod from PR_VacationPay where person = pr_employee.person and company = :par_company and prperiod = :par_period),6) = :par_period then '5'
			else '' end As TipoMovimiento,
			case 

				when left((select top 1 prperiod from pr_period where company = :par_company and pr_period.payrolltype = pr_employee.payrolltype and pr_employee.ceasedate between pr_period.datebegin and pr_period.dateend),6) = :par_period then '2'

				when left((select  top 1  prperiod from PR_EmployeeMedicalRest where person = pr_employee.person and company = :par_company and payreponsableflag = 'S' and prperiod = :par_period),6) = :par_period then '3'
				when left((select  top 1 prperiod from PR_VacationPay where person = pr_employee.person and company = :par_company and prperiod = :par_period),6) = :par_period then '5'
			else '' end As TipoMovimientocese,
  	 		case when isnull(pr_employee.ceasedate,'') = '' then '' else convert(Char(10), pr_employee.ceasedate,103) end As ceasedate,
  	 		convert(Char(10), pr_employeeafp.entrydate,103) As entrydate,
			pr_afp.description,
			sy_company.description,
			sy_company.ruc,
			sy_person.name1 + ' ' + sy_person.name2 as names,					
			sy_person.lastname1 as lastname1,
			sy_person.lastname2 as lastname2,
			sy_person.documentnumber as dni,
			substring(pr_afp.afpcodenet,1,2) as afpcode,
			/*case when isnull(pr_employeeafp.variableamountlo, 0.00) = 0.00 then ' ' else */

			case when (select count(*) from PR_EmployeeConcept where Person = pr_employee.person and PayRollType = pr_employee.PayRollType and   exists (select * from PR_Concept where Concept = PR_EmployeeConcept.Concept and formulacode = 'FLAG_MINERO')) > 0 THEN 'M' else 'N' end as Riesgo,
			/*isnull((select top 1 'M' from pr_employeeconcept, pr_mapping 
			 where pr_mapping.employeerisk = pr_employeeconcept.concept
			 and pr_mapping.company = pr_employee.company
			 and pr_employee.person = pr_employeeconcept.person
			 and left(pr_employeeconcept.prperiodstart,6) <= left(pr_employeeafp.prperiod,6) ),'') */
			 /*ISNULL((
				select case max(PR_Concept.FormulaCode) when 'FLAG_COBERTURA_ALTA' then 'M' else '' end from pr_employeeconcept, pr_concept
				where 
					pr_employeeconcept.concept = pr_concept.concept
				and pr_employeeconcept.person = pr_employee.person
				and left(pr_employeeconcept.prperiodstart,6) <= left(pr_employeeafp.prperiod,6)
				and PR_Concept.FormulaCode = 'FLAG_COBERTURA_ALTA'
				and PR_EmployeeConcept.Company = PR_Employee.Company
			 ),'') 
			 as Riesgo,*/
			/*(select case max(PR_Concept.FormulaCode) when 'PORC_TRAFONAFP2' then 'M' else '' end from pr_employeeconcept, pr_concept
				where 
					pr_employeeconcept.concept = pr_concept.concept
				and pr_employeeconcept.person = pr_employee.person
				and PR_Concept.FormulaCode = 'PORC_TRAFONAFP2'
				and PR_EmployeeConcept.Company = PR_Employee.Company
			 ) as RegMinero,*/
			/*(select case when PDT = '32' then 'M' else ' ' end from pr_employeetype where employeetype = pr_employee.employeetype) as RegMinero,*/
			'N' as RegMinero,
			pr_employeeafpheader.InteresPercentage,
			pr_employeeafpheader.InteresDays,
         isnull((select 
         case sy_persondocumenttype.pdt 
             when '01' then '0'
             when '04' then '1'
             when '02' then '2'
             when '03' then '2'
             when '13' then '3'
             when '11' then '3'
             when '07' then '4'
             else '0'
             end
         from sy_persondocumenttype (nolock) WHERE 
        sy_persondocumenttype.PersonDocumentType = sy_person.employeedocumenttype),'0') as PersonDocumentType 
	FROM  pr_employeeafp (nolock),
			pr_employeeafpheader (nolock),
		 	pr_afp (nolock),
		 	sy_person (nolock),
		 	sy_company (nolock),
		 	pr_employee (nolock) 
	WHERE	 (pr_employeeafp.person  = sy_person.person)
	 AND	(pr_employeeafp.company  = sy_company.company)
	 AND	(pr_employeeafp.person  = pr_employee.person)
	 AND	(pr_employeeafp.company  = pr_employee.company)
	 AND	(pr_employeeafp.company  = :par_company)
	 AND  (pr_employeeafpheader.company = pr_employeeafp.company)
	 AND  (pr_employeeafpheader.prperiod = pr_employeeafp.prperiod)
	 AND  (pr_employeeafpheader.afp = pr_employeeafp.afp)
	 AND  (pr_employeeafpheader.replicationunit = pr_employeeafp.replicationunit)
	 AND  (pr_employeeafpheader.costcenter = pr_employeeafp.costcenter)
	 AND  (pr_employeeafpheader.payrolltype = pr_employeeafp.payrolltype)
	 AND	(pr_employeeafp.afp = pr_afp.afp)
	 AND	(:par_afp_all  = 'Y'
	 OR	pr_employeeafp.afp  = :par_afp)
	 AND	(:par_payrolltype_all  = 'Y'
	 OR	pr_employeeafpheader.payrolltype  = :par_payrolltype)
	 AND	(left(pr_employeeafp.prperiod, 6)  = left(:par_period,6))
	 AND	(:par_employee_all  = 'Y'
	 OR	pr_employeeafp.person  = :par_employee)
    AND  (:par_repunit_all  = 'Y' or pr_employeeafpheader.replicationunit = :par_repunit)
 	 AND 	(:par_flagcostcenter = 'Y' or (pr_employeeafpheader.costcenter = :par_costcenter)) 

	union all


	SELECT 

CASE 
				WHEN sy_person.lastname1 IS null THEN ''
				ELSE sy_person.lastname1 
			END + ' ' + 
			CASE 
				WHEN sy_person.lastname2 IS null THEN ''
				ELSE sy_person.lastname2 
			END  + ' ' + 
			CASE 
				WHEN sy_person.name1 IS null THEN ''
				ELSE sy_person.name1 
			END  + ' ' + 
			CASE 
				WHEN sy_person.name2 IS null THEN ''
				ELSE sy_person.name2 
			END name,
			'202305',

			NULL, NULL, NULL, NULL,
			sy_company.address,
			sy_company.telephone,
			0 as RemAsegurable,
			0 as AporteVoluntarioC,
			0 as AporteVoluntarioS,
			0 as AporteEmpleador,
			0 as insuredamountlo,
			0 as arcomisionamountlo,

			case 				
				when 
					isnull((select sum(Days) as dias from PR_EmployeeMedicalRest A inner join PR_MedicalRestType B on (A.person = pr_employee.person and A.MedicalRestType = B.MedicalRestType and B.pdt = '05' AND left(A.PRPeriod,6) = left(:par_period,6) and A.Company = 'BGT' )),0) >= 30 
				AND not exists (select * from PR_EmployeePayRollConcept x inner join PR_Concept y on (x.Concept = y.Concept and y.formulacode = 'TOTAL_REM_AFP'
				and x.Person = pr_employee.person and x.Company = :par_company AND LEFT(X.PRPeriod,6) = left(:par_period,6) )) then 'L'
				else 'O' end,

			'J' As TipoMovimiento,
			'0' As TipoMovimientocese,
			
  	 		case when isnull(pr_employee.ceasedate,'') = '' then '' else convert(Char(10), pr_employee.ceasedate,103) end As ceasedate,
  	 		convert(Char(10), pr_employee.entrydate,103) As entrydate,
			NULL,
			sy_company.description,
			sy_company.ruc,
			sy_person.name1 + ' ' + sy_person.name2 as names,					
			sy_person.lastname1 as lastname1,
			sy_person.lastname2 as lastname2,
			sy_person.documentnumber as dni,
			NULL as afpcode,
			'N',

			'N' as RegMinero,
			0,0,
         isnull((select 
         case sy_persondocumenttype.pdt 
             when '01' then '0'
             when '04' then '1'
             when '02' then '2'
             when '03' then '2'
             when '13' then '3'
             when '11' then '3'
             when '07' then '4'
             else '0'
             end
         from sy_persondocumenttype (nolock) WHERE 
        sy_persondocumenttype.PersonDocumentType = sy_person.employeedocumenttype),'0') as PersonDocumentType 
		FROM	PR_EmployeeConcept inner join PR_Employee on (PR_EmployeeConcept.Person = PR_Employee.Person
	and FlagFrecuencyType in ('P', 'T') ) inner join
		 	sy_person (nolock) on (PR_EmployeeConcept.Person = sy_person.Person) inner join	 	sy_company (nolock)
			on (PR_EmployeeConcept.Company = SY_Company.Company) inner join PR_Concept on (PR_EmployeeConcept.Concept
			 = PR_Concept.Concept and PR_Concept.formulacode = 'FLAG_JUBILADO')
	where (((FlagFrecuencyType = 'T' and left(PRPeriodStart,6) = left(:par_period,6))) or (FlagFrecuencyType = 'P'))
 AND	(PR_EmployeeConcept.company  = :par_company)

	ORDER BY pr_afp.description,
		 pr_employeeafpheader.payrolltype,
		 1 
	


2. Acción del Botón (Backend - Python): Crea una ruta en Flask que tome los datos de la planilla del mes y devuelva un archivo de Excel descargable (.xlsx)
 usando la librería openpyxl. El archivo no debe llevar cabeceras decorativas ni títulos; debe empezar directamente en la fila 1, fila por fila con las 16 columnas oficiales que 
 pide AFPnet (Secuencia, CUSPP, Tipo Doc, Num Doc, Apellido P, Apellido M, Nombres, Relación Laboral 'S' o 'N', Inicio, Cese, Excepción, Remuneración Asegurable con dos decimales y las columnas de aportes voluntarios en 0.00). 
 Mapea el Tipo de Documento de Sunat al formato de AFPnet (DNI = 0, CE = 1, Pasaporte = 2).
 
 El formato de AFP NET es :
 
 Columna,Nombre del Campo,Tipo / Formato,Regla de Negocio / Legislación Peruana
A (1),Número de Secuencia,Numérico,"Correlativo simple empezando en 1, 2, 3..."
B (2),CUSPP,Alfanumérico,Código Único del Sistema Privado de Pensiones (12 caracteres).
C (3),Tipo de Documento,Numérico,"Mapeo AFPnet: 0 = DNI, 1 = Carnet Extranjería, 2 = Pasaporte."
D (4),Número de Documento,Alfanumérico,Documento de identidad del aportante.
E (5),Apellido Paterno,Alfanumérico,Texto limpio (sin caracteres extraños).
F (6),Apellido Materno,Alfanumérico,Texto limpio.
G (7),Nombres,Alfanumérico,Primer y segundo nombre del colaborador.
H (8),Relación Laboral,Alfanumérico,'S' (Sí mantiene vínculo laboral en el mes) o 'N' (No).
I (9),Inicio de Relación Laboral,Alfanumérico,"'S' si ingresó en el mes evaluado, de lo contrario vacío."
J (10),Cese de Relación Laboral,Alfanumérico,"'S' si cesó en el mes evaluado, de lo contrario vacío."
K (11),Excepción de Aportar,Alfanumérico,Vacío por defecto. 'L' si está bajo licencia sin goce de haber.
L (12),Remuneración Asegurable,Decimal (0.00),"El sueldo ganado afecto a AFP. Ojo: Si tuvo licencia (L), va en 0.00."
M (13),Aporte Voluntario Con Fin,Decimal (0.00),Monto del trabajador para su fondo (generalmente 0.00).
N (14),Aporte Voluntario Sin Fin,Decimal (0.00),Monto con fin de ahorro del trabajador (generalmente 0.00).
O (15),Aporte del Empleador,Decimal (0.00),Aportes voluntarios que hace la empresa (generalmente 0.00).
P (16),Tipo de Trabajo / Actividad,Alfanumérico,Regularmente vacío. Se usa 'H' para trabajo de alto riesgo (Jubilación anticipada).


