/*
    Réplica de maestros de planilla de una empresa origen a una empresa nueva.
    Reemplaza a SP_PR_CompanyReplication + sp_pr_completar_replicacion, solo con lo que usa la web.

    Uso:
        EXEC dbo.sp_pr_replicarempresa_web @company = 'S471', @company_base = 'BGT', @xlastuser = 'admin';

    Qué copia (misma BD, de @company_base a @company):
      - Proceso de planilla: tipos de periodo, procesos, tipos de planilla, procesos por planilla,
        periodos y control de procesos.
      - Conceptos y fórmulas: tipos y grupos de concepto, secciones de liquidación, conceptos,
        parámetros, fórmulas (cabecera y detalle) y plantillas de importación.
      - Catálogos de la ficha del trabajador: tipos de documento, estados, motivos de cese, descansos,
        nacionalidades, nivel educativo, modalidades de contrato, EPS, régimen laboral/salud,
        categorías, SCTR, situación especial, tipo de trabajador, pensión, AFP, ocupaciones, cargos,
        motivos de préstamo, categoría profesional, convenios, vías y zonas.
      - Asientos y bancos: bancos, tipos de cuenta, plan de cuentas, cuentas bancarias (sin número),
        formas de pago, perfiles contables y su detalle, configuración PLAME y de 5ta.
      - PR_Mapping y PR_mapping2 (con conceptos, procesos, cuentas, etc. traducidos).
      - Correlativos (SY_ObjectSecuence) para que las altas nuevas no choquen con los IDs copiados.

    Los IDs se traducen reemplazando el código de la empresa origen por el de la destino
    ('LIMABGT 000000000123' -> 'LIMAS471000000000123', 'SB05000000000130' -> 'S471000000000130').
    Si el ID no contiene el código de origen se antepone el código destino (p. ej. AFP '4' -> 'S4714');
    si no cabe o choca, se asigna 'LIMA' + destino + '9' + correlativo.

    No copia trabajadores ni movimientos. La empresa destino no debe tener trabajadores; si ya tiene
    conceptos o fórmulas, solo se reemplazan con @reemplazar = 1.
*/
CREATE OR ALTER FUNCTION [dbo].[fn_pr_replicaid_web]
(
    @id     VARCHAR(50),
    @src    VARCHAR(4),
    @dst    VARCHAR(4),
    @maxlen INT
)
RETURNS VARCHAR(50)
AS
BEGIN
    DECLARE @s VARCHAR(4) = RTRIM(@src);
    DECLARE @p INT;

    IF @id IS NULL OR @s = ''
        RETURN NULL;

    SET @p = CHARINDEX(@s, @id);
    IF @p > 0
        RETURN STUFF(@id, @p, 4, LEFT(@dst + '    ', 4));

    IF LEN(RTRIM(@dst) + @id) <= @maxlen
        RETURN RTRIM(@dst) + @id;

    RETURN NULL;
