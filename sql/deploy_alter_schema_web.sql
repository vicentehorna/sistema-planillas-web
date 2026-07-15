/*
  ALTER SCHEMA WEB - columnas/tablas requeridas por SPs web
  Generado: 2026-07-15 15:56

  Ejecutar PRIMERO sobre la BD destino (hm_alamo, hm_aci, ...)
  antes o como parte de deploy_planillas_web_completo.sql.

  Archivos (10):
    - alter_pr_mapping_add_banbifbank.sql
    - alter_pr_payrolltype_add_diasvacaciones.sql
    - alter_pr_processtype_add_procedurename.sql
    - alter_pr_importconcept_xlastuser_20.sql
    - alter_sy_company_add_logoname_signaturename.sql
    - alter_sy_person_add_nacionalidad.sql
    - alter_pr_concept_add_flagafectoutilidad.sql
    - alter_pr_formuladetail_conceptlist.sql
    - alter_pr_formuladetail_divisor.sql
    - tables_pr_plame_sunat_web.sql
*/

SET NOCOUNT ON;
GO


-- [1/10] alter_pr_mapping_add_banbifbank.sql

/*
    Agrega la columna BanbifBank en PR_Mapping y la inicializa
    con el código de banco de ERP_Bank (BANCO BANBIF) por compañía.
*/
IF OBJECT_ID(N'dbo.PR_Mapping', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_Mapping', 'BanbifBank') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_Mapping ADD BanbifBank VARCHAR(20) NULL');
END
GO