END;
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_pr_replicarempresa_web]
    @company      VARCHAR(4),
    @company_base VARCHAR(4),
    @xlastuser    VARCHAR(20) = NULL,
    @reemplazar   BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @dst VARCHAR(4) = LTRIM(RTRIM(ISNULL(@company, '')));
    DECLARE @src VARCHAR(4) = LTRIM(RTRIM(ISNULL(@company_base, '')));
    DECLARE @dst4 VARCHAR(4) = LEFT(LTRIM(RTRIM(ISNULL(@company, ''))) + '    ', 4);
    DECLARE @usuario VARCHAR(20) = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    DECLARE @msg NVARCHAR(400);

    IF @dst = '' OR @src = ''
    BEGIN
        RAISERROR('Indique la empresa destino y la empresa origen.', 16, 1);
        RETURN;
    END;
    IF @dst = @src
    BEGIN
        RAISERROR('La empresa origen debe ser distinta a la empresa destino.', 16, 1);
        RETURN;
    END;
    IF NOT EXISTS (SELECT 1 FROM SY_Company (NOLOCK) WHERE Company = @dst)
    BEGIN
        RAISERROR('La empresa destino no existe.', 16, 1);
        RETURN;
    END;
    IF NOT EXISTS (SELECT 1 FROM SY_Company (NOLOCK) WHERE Company = @src)
    BEGIN
        RAISERROR('La empresa origen no existe.', 16, 1);
        RETURN;
    END;
    IF NOT EXISTS (SELECT 1 FROM PR_Concept (NOLOCK) WHERE Company = @src)
    BEGIN
        RAISERROR('La empresa origen no tiene conceptos para replicar.', 16, 1);
        RETURN;
    END;
    IF EXISTS (SELECT 1 FROM PR_Employee (NOLOCK) WHERE Company = @dst)
    BEGIN
        RAISERROR('La empresa destino ya tiene trabajadores registrados; no se puede replicar.', 16, 1);
        RETURN;
    END;
    DECLARE @tiene_formulas BIT = 0;
    IF OBJECT_ID('dbo.PR_FormulaHeader', 'U') IS NOT NULL
        EXEC sp_executesql
            N'IF EXISTS (SELECT 1 FROM PR_FormulaHeader (NOLOCK) WHERE Company = @dst) SET @tiene = 1;',
            N'@dst VARCHAR(4), @tiene BIT OUTPUT', @dst, @tiene_formulas OUTPUT;

    IF @reemplazar = 0
       AND (@tiene_formulas = 1 OR EXISTS (SELECT 1 FROM PR_Concept (NOLOCK) WHERE Company = @dst))
    BEGIN
        RAISERROR('La empresa destino ya tiene conceptos o fórmulas. Confirme el reemplazo para volver a replicar.', 16, 1);
        RETURN;
    END;

    /* ---------- Configuración ---------- */
    -- filtro: filas origen a copiar (alias s). filtro_del: filas destino a borrar antes (alias d).
    DECLARE @t TABLE (
        orden      INT PRIMARY KEY,
        tabla      SYSNAME COLLATE DATABASE_DEFAULT,
        idcol      SYSNAME COLLATE DATABASE_DEFAULT NULL,
        objeto     VARCHAR(50) COLLATE DATABASE_DEFAULT NULL,
        modo       CHAR(1) NOT NULL DEFAULT 'N',
        filtro     NVARCHAR(1000) NULL,
        filtro_del NVARCHAR(1000) NULL
    );

    INSERT INTO @t (orden, tabla, idcol, objeto, modo, filtro, filtro_del) VALUES
        (10,  'PR_PeriodType',          'PeriodType',          NULL,                   'N', NULL, NULL),
        (20,  'PR_ProcessType',         'ProcessType',         NULL,                   'N', NULL, NULL),
        (30,  'PR_PayRollType',         'PayRollType',         'PR_PAYROLLTYPE',       'N', NULL, NULL),
        (40,  'PR_PayRollTypeProcess',  NULL,                  NULL,                   'N', NULL, NULL),
        (50,  'PR_Period',              NULL,                  NULL,                   'N', NULL, NULL),
        (60,  'PR_ProcessControl',      NULL,                  NULL,                   'N',
              N's.[Company] = @src
                AND EXISTS (SELECT 1 FROM PR_Period p WHERE p.Company = @src AND p.PayRollType = s.PayRollType AND p.PRPeriod = s.PRPeriod)
                AND EXISTS (SELECT 1 FROM PR_PayRollTypeProcess q WHERE q.Company = @src AND q.PayRollType = s.PayRollType AND q.ProcessType = s.ProcessType)',
              NULL),
        (70,  'PR_ConceptType',         'ConceptType',         NULL,                   'N', NULL, NULL),
        (80,  'PR_ConceptGroup',        'ConceptGroup',        NULL,                   'N', NULL, NULL),
        (90,  'PR_LiquidationSection',  'LiquidationSection',  NULL,                   'N', NULL, NULL),
        (100, 'PR_Concept',             'Concept',             'PR_CONCEPT',           'N', NULL, NULL),
        (110, 'PR_Parameter',           'Parameter',           'PR_PARAMETER',         'N', NULL, NULL),
        (120, 'PR_FormulaHeader',       'FormulaHeader',       'PRA_FORM2024',         'N', NULL, NULL),
        (130, 'PR_FormulaDetail',       NULL,                  NULL,                   'N',
              N'1 = 1',
              N'(d.[company] = @dst OR d.FormulaHeader IN (SELECT h.FormulaHeader FROM PR_FormulaHeader h WHERE h.Company = @dst))'),
        (140, 'PR_ImportConcept',       'ImportConcept',       'PR_IMPORTCONCEPT',     'N', NULL, NULL),
        (150, 'PR_ImportConceptDetail', NULL,                  NULL,                   'N',
              N'1 = 1',
              N'(d.[Company] = @dst OR d.ImportConcept IN (SELECT h.ImportConcept FROM PR_ImportConcept h WHERE h.Company = @dst))'),
        (200, 'SY_PersonDocumentType',  'PersonDocumentType',  'PR_PERSONDOCUMENTYPE', 'N', NULL, NULL),
        (205, 'PR_EmployeeStatus',      'EmployeeStatus',      NULL,                   'N', NULL, NULL),
        (210, 'PR_CeaseReason',         'CeaseReason',         NULL,                   'N', NULL, NULL),
        (215, 'PR_MedicalRestType',     'MedicalRestType',     NULL,                   'N', NULL, NULL),
        (220, 'PR_Nacionalidad',        'Nacionalidad',        NULL,                   'N', NULL, NULL),
        (225, 'PR_InstructionLevel',    'InstructionLevel',    NULL,                   'N', NULL, NULL),
        (230, 'HR_CONTRACTMODALITY',    'ContractModality',    NULL,                   'N', NULL, NULL),
        (235, 'PR_HealthEntity',        'HealthEntity',        NULL,                   'N', NULL, NULL),
        (240, 'PR_RegimenLabour',       'RegimenLabour',       NULL,                   'N', NULL, NULL),
        (245, 'PR_REGIMEHEALTH',        'RegimeHealth',        NULL,                   'N', NULL, NULL),
        (250, 'PR_EmployeeCategory',    'EmployeeCategory',    NULL,                   'N', NULL, NULL),
        (255, 'PR_SCTR',                'SCTR',                NULL,                   'N', NULL, NULL),
        (260, 'PR_SpecialStatus',       'SpecialStatus',       NULL,                   'N', NULL, NULL),
        (265, 'PR_EmployeeType',        'EmployeeType',        NULL,                   'N', NULL, NULL),
        (270, 'PR_PensionType',         'PensionType',         NULL,                   'N', NULL, NULL),
        (275, 'PR_AFP',                 'AFP',                 'PR_AFP',               'N', NULL, NULL),
        (280, 'PR_Ocupation',           'Ocupation',           NULL,                   'N', NULL, NULL),
        (285, 'PR_Position',            'Position',            'PR_POSITION',          'N', NULL, NULL),
        (290, 'PR_LoanReason',          'LoanReason',          NULL,                   'N', NULL, NULL),
        (295, 'PR_ProfessionalCategory','ProfessionalCategory',NULL,                   'N', NULL, NULL),
        (300, 'PR_TaxAgreement',        'TaxAgreement',        NULL,                   'N', NULL, NULL),
        (305, 'SY_StreetType',          'StreetType',          NULL,                   'N', NULL, NULL),
        (310, 'SY_Zone',                'Zone',                NULL,                   'N', NULL, NULL),
        (400, 'ERP_Bank',               'Bank',                NULL,                   'N', NULL, NULL),
        (405, 'TE_AccountType',         'AccountType',         NULL,                   'N', NULL, NULL),
        (410, 'AC_Account',             'Account',             'ACACCOUNT',            'N', NULL, NULL),
        (415, 'TE_BankAccount',         'BankAccount',         'TE_BANKACCOUNT',       'N', NULL, NULL),
        (420, 'TE_CollectionForm',      'CollectionForm',      NULL,                   'N', NULL, NULL),
        (425, 'PR_AccountProfile',      'AccountProfile',      NULL,                   'N', NULL, NULL),
        (430, 'PR_AccountProfileDetail',NULL,                  NULL,                   'N',
              N'1 = 1',
              N'(d.[Company] = @dst OR d.AccountProfile IN (SELECT h.AccountProfile FROM PR_AccountProfile h WHERE h.Company = @dst))'),
        (435, 'PR_CompanyPlame',        NULL,                  NULL,                   'N', NULL, NULL),
        (440, 'PR_Configura5ta',        NULL,                  NULL,                   'N', NULL, NULL),
        (500, 'PR_Mapping',             NULL,                  NULL,                   'M', NULL, NULL),
        (510, 'PR_mapping2',            NULL,                  NULL,                   'M', NULL, NULL);

    -- Columnas que apuntan a otra tabla replicada. req = 1: la fila solo se copia si la referencia se tradujo.
    DECLARE @r TABLE (
        tabla     SYSNAME COLLATE DATABASE_DEFAULT,
        columna   SYSNAME COLLATE DATABASE_DEFAULT,
        tabla_ref SYSNAME COLLATE DATABASE_DEFAULT,
        req       BIT NOT NULL DEFAULT 0
    );

    INSERT INTO @r (tabla, columna, tabla_ref, req) VALUES
        ('PR_PayRollType',          'PeriodType',         'PR_PeriodType',         0),
        ('PR_PayRollType',          'salarybank',         'ERP_Bank',              0),
        ('PR_PayRollType',          'salaryaccounttype',  'TE_AccountType',        0),
        ('PR_PayRollType',          'salaryaccount',      'TE_BankAccount',        0),
        ('PR_PayRollTypeProcess',   'PayRollType',        'PR_PayRollType',        1),
        ('PR_PayRollTypeProcess',   'ProcessType',        'PR_ProcessType',        1),
        ('PR_PayRollTypeProcess',   'knownconcept',       'PR_Concept',            0),
        ('PR_PayRollTypeProcess',   'Unknownconcept',     'PR_Concept',            0),
        ('PR_Period',               'PayRollType',        'PR_PayRollType',        1),
        ('PR_ProcessControl',       'PayRollType',        'PR_PayRollType',        1),
        ('PR_ProcessControl',       'ProcessType',        'PR_ProcessType',        1),
        ('PR_Concept',              'ConceptGroup',       'PR_ConceptGroup',       0),
        ('PR_Concept',              'ConceptType',        'PR_ConceptType',        0),
        ('PR_Concept',              'LiquidationSection', 'PR_LiquidationSection', 0),
        ('PR_Concept',              'associatedconcept',  'PR_Concept',            0),
        ('PR_FormulaHeader',        'Payrolltype',        'PR_PayRollType',        0),
        ('PR_FormulaHeader',        'Proccestype',        'PR_ProcessType',        0),
        ('PR_FormulaHeader',        'Concept',            'PR_Concept',            0),
        ('PR_FormulaHeader',        'ConceptCond',        'PR_Concept',            0),
        ('PR_FormulaDetail',        'FormulaHeader',      'PR_FormulaHeader',      1),
        ('PR_FormulaDetail',        'Concept',            'PR_Concept',            0),
        ('PR_FormulaDetail',        'parameter',          'PR_Parameter',          0),
        ('PR_FormulaDetail',        'process',            'PR_ProcessType',        0),
        ('PR_ImportConceptDetail',  'ImportConcept',      'PR_ImportConcept',      1),
        ('PR_ImportConceptDetail',  'Concept',            'PR_Concept',            0),
        ('PR_LoanReason',           'concept',            'PR_Concept',            0),
        ('AC_Account',              'accountassociated',  'AC_Account',            0),
        ('TE_BankAccount',          'AccountType',        'TE_AccountType',        0),
        ('TE_BankAccount',          'Bank',               'ERP_Bank',              0),
        ('TE_BankAccount',          'AccountLo',          'AC_Account',            0),
        ('TE_BankAccount',          'AccountEx',          'AC_Account',            0),
        ('TE_BankAccount',          'FinanceAccount1',    'AC_Account',            0),
        ('TE_BankAccount',          'FinanceAccount2',    'AC_Account',            0),
        ('TE_BankAccount',          'ACCORDEN1',          'AC_Account',            0),
        ('TE_BankAccount',          'ACCORDEN2',          'AC_Account',            0),
        ('TE_CollectionForm',       'AccountLo',          'AC_Account',            0),
        ('TE_CollectionForm',       'AccountEx',          'AC_Account',            0),
        ('PR_AccountProfileDetail', 'AccountProfile',     'PR_AccountProfile',     1),
        ('PR_AccountProfileDetail', 'Concept',            'PR_Concept',            0),
        ('PR_AccountProfileDetail', 'ProcessType',        'PR_ProcessType',        0),
        ('PR_AccountProfileDetail', 'DebitAccount',       'AC_Account',            0),
        ('PR_AccountProfileDetail', 'CreditAccount',      'AC_Account',            0),
        ('PR_CompanyPlame',         'Concept',            'PR_Concept',            0),
        ('PR_Configura5ta',         'ProcessType',        'PR_ProcessType',        0),
        ('PR_Configura5ta',         'Concept',            'PR_Concept',            0);

    -- Valores fijos por columna. {VACIO} = NULL o '' según la nulabilidad de la columna.
    DECLARE @e TABLE (
        tabla   SYSNAME COLLATE DATABASE_DEFAULT,
        columna SYSNAME COLLATE DATABASE_DEFAULT,
        expr    NVARCHAR(400)
    );

    INSERT INTO @e (tabla, columna, expr) VALUES
        ('TE_BankAccount', 'BankAccountNumber', N'{VACIO}'),
        ('PR_mapping2',    'logoweb',           N'{VACIO}');

    IF OBJECT_ID('dbo.f_map_conceptlist_cia') IS NOT NULL
        INSERT INTO @e (tabla, columna, expr)
        VALUES ('PR_FormulaDetail', 'ConceptList', N'dbo.f_map_conceptlist_cia(s.[ConceptList], @src, @dst)');

    -- Tablas presentes en esta BD.
    DECLARE @x TABLE (
        orden      INT PRIMARY KEY,
        tabla      SYSNAME COLLATE DATABASE_DEFAULT,
        idcol      SYSNAME COLLATE DATABASE_DEFAULT NULL,
        objeto     VARCHAR(50) COLLATE DATABASE_DEFAULT NULL,
        modo       CHAR(1),
        colcia     SYSNAME COLLATE DATABASE_DEFAULT,
        maxlen     INT NULL,
        filtro     NVARCHAR(1000),
        filtro_del NVARCHAR(1000)
    );

    INSERT INTO @x (orden, tabla, idcol, objeto, modo, colcia, maxlen, filtro, filtro_del)
    SELECT
        t.orden, t.tabla, idc.name, t.objeto, t.modo, cc.name, idc.max_length,
        ISNULL(t.filtro, N's.' + QUOTENAME(cc.name) + N' = @src'),
        ISNULL(t.filtro_del, N'd.' + QUOTENAME(cc.name) + N' = @dst')
    FROM @t t
    CROSS APPLY (
        SELECT TOP 1 c.name
        FROM sys.columns c
        WHERE c.object_id = OBJECT_ID(N'dbo.' + t.tabla) AND UPPER(c.name) = 'COMPANY'
    ) cc
    OUTER APPLY (
        SELECT TOP 1 c.name, c.max_length
        FROM sys.columns c
        WHERE c.object_id = OBJECT_ID(N'dbo.' + t.tabla) AND UPPER(c.name) = UPPER(t.idcol)
    ) idc
    WHERE OBJECT_ID(N'dbo.' + t.tabla, 'U') IS NOT NULL
      AND (t.idcol IS NULL OR idc.name IS NOT NULL);

    CREATE TABLE #map (
        tabla  SYSNAME COLLATE DATABASE_DEFAULT NOT NULL,
        old    VARCHAR(50) COLLATE DATABASE_DEFAULT NOT NULL,
        new    VARCHAR(50) COLLATE DATABASE_DEFAULT NULL,
        normal BIT NOT NULL,
        PRIMARY KEY (tabla, old)
    );
    CREATE TABLE #res (orden INT PRIMARY KEY, tabla SYSNAME COLLATE DATABASE_DEFAULT, filas INT);

    DECLARE @orden INT, @tabla SYSNAME, @idcol SYSNAME, @objeto VARCHAR(50), @modo CHAR(1);
    DECLARE @colcia SYSNAME, @maxlen INT, @filtro NVARCHAR(1000), @filtro_del NVARCHAR(1000);
    DECLARE @sql NVARCHAR(MAX), @cols NVARCHAR(MAX), @vals NVARCHAR(MAX), @joins NVARCHAR(MAX), @filas INT;
    DECLARE @pdef NVARCHAR(200) = N'@src VARCHAR(4), @dst VARCHAR(4), @usuario VARCHAR(20), @tabla SYSNAME, @maxlen INT';
    DECLARE @col SYSNAME;
    DECLARE @cc TABLE (column_id INT PRIMARY KEY, colname NVARCHAR(300), valexpr NVARCHAR(MAX));
    DECLARE @fk TABLE (n INT PRIMARY KEY, cond NVARCHAR(MAX));
    DECLARE @i INT, @hit BIT, @cond NVARCHAR(MAX);
    BEGIN TRY
        BEGIN TRANSACTION;

        /* 1. Borra lo que tenga la empresa destino (hijos primero).
              Restos de la misma empresa en tablas hoja fuera de la réplica (reportes, conjuntos, etc.) se borran;
              se conservan las filas que otra empresa aún referencia (restos de empresas eliminadas). */
        DECLARE cur_del CURSOR LOCAL FAST_FORWARD FOR
            SELECT tabla, colcia, filtro_del FROM @x ORDER BY orden DESC;
        OPEN cur_del;
        FETCH NEXT FROM cur_del INTO @tabla, @colcia, @filtro_del;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = (
                SELECT N'DELETE h FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id))
                    + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + N' h WHERE h.' + QUOTENAME(hc.name)
                    + N' = @dst AND EXISTS (SELECT 1 FROM ' + QUOTENAME(@tabla) + N' d WHERE '
                    + STUFF((
                        SELECT N' AND h.' + QUOTENAME(COL_NAME(fc.parent_object_id, fc.parent_column_id))
                            + N' = d.' + QUOTENAME(COL_NAME(fc.referenced_object_id, fc.referenced_column_id))
                        FROM sys.foreign_key_columns fc
                        WHERE fc.constraint_object_id = fk.object_id
                        ORDER BY fc.constraint_column_id
                        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 5, N'')
                    + N' AND ' + @filtro_del + N'); '
                FROM sys.foreign_keys fk
                INNER JOIN sys.columns hc ON hc.object_id = fk.parent_object_id AND UPPER(hc.name) = 'COMPANY'
                WHERE fk.referenced_object_id = OBJECT_ID(N'dbo.' + @tabla)
                  AND fk.parent_object_id <> fk.referenced_object_id
                  AND fk.is_disabled = 0
                  AND NOT EXISTS (SELECT 1 FROM @x x3 WHERE OBJECT_ID(N'dbo.' + x3.tabla) = fk.parent_object_id)
                  AND NOT EXISTS (SELECT 1 FROM sys.foreign_keys g
                                  WHERE g.referenced_object_id = fk.parent_object_id AND g.is_disabled = 0)
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)');
            IF @sql IS NOT NULL
                EXEC sp_executesql @sql, @pdef, @src, @dst, @usuario, @tabla, 0;

            -- Solo se protege con NOT EXISTS las llaves que de verdad tienen referencias (evita recorrer tablas grandes).
            DELETE FROM @fk;
            INSERT INTO @fk (n, cond)
            SELECT ROW_NUMBER() OVER (ORDER BY fk.object_id),
                N'SELECT 1 FROM ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id))
                    + N'.' + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + N' h WHERE '
                    + STUFF((
                        SELECT N' AND h.' + QUOTENAME(COL_NAME(fc.parent_object_id, fc.parent_column_id))
                            + N' = d.' + QUOTENAME(COL_NAME(fc.referenced_object_id, fc.referenced_column_id))
                        FROM sys.foreign_key_columns fc
                        WHERE fc.constraint_object_id = fk.object_id
                        ORDER BY fc.constraint_column_id
                        FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 5, N'')
                    + CASE WHEN fk.parent_object_id = fk.referenced_object_id
                           THEN N' AND h.' + QUOTENAME(@colcia) + N' <> @dst' ELSE N'' END
            FROM sys.foreign_keys fk
            WHERE fk.referenced_object_id = OBJECT_ID(N'dbo.' + @tabla)
              AND fk.is_disabled = 0;

            SET @joins = N'';
            SET @i = 1;
            WHILE @i <= (SELECT COUNT(*) FROM @fk)
            BEGIN
                SELECT @cond = cond FROM @fk WHERE n = @i;
                SET @hit = 0;
                SET @sql = N'SELECT TOP (1) @hit = 1 FROM ' + QUOTENAME(@tabla) + N' d WHERE ' + @filtro_del
                    + N' AND EXISTS (' + @cond + N') OPTION (RECOMPILE);';
                EXEC sp_executesql @sql, N'@dst VARCHAR(4), @hit BIT OUTPUT', @dst, @hit OUTPUT;
                IF @hit = 1
                    SET @joins = @joins + N' AND NOT EXISTS (' + @cond + N')';
                SET @i = @i + 1;
            END;

            SET @sql = N'DELETE d FROM ' + QUOTENAME(@tabla) + N' d WHERE ' + @filtro_del + @joins
                + N' OPTION (RECOMPILE)';
            EXEC sp_executesql @sql, @pdef, @src, @dst, @usuario, @tabla, 0;
            FETCH NEXT FROM cur_del INTO @tabla, @colcia, @filtro_del;
        END;
        CLOSE cur_del;
        DEALLOCATE cur_del;

        /* 2. Tabla de equivalencias de IDs (origen -> destino). */
        DECLARE cur_map CURSOR LOCAL FAST_FORWARD FOR
            SELECT tabla, idcol, maxlen, filtro FROM @x WHERE idcol IS NOT NULL ORDER BY orden;
        OPEN cur_map;
        FETCH NEXT FROM cur_map INTO @tabla, @idcol, @maxlen, @filtro;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @sql = N'INSERT INTO #map (tabla, old, new, normal)
                SELECT DISTINCT @tabla, s.' + QUOTENAME(@idcol) + N',
                       dbo.fn_pr_replicaid_web(s.' + QUOTENAME(@idcol) + N', @src, @dst, @maxlen),
                       CASE WHEN CHARINDEX(RTRIM(@src), s.' + QUOTENAME(@idcol) + N') > 0 THEN 1 ELSE 0 END
                FROM ' + QUOTENAME(@tabla) + N' s
                WHERE ' + @filtro + N' AND s.' + QUOTENAME(@idcol) + N' IS NOT NULL';
            EXEC sp_executesql @sql, @pdef, @src, @dst, @usuario, @tabla, @maxlen;

            -- IDs repetidos o ya usados en la tabla: se les asigna un ID nuevo.
            WITH d AS (
                SELECT new, ROW_NUMBER() OVER (PARTITION BY new ORDER BY normal DESC, old) AS rn
                FROM #map
                WHERE tabla = @tabla AND new IS NOT NULL
            )
            UPDATE d SET new = NULL WHERE rn > 1;

            -- También choca si quedaron detalles huérfanos con ese ID.
            SET @joins = (
                SELECT N' OR EXISTS (SELECT 1 FROM ' + QUOTENAME(r.tabla) + N' x WHERE x.' + QUOTENAME(r.columna) + N' = m.new)'
                FROM @r r
                INNER JOIN @x x2 ON x2.tabla = r.tabla
                WHERE r.tabla_ref = @tabla AND r.req = 1 AND x2.idcol IS NULL
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)');

            SET @sql = N'UPDATE m SET new = NULL
                FROM #map m
                WHERE m.tabla = @tabla AND m.new IS NOT NULL
                  AND (EXISTS (SELECT 1 FROM ' + QUOTENAME(@tabla) + N' x WHERE x.' + QUOTENAME(@idcol) + N' = m.new)'
                  + ISNULL(@joins, N'') + N')';
            EXEC sp_executesql @sql, @pdef, @src, @dst, @usuario, @tabla, @maxlen;

            IF EXISTS (SELECT 1 FROM #map WHERE tabla = @tabla AND new IS NULL)
            BEGIN
                IF @maxlen < 20
                BEGIN
                    SET @msg = N'No se pudo generar el ID destino en ' + @tabla + N'.';
                    RAISERROR(@msg, 16, 1);
                END;

                WITH f AS (
                    SELECT new, ROW_NUMBER() OVER (ORDER BY old) AS n
                    FROM #map
                    WHERE tabla = @tabla AND new IS NULL
                )
                UPDATE f
                SET new = 'LIMA' + @dst4 + '9' + RIGHT(REPLICATE('0', 11) + CAST(n AS VARCHAR(11)), 11);
            END;

            FETCH NEXT FROM cur_map INTO @tabla, @idcol, @maxlen, @filtro;
        END;
        CLOSE cur_map;
        DEALLOCATE cur_map;

        SELECT old, MAX(new) AS new
        INTO #mapany
        FROM #map
        WHERE tabla IN ('PR_Concept', 'PR_ProcessType', 'PR_PayRollType', 'PR_Parameter',
                        'AC_Account', 'ERP_Bank', 'TE_AccountType', 'TE_BankAccount', 'TE_CollectionForm')
          AND LEN(old) >= 10
        GROUP BY old;
        CREATE UNIQUE CLUSTERED INDEX ix_mapany ON #mapany (old);

        /* 3. Copia tabla por tabla, traduciendo IDs y referencias. */
        DECLARE cur_ins CURSOR LOCAL FAST_FORWARD FOR
            SELECT orden, tabla, idcol, modo, colcia, filtro FROM @x ORDER BY orden;
        OPEN cur_ins;
        FETCH NEXT FROM cur_ins INTO @orden, @tabla, @idcol, @modo, @colcia, @filtro;
        WHILE @@FETCH_STATUS = 0
        BEGIN
            DELETE FROM @cc;
            INSERT INTO @cc (column_id, colname, valexpr)
            SELECT
                c.column_id,
                QUOTENAME(c.name),
                    CASE
                        WHEN UPPER(c.name) = UPPER(@colcia) THEN N'@dst'
                        WHEN @idcol IS NOT NULL AND UPPER(c.name) = UPPER(@idcol) THEN N'm0.new'
                        WHEN e.expr IS NOT NULL THEN
                            REPLACE(e.expr, N'{VACIO}', CASE WHEN c.is_nullable = 1 THEN N'NULL' ELSE N'''''' END)
                        -- Referencia huérfana en el origen (no existe en la tabla referenciada): NULL si se permite.
                        WHEN r.tabla_ref IS NOT NULL AND c.is_nullable = 1 AND xr.idcol IS NOT NULL THEN
                            N'COALESCE(r' + CAST(c.column_id AS NVARCHAR(10)) + N'.new, (SELECT TOP (1) z.'
                            + QUOTENAME(xr.idcol) + N' FROM ' + QUOTENAME(xr.tabla) + N' z WHERE z.'
                            + QUOTENAME(xr.idcol) + N' = s.' + QUOTENAME(c.name) + N'))'
                        WHEN r.tabla_ref IS NOT NULL THEN
                            N'COALESCE(r' + CAST(c.column_id AS NVARCHAR(10)) + N'.new, s.' + QUOTENAME(c.name) + N')'
                        WHEN UPPER(c.name) = 'XLASTUSER' AND @usuario IS NOT NULL THEN N'@usuario'
                        WHEN UPPER(c.name) = 'XLASTDATE' AND TYPE_NAME(c.system_type_id) LIKE '%datetime%' THEN N'GETDATE()'
                        ELSE N's.' + QUOTENAME(c.name)
                    END
            FROM sys.columns c
            LEFT JOIN @e e ON e.tabla = @tabla AND UPPER(e.columna) = UPPER(c.name)
            LEFT JOIN @r r ON r.tabla = @tabla AND UPPER(r.columna) = UPPER(c.name) AND @modo = 'N'
            LEFT JOIN @x xr ON xr.tabla = r.tabla_ref
            WHERE c.object_id = OBJECT_ID(N'dbo.' + @tabla)
              AND c.is_computed = 0
              AND c.is_identity = 0
              AND TYPE_NAME(c.system_type_id) NOT IN ('timestamp');

            SET @cols = STUFF((
                SELECT N', ' + colname FROM @cc ORDER BY column_id
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'');
            SET @vals = STUFF((
                SELECT N', ' + valexpr FROM @cc ORDER BY column_id
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, N'');

            SET @joins = (
                SELECT CASE WHEN r.req = 1 THEN N' INNER JOIN' ELSE N' LEFT JOIN' END
                    + N' #map r' + CAST(c.column_id AS NVARCHAR(10))
                    + N' ON r' + CAST(c.column_id AS NVARCHAR(10)) + N'.tabla = N''' + r.tabla_ref + N''''
                    + N' AND r' + CAST(c.column_id AS NVARCHAR(10)) + N'.old = s.' + QUOTENAME(c.name)
                FROM @r r
                INNER JOIN sys.columns c
                    ON c.object_id = OBJECT_ID(N'dbo.' + @tabla) AND UPPER(c.name) = UPPER(r.columna)
                WHERE r.tabla = @tabla AND @modo = 'N'
                  AND NOT EXISTS (SELECT 1 FROM @e e WHERE e.tabla = @tabla AND UPPER(e.columna) = UPPER(c.name))
                  AND (@idcol IS NULL OR UPPER(c.name) <> UPPER(@idcol))
                ORDER BY c.column_id
                FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)');

            SET @sql = N'INSERT INTO ' + QUOTENAME(@tabla) + N' (' + @cols + N')
                SELECT ' + @vals + N'
                FROM ' + QUOTENAME(@tabla) + N' s'
                + CASE WHEN @idcol IS NOT NULL
                       THEN N' INNER JOIN #map m0 ON m0.tabla = @tabla AND m0.old = s.' + QUOTENAME(@idcol)
                       ELSE N'' END
                + ISNULL(@joins, N'')
                + N' WHERE ' + @filtro;

            EXEC sp_executesql @sql, @pdef, @src, @dst, @usuario, @tabla, 0;
            SET @filas = @@ROWCOUNT;

            /* PR_Mapping / PR_mapping2: cualquier columna que apunte a un maestro copiado. */
            IF @modo = 'M' AND @filas > 0
            BEGIN
                DECLARE cur_col CURSOR LOCAL FAST_FORWARD FOR
                    SELECT c.name
                    FROM sys.columns c
                    WHERE c.object_id = OBJECT_ID(N'dbo.' + @tabla)
                      AND c.is_computed = 0
                      AND TYPE_NAME(c.system_type_id) IN ('varchar', 'char', 'nvarchar', 'nchar')
                      AND c.max_length BETWEEN 1 AND 100
                      AND UPPER(c.name) NOT IN (UPPER(@colcia), 'REPLICATIONUNIT', 'XLASTUSER')
                      AND c.name NOT LIKE 'doc%'
                      AND c.name NOT LIKE '%transactiontype%'
                      AND c.name NOT LIKE '%path%'
                      AND NOT EXISTS (SELECT 1 FROM @e e WHERE e.tabla = @tabla AND UPPER(e.columna) = UPPER(c.name));
                OPEN cur_col;
                FETCH NEXT FROM cur_col INTO @col;
                WHILE @@FETCH_STATUS = 0
                BEGIN
                    SET @sql = N'UPDATE t SET ' + QUOTENAME(@col) + N' = m.new
                        FROM ' + QUOTENAME(@tabla) + N' t
                        INNER JOIN #mapany m ON m.old = t.' + QUOTENAME(@col) + N'
                        WHERE t.' + QUOTENAME(@colcia) + N' = @dst';
                    EXEC sp_executesql @sql, @pdef, @src, @dst, @usuario, @tabla, 0;
                    FETCH NEXT FROM cur_col INTO @col;
                END;
                CLOSE cur_col;
                DEALLOCATE cur_col;
            END;

            INSERT INTO #res (orden, tabla, filas) VALUES (@orden, @tabla, @filas);

            FETCH NEXT FROM cur_ins INTO @orden, @tabla, @idcol, @modo, @colcia, @filtro;
        END;
        CLOSE cur_ins;
        DEALLOCATE cur_ins;

        IF OBJECT_ID('dbo.PR_mapping2', 'U') IS NOT NULL
            EXEC sp_executesql
                N'IF NOT EXISTS (SELECT 1 FROM PR_mapping2 WHERE company = @dst)
                      INSERT INTO PR_mapping2 (company) VALUES (@dst);',
                N'@dst VARCHAR(4)', @dst;

        /* 4. Correlativos: al menos los de la empresa origen y por encima de los IDs copiados. */
        INSERT INTO SY_ObjectSecuence (Company, Object, ReplicationUnit, Secuence, XLastUser, XLastDate)
        SELECT @dst, s.Object, s.ReplicationUnit, 0, @usuario, GETDATE()
        FROM SY_ObjectSecuence s
        WHERE s.Company = @src
          AND NOT EXISTS (
              SELECT 1 FROM SY_ObjectSecuence d
              WHERE d.Company = @dst AND d.Object = s.Object AND d.ReplicationUnit = s.ReplicationUnit
          );

        UPDATE d
        SET Secuence = s.Secuence, XLastUser = ISNULL(@usuario, d.XLastUser), XLastDate = GETDATE()
        FROM SY_ObjectSecuence d
        INNER JOIN SY_ObjectSecuence s
            ON s.Company = @src AND s.Object = d.Object AND s.ReplicationUnit = d.ReplicationUnit
        WHERE d.Company = @dst
          AND ISNULL(s.Secuence, 0) > ISNULL(d.Secuence, 0);

        ;WITH maxid AS (
            SELECT x.objeto, MAX(CAST(RIGHT(m.new, 12) AS BIGINT)) AS maximo
            FROM #map m
            INNER JOIN @x x ON x.tabla = m.tabla AND x.objeto IS NOT NULL
            WHERE LEN(m.new) = 20
              AND LEFT(m.new, 8) = 'LIMA' + @dst4
              AND RIGHT(m.new, 12) NOT LIKE '%[^0-9]%'
              AND LEFT(RIGHT(m.new, 12), 1) <> '9'
            GROUP BY x.objeto
        )
        UPDATE d
        SET Secuence = mx.maximo, XLastUser = ISNULL(@usuario, d.XLastUser), XLastDate = GETDATE()
        FROM SY_ObjectSecuence d
        INNER JOIN maxid mx ON mx.objeto = d.Object
        WHERE d.Company = @dst
          AND d.ReplicationUnit = 'LIMA'
          AND ISNULL(d.Secuence, 0) < mx.maximo;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;

    DECLARE @total INT = (SELECT ISNULL(SUM(filas), 0) FROM #res);
    DECLARE @conceptos INT = ISNULL((SELECT filas FROM #res WHERE tabla = 'PR_Concept'), 0);
    DECLARE @formulas INT = ISNULL((SELECT filas FROM #res WHERE tabla = 'PR_FormulaHeader'), 0);

    SELECT
        @dst AS company,
        @src AS company_base,
        (SELECT COUNT(*) FROM #res WHERE filas > 0) AS tablas,
        @total AS filas,
        @conceptos AS conceptos,
        @formulas AS formulas,
        'Réplica de ' + @src + ' a ' + @dst + ' completada: '
            + CAST(@conceptos AS VARCHAR(10)) + ' conceptos, '
            + CAST(@formulas AS VARCHAR(10)) + ' fórmulas, '
            + CAST(@total AS VARCHAR(10)) + ' registros en total.' AS mensaje;

    SELECT orden, tabla, filas FROM #res ORDER BY orden;
END;
GO