IF OBJECT_ID(N'dbo.PR_Mapping', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_Mapping', 'BanbifBank') IS NOT NULL
   AND OBJECT_ID(N'dbo.ERP_Bank', N'U') IS NOT NULL
BEGIN
    EXEC('
        UPDATE m
        SET BanbifBank = b.bank
        FROM dbo.PR_Mapping m
        INNER JOIN (
            SELECT Company, MIN(bank) AS bank
            FROM dbo.ERP_Bank
            WHERE name = ''BANCO BANBIF''
            GROUP BY Company
        ) b ON b.Company = m.Company
        WHERE m.BanbifBank IS NULL
    ');
END
GO



-- [2/10] alter_pr_payrolltype_add_diasvacaciones.sql

/*
    Agrega dias anuales de vacaciones por tipo de planilla.
    Valor por defecto: 30 dias.
*/
IF OBJECT_ID(N'dbo.PR_PayRollType', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_PayRollType', 'DiasVacaciones') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_PayRollType ADD DiasVacaciones INT NOT NULL CONSTRAINT DF_PR_PayRollType_DiasVacaciones DEFAULT (30)');
END
GO

IF OBJECT_ID(N'dbo.PR_PayRollType', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_PayRollType', 'DiasVacaciones') IS NOT NULL
BEGIN
    EXEC('UPDATE dbo.PR_PayRollType SET DiasVacaciones = 30 WHERE DiasVacaciones IS NULL');
END
GO



-- [3/10] alter_pr_processtype_add_procedurename.sql

/*
    Agrega la columna ProcedureName en PR_ProcessType y asigna el SP de cálculo
    por persona según la descripción del proceso (Procesar planilla → Calcular).

    ProcedureName NULL: proceso sin SP de cálculo individual configurado.
*/
IF OBJECT_ID(N'dbo.PR_ProcessType', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_ProcessType', 'ProcedureName') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_ProcessType ADD ProcedureName VARCHAR(50) NULL');
END
GO

IF OBJECT_ID(N'dbo.PR_ProcessType', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_ProcessType', 'ProcedureName') IS NOT NULL
BEGIN
    UPDATE PR_ProcessType SET ProcedureName = NULL WHERE RTRIM(LTRIM(Description)) = 'PRESTAMOS';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_finmes_persona' WHERE RTRIM(LTRIM(Description)) = 'MENSUAL';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_pagocts_persona' WHERE RTRIM(LTRIM(Description)) = 'PAGO DE CTS';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_vacaciones_persona' WHERE RTRIM(LTRIM(Description)) = 'VACACIONES';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_quincena_persona' WHERE RTRIM(LTRIM(Description)) = 'QUINCENA';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_provcts_persona' WHERE RTRIM(LTRIM(Description)) = 'PROVISION CTS';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_provvac_persona' WHERE RTRIM(LTRIM(Description)) = 'PROVISION VACACIONES';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_provgrati_persona' WHERE RTRIM(LTRIM(Description)) = 'PROVISION GRATIFICACION';
    UPDATE PR_ProcessType
    SET ProcedureName = 'sp_pr_calcular_gratificacion_persona'
    WHERE RTRIM(LTRIM(ShortName)) = 'GRATIFICACION'
       OR RTRIM(LTRIM(Description)) = 'GRATIFICACION';
    UPDATE PR_ProcessType SET ProcedureName = NULL WHERE RTRIM(LTRIM(Description)) = 'UTILIDADES';
    UPDATE PR_ProcessType SET ProcedureName = 'sp_pr_calcular_liquidacion_persona' WHERE RTRIM(LTRIM(Description)) = 'LIQUIDACION';
    UPDATE PR_ProcessType SET ProcedureName = NULL WHERE RTRIM(LTRIM(Description)) = 'PROMEDIO VACACION';
    UPDATE PR_ProcessType SET ProcedureName = NULL WHERE RTRIM(LTRIM(Description)) = 'REINTEGRO';
END
GO



-- [4/10] alter_pr_importconcept_xlastuser_20.sql

/*
    Amplía XlastUser de VARCHAR(4) a VARCHAR(20) en plantillas de importación.
    Alineado con SY_ObjectSecuence.XLastUser y el usuario web (_xlastuser_id, 20 chars).

    Tablas: PR_ImportConcept, PR_ImportConceptDetail
    Usado por: sp_pr_guardarimportconcept_web, POST /api/plantillas-importacion/guardar
*/
IF OBJECT_ID(N'dbo.PR_ImportConcept', N'U') IS NOT NULL
   AND EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'PR_ImportConcept'
      AND c.name = 'XlastUser'
      AND c.max_length <> 20
)
BEGIN
    EXEC('ALTER TABLE dbo.PR_ImportConcept ALTER COLUMN XlastUser VARCHAR(20) NULL');
END
GO

IF OBJECT_ID(N'dbo.PR_ImportConceptDetail', N'U') IS NOT NULL
   AND EXISTS (
    SELECT 1
    FROM sys.columns c
        INNER JOIN sys.tables t ON t.object_id = c.object_id
        INNER JOIN sys.schemas s ON s.schema_id = t.schema_id
    WHERE s.name = 'dbo'
      AND t.name = 'PR_ImportConceptDetail'
      AND c.name = 'XlastUser'
      AND c.max_length <> 20
)
BEGIN
    EXEC('ALTER TABLE dbo.PR_ImportConceptDetail ALTER COLUMN XlastUser VARCHAR(20) NULL');
END
GO



-- [5/10] alter_sy_company_add_logoname_signaturename.sql

/*
    Agrega columnas de logo y firma por compañía en SY_Company.
    Usado por: generación de boletas PDF (static/img + logoname / signaturename).
*/
IF OBJECT_ID(N'dbo.SY_Company', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Company', 'logoname') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.SY_Company ADD logoname VARCHAR(100) NULL');
END
GO

IF OBJECT_ID(N'dbo.SY_Company', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Company', 'signaturename') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.SY_Company ADD signaturename VARCHAR(100) NULL');
END
GO



-- [6/10] alter_sy_person_add_nacionalidad.sql

/*
    Agrega campo de texto Nacionalidad en SY_Person.
    Usado por: maestro de trabajadores / datos generales (web).
*/
IF OBJECT_ID(N'dbo.SY_Person', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Person', 'Nacionalidad') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.SY_Person ADD Nacionalidad VARCHAR(100) NULL');
END
GO



-- [7/10] alter_pr_concept_add_flagafectoutilidad.sql

/*
    Agrega flag afecto a utilidades en PR_Concept (maestro Conceptos).
    Usado por: sp_pr_guardarconcepto_web, sp_pr_obtenerconcepto_web.
*/
IF OBJECT_ID(N'dbo.PR_Concept', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_Concept', 'flagafectoUtilidad') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_Concept ADD flagafectoUtilidad CHAR(1) NOT NULL CONSTRAINT DF_PR_Concept_flagafectoUtilidad DEFAULT (''N'')');
END
GO



-- [8/10] alter_pr_formuladetail_conceptlist.sql

/*
    Lista de conceptos para líneas SumaConc (tipo S).
    Valores separados por |, ej: BGT 000000000130|BGT 000000000069
    Si es NULL, se usa el campo Concept (compatibilidad hacia atrás).
*/
IF OBJECT_ID(N'dbo.PR_FormulaDetail', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_FormulaDetail', 'ConceptList') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_FormulaDetail ADD ConceptList VARCHAR(500) NULL');
END
GO



-- [9/10] alter_pr_formuladetail_divisor.sql

/*
    Divisor fijo para líneas Promedio Vac (tipo M) y Promedio Grati (tipo H).
    Si > 0, la suma del rango se divide entre este valor.
    Si NULL o 0, se divide entre meses del rango (ajustado por ingreso/reingreso).
*/
IF OBJECT_ID(N'dbo.PR_FormulaDetail', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_FormulaDetail', 'Divisor') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_FormulaDetail ADD Divisor NUMERIC(19, 4) NULL');
END
GO



-- [10/10] tables_pr_plame_sunat_web.sql

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

