/*
    Registra un trabajador NUEVO a partir de datos consolidados del T-Registro (reportes SUNAT).
    Solo inserta si el DNI/documento no existe en la ficha de la compañía.

    Tablas principales: SY_Person + PR_Employee.
    Address: solo texto libre. Nacionalidad: solo texto (columna Nacionalidad).
    No registra ubigeo ni dirección estructurada.

    Usado por: POST /api/tregistro-importacion/registrar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_tregistro_registrar_trabajador_nuevo_web]
    @cia                    VARCHAR(10),
    @tipo_doc               VARCHAR(50),
    @num_doc                VARCHAR(15),
    @apellido_paterno       VARCHAR(40),
    @apellido_materno       VARCHAR(40) = NULL,
    @nombres                VARCHAR(80),
    @fecha_nac              VARCHAR(10) = NULL,
    @nacionalidad           VARCHAR(100) = NULL,
    @sexo                   VARCHAR(20),
    @telefono               VARCHAR(15) = NULL,
    @email                  VARCHAR(255) = NULL,
    @direccion              VARCHAR(255) = NULL,
    @fecha_ingreso          VARCHAR(10) = NULL,
    @tipo_trabajador        VARCHAR(80) = NULL,
    @regimen_laboral        VARCHAR(80) = NULL,
    @cat_ocupacional        VARCHAR(80) = NULL,
    @ocupacion              VARCHAR(120) = NULL,
    @nivel_educativo        VARCHAR(80) = NULL,
    @tipo_contrato          VARCHAR(80) = NULL,
    @tipo_pago              VARCHAR(80) = NULL,
    @entidad_financiera     VARCHAR(120) = NULL,
    @nro_cuenta             VARCHAR(30) = NULL,
    @remun_bas              VARCHAR(20) = NULL,
    @regimen_pension        VARCHAR(80) = NULL,
    @regimen_pension_fec    VARCHAR(10) = NULL,
    @cuspp                  VARCHAR(20) = NULL,
    @regimen_salud          VARCHAR(80) = NULL,
    @regimen_salud_fec      VARCHAR(10) = NULL,
    @situacion_especial     VARCHAR(80) = NULL,
    @sindicalizado          VARCHAR(5) = NULL,
    @replicationunit        VARCHAR(20) = 'LIMA',
    @xlastuser              VARCHAR(20) = NULL,
    @person_out             VARCHAR(20) = NULL OUTPUT,
    @mensaje_out            VARCHAR(500) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @person                 VARCHAR(20);
    DECLARE @num_doc_norm           VARCHAR(15);
    DECLARE @name1                  VARCHAR(40);
    DECLARE @name2                  VARCHAR(40);
    DECLARE @nombre_completo        VARCHAR(100);
    DECLARE @sex_code               CHAR(1);
    DECLARE @birthdate_dt           DATETIME;
    DECLARE @entrydate_dt           DATETIME;
    DECLARE @pensiondate_dt         DATETIME;
    DECLARE @healthdate_dt          DATETIME;
    DECLARE @rembasica              NUMERIC(18, 4);
    DECLARE @doc_type_id            VARCHAR(20);
    DECLARE @employee_type_id       VARCHAR(20);
    DECLARE @regimen_labour_id      VARCHAR(20);
    DECLARE @prof_category_id       VARCHAR(20);
    DECLARE @contract_modality_id   VARCHAR(20);
    DECLARE @ocupation_id           VARCHAR(20);
    DECLARE @instruction_level_id   VARCHAR(20);
    DECLARE @pension_type_id        VARCHAR(20);
    DECLARE @regime_health_id       VARCHAR(20);
    DECLARE @collection_form_id     VARCHAR(20);
    DECLARE @salary_bank_id         VARCHAR(20);
    DECLARE @special_status_id      VARCHAR(20);
    DECLARE @employee_category_id   VARCHAR(20);
    DECLARE @employee_status_id     VARCHAR(20);
    DECLARE @payroll_type_id        VARCHAR(20);
    DECLARE @position_id            VARCHAR(20);
    DECLARE @costcenter_id          VARCHAR(20);
    DECLARE @accountprofile_id      VARCHAR(20);
    DECLARE @salaryaccounttype_id   VARCHAR(20);
    DECLARE @sctr_health_id         VARCHAR(20);
    DECLARE @sctr_pension_id        VARCHAR(20);
    DECLARE @costcentername         VARCHAR(20);
    DECLARE @is_unionized           CHAR(1);
    DECLARE @flag_mixta             CHAR(1);
    DECLARE @tiene_afp              CHAR(1);
    DECLARE @es_construccion        CHAR(1);
    DECLARE @concept_rembasica      VARCHAR(20);
    DECLARE @concept_afp_flujo      VARCHAR(20);
    DECLARE @period_start           VARCHAR(10);
    DECLARE @cc_asignacion          VARCHAR(20);
    DECLARE @cc_code_asignacion     VARCHAR(20);
    DECLARE @txt                    VARCHAR(200);
    DECLARE @tipo_contrato_raw      VARCHAR(80);
    DECLARE @pos_space              INT;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @tipo_doc = LTRIM(RTRIM(ISNULL(@tipo_doc, '')));
    SET @num_doc = LTRIM(RTRIM(ISNULL(@num_doc, '')));
    SET @apellido_paterno = UPPER(LTRIM(RTRIM(ISNULL(@apellido_paterno, ''))));
    SET @apellido_materno = UPPER(LTRIM(RTRIM(ISNULL(@apellido_materno, ''))));
    SET @nombres = UPPER(LTRIM(RTRIM(ISNULL(@nombres, ''))));
    SET @nacionalidad = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@nacionalidad, '')))), '');
    SET @telefono = NULLIF(LTRIM(RTRIM(ISNULL(@telefono, ''))), '');
    SET @email = NULLIF(LOWER(LTRIM(RTRIM(ISNULL(@email, '')))), '');
    SET @direccion = NULLIF(UPPER(LTRIM(RTRIM(ISNULL(@direccion, '')))), '');
    SET @replicationunit = UPPER(LTRIM(RTRIM(ISNULL(@replicationunit, 'LIMA'))));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    SET @person_out = NULL;
    SET @mensaje_out = NULL;

    IF @cia = '' OR @num_doc = '' OR @apellido_paterno = '' OR @nombres = ''
    BEGIN
        RAISERROR('Indique compañía, documento, apellido paterno y nombres.', 16, 1);
        RETURN;
    END;

    /* Normalizar documento (sin ceros a la izquierda si es numérico). */
    SET @num_doc_norm = @num_doc;
    IF @num_doc_norm NOT LIKE '%[^0-9]%'
    BEGIN
        WHILE LEN(@num_doc_norm) > 1 AND LEFT(@num_doc_norm, 1) = '0'
            SET @num_doc_norm = SUBSTRING(@num_doc_norm, 2, 15);
    END;

    IF EXISTS (
        SELECT 1
        FROM pr_employee e (NOLOCK)
            INNER JOIN sy_person sp (NOLOCK) ON sp.person = e.person
        WHERE e.company = @cia
          AND (
                LTRIM(RTRIM(ISNULL(sp.documentnumber, ''))) = @num_doc
             OR LTRIM(RTRIM(ISNULL(sp.documentnumber, ''))) = @num_doc_norm
             OR (
                    ISNUMERIC(sp.documentnumber) = 1
                AND ISNUMERIC(@num_doc_norm) = 1
                AND CAST(sp.documentnumber AS BIGINT) = CAST(@num_doc_norm AS BIGINT)
             )
          )
    )
    BEGIN
        RAISERROR('El documento %s ya está registrado en la ficha de la compañía.', 16, 1, @num_doc_norm);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM sy_person (NOLOCK) WHERE person = @num_doc_norm)
    BEGIN
        RAISERROR('El código de persona %s ya existe en SY_Person.', 16, 1, @num_doc_norm);
        RETURN;
    END;

    SET @person = @num_doc_norm;

    SET @pos_space = CHARINDEX(' ', @nombres + ' ');
    SET @name1 = LEFT(@nombres, @pos_space - 1);
    SET @name2 = NULLIF(LTRIM(SUBSTRING(@nombres, @pos_space + 1, 80)), '');

    SET @nombre_completo = UPPER(LTRIM(RTRIM(
        ISNULL(@apellido_paterno, '') + ' ' +
        ISNULL(@apellido_materno, '') + ' ' +
        ISNULL(@name1, '') + ' ' +
        ISNULL(@name2, '')
    )));
    IF LEN(@nombre_completo) > 100
        SET @nombre_completo = LEFT(@nombre_completo, 100);

    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@sexo, ''))));
    IF @txt LIKE '%FEMENIN%' OR @txt IN ('2', 'F')
        SET @sex_code = '2';
    ELSE IF @txt LIKE '%MASCULIN%' OR @txt IN ('1', 'M')
        SET @sex_code = '1';
    ELSE
    BEGIN
        RAISERROR('Sexo no reconocido: %s', 16, 1, @sexo);
        RETURN;
    END;

    SET @birthdate_dt = NULL;
    IF NULLIF(LTRIM(RTRIM(ISNULL(@fecha_nac, ''))), '') IS NOT NULL
    BEGIN
        IF CHARINDEX('/', @fecha_nac) > 0
            SET @birthdate_dt = TRY_CONVERT(DATETIME, @fecha_nac, 103);
        ELSE IF ISDATE(@fecha_nac) = 1
            SET @birthdate_dt = CONVERT(DATETIME, @fecha_nac, 120);

        IF @birthdate_dt IS NULL
        BEGIN
            RAISERROR('Fecha de nacimiento no válida: %s', 16, 1, @fecha_nac);
            RETURN;
        END;
    END;

    SET @entrydate_dt = NULL;
    IF NULLIF(LTRIM(RTRIM(ISNULL(@fecha_ingreso, ''))), '') IS NOT NULL
    BEGIN
        IF CHARINDEX('/', @fecha_ingreso) > 0
            SET @entrydate_dt = TRY_CONVERT(DATETIME, @fecha_ingreso, 103);
        ELSE IF ISDATE(@fecha_ingreso) = 1
            SET @entrydate_dt = CONVERT(DATETIME, @fecha_ingreso, 120);

        IF @entrydate_dt IS NULL
        BEGIN
            RAISERROR('Fecha de ingreso no válida: %s', 16, 1, @fecha_ingreso);
            RETURN;
        END;
    END;

    SET @pensiondate_dt = NULL;
    IF NULLIF(LTRIM(RTRIM(ISNULL(@regimen_pension_fec, ''))), '') IS NOT NULL
    BEGIN
        IF CHARINDEX('/', @regimen_pension_fec) > 0
            SET @pensiondate_dt = TRY_CONVERT(DATETIME, @regimen_pension_fec, 103);
        ELSE IF ISDATE(@regimen_pension_fec) = 1
            SET @pensiondate_dt = CONVERT(DATETIME, @regimen_pension_fec, 120);
    END;
    IF @pensiondate_dt IS NULL
        SET @pensiondate_dt = @entrydate_dt;

    SET @healthdate_dt = NULL;
    IF NULLIF(LTRIM(RTRIM(ISNULL(@regimen_salud_fec, ''))), '') IS NOT NULL
    BEGIN
        IF CHARINDEX('/', @regimen_salud_fec) > 0
            SET @healthdate_dt = TRY_CONVERT(DATETIME, @regimen_salud_fec, 103);
        ELSE IF ISDATE(@regimen_salud_fec) = 1
            SET @healthdate_dt = CONVERT(DATETIME, @regimen_salud_fec, 120);
    END;

    SET @rembasica = NULL;
    IF NULLIF(LTRIM(RTRIM(ISNULL(@remun_bas, ''))), '') IS NOT NULL
        SET @rembasica = TRY_CONVERT(NUMERIC(18, 4), REPLACE(@remun_bas, ',', ''));

    SET @is_unionized = CASE
        WHEN UPPER(LTRIM(RTRIM(ISNULL(@sindicalizado, '')))) IN ('SI', 'S', '1', 'X') THEN '1'
        ELSE '0'
    END;

    /* --- Tipo de documento --- */
    SET @txt = UPPER(@tipo_doc);
    SELECT TOP 1 @doc_type_id = dt.persondocumenttype
    FROM sy_persondocumenttype dt (NOLOCK)
    WHERE dt.company = @cia
      AND (
            (@txt LIKE '%DNI%' AND dt.pdt = '01')
         OR (@txt LIKE '%CARN%' AND @txt LIKE '%EXT%' AND dt.pdt = '04')
         OR (@txt LIKE '%PASAPORTE%' AND dt.pdt = '07')
         OR (@txt LIKE '%PTP%' AND dt.pdt = '26')
         OR dt.description = @txt
      )
    ORDER BY CASE WHEN dt.persondocumenttype LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END;

    IF @doc_type_id IS NULL
    BEGIN
        RAISERROR('No se encontró tipo de documento para: %s', 16, 1, @tipo_doc);
        RETURN;
    END;

    /* --- Tipo trabajador --- */
    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@tipo_trabajador, ''))));
    SELECT TOP 1 @employee_type_id = et.employeetype
    FROM pr_employeetype et (NOLOCK)
    WHERE et.company = @cia
      AND UPPER(LTRIM(RTRIM(ISNULL(et.description, '')))) = @txt
    ORDER BY et.employeetype;

    IF @employee_type_id IS NULL AND @txt <> ''
    BEGIN
        SELECT TOP 1 @employee_type_id = et.employeetype
        FROM pr_employeetype et (NOLOCK)
        WHERE et.company = @cia
          AND UPPER(LTRIM(RTRIM(ISNULL(et.description, '')))) LIKE '%' + @txt + '%'
        ORDER BY et.employeetype;
    END;

    /* --- Régimen laboral (728 -> PRIVADO) --- */
    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@regimen_laboral, ''))));
    IF @txt LIKE '%728%' OR @txt LIKE '%PRIVAD%'
        SET @txt = 'PRIVADO';
    ELSE IF @txt LIKE '%PUBLIC%'
        SET @txt = 'PUBLICO';

    SELECT TOP 1 @regimen_labour_id = rl.regimenlabour
    FROM pr_regimenlabour rl (NOLOCK)
    WHERE (rl.company = @cia OR rl.regimenlabour LIKE 'LIMA' + @cia + '%')
      AND UPPER(LTRIM(RTRIM(ISNULL(rl.description, '')))) = @txt
    ORDER BY CASE WHEN rl.regimenlabour LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END;

    /* --- Categoría ocupacional --- */
    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@cat_ocupacional, ''))));
    SELECT TOP 1 @prof_category_id = pc.professionalcategory
    FROM pr_professionalcategory pc (NOLOCK)
    WHERE (pc.company = @cia OR pc.professionalcategory LIKE 'LIMA' + @cia + '%')
      AND UPPER(LTRIM(RTRIM(ISNULL(pc.description, '')))) = @txt
    ORDER BY CASE WHEN pc.professionalcategory LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END;

    /* --- Ocupación --- */
    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@ocupacion, ''))));
    IF @txt <> ''
    BEGIN
        SELECT TOP 1 @ocupation_id = o.ocupation
        FROM pr_ocupation o (NOLOCK)
        WHERE UPPER(LTRIM(RTRIM(ISNULL(o.description, '')))) = @txt
           OR UPPER(LTRIM(RTRIM(ISNULL(o.description, '')))) LIKE '%' + @txt + '%'
        ORDER BY CASE WHEN o.ocupation LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END, o.ocupation;
    END;

    /* --- Nivel educativo --- */
    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@nivel_educativo, ''))));
    IF @txt <> ''
    BEGIN
        SELECT TOP 1 @instruction_level_id = il.instructionlevel
        FROM pr_instructionlevel il (NOLOCK)
        WHERE UPPER(LTRIM(RTRIM(ISNULL(il.description, '')))) = @txt
           OR UPPER(LTRIM(RTRIM(ISNULL(il.description, '')))) LIKE '%' + @txt + '%'
        ORDER BY CASE WHEN il.instructionlevel LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END, il.instructionlevel;
    END;

    /* --- Modalidad de contrato (TRA → HR_ContractModality de la compañía) --- */
    SET @tipo_contrato_raw = UPPER(LTRIM(RTRIM(ISNULL(@tipo_contrato, ''))));
    SET @txt = @tipo_contrato_raw;

    IF @txt <> ''
    BEGIN
        SELECT TOP 1 @contract_modality_id = cm.contractmodality
        FROM hr_contractmodality cm (NOLOCK)
        WHERE (cm.company = @cia OR cm.contractmodality LIKE 'LIMA' + @cia + '%')
          AND (
                UPPER(LTRIM(RTRIM(ISNULL(cm.description, '')))) = @txt
             OR UPPER(LTRIM(RTRIM(ISNULL(cm.description, '')))) LIKE '%' + @txt + '%'
             OR @txt LIKE '%' + UPPER(LTRIM(RTRIM(ISNULL(cm.description, '')))) + '%'
             OR (@txt LIKE '%OBRA%' AND @txt LIKE '%DETERM%' AND cm.pdt = '09')
             OR (@txt LIKE '%OBRA%' AND @txt LIKE '%DETERM%' AND UPPER(cm.description) LIKE '%OBRA DETERMIN%')
             OR (@txt LIKE '%SERV%ESPEC%' AND cm.pdt = '09')
             OR (@txt LIKE '%INDETERM%' AND cm.pdt = '01')
             OR (@txt LIKE '%INDETERM%' AND UPPER(cm.description) LIKE '%INDETERMIN%')
             OR (@txt LIKE '%PLAZO FIJO%' AND cm.pdt = '02')
             OR (@txt LIKE '%TEMPORAL%' AND cm.pdt IN ('03', '04'))
          )
        ORDER BY
            CASE WHEN cm.company = @cia THEN 0 ELSE 1 END,
            CASE WHEN cm.contractmodality LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END,
            cm.contractmodality;
    END;

    /* --- Pensión --- */
    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@regimen_pension, ''))));
    SELECT TOP 1 @pension_type_id = pt.pensiontype
    FROM pr_pensiontype pt (NOLOCK)
    WHERE (pt.company = @cia OR pt.pensiontype LIKE 'LIMA' + @cia + '%' OR pt.pensiontype LIKE @cia + '%')
      AND (
            UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) = @txt
         OR UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) LIKE '%' + @txt + '%'
         OR @txt LIKE '%' + UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) + '%'
         OR (
                (
                    @txt LIKE '%ONP%'
                 OR @txt LIKE '%19990%'
                 OR @txt LIKE '%DECRETO LEY 19990%'
                 OR @txt LIKE '%SISTEMA NACIONAL DE PENS%'
                 OR @txt LIKE '%S.N.P.%'
                 OR @txt LIKE '%SNP%'
                )
            AND pt.pdt IN ('02', '2')
            )
         OR (@txt LIKE '%INTEGRA%' AND pt.pdt = '21')
         OR (@txt LIKE '%PROFUTURO%' AND pt.pdt = '23')
         OR (@txt LIKE '%PRIMA%' AND @txt NOT LIKE '%ONP%' AND @txt NOT LIKE '%19990%' AND pt.pdt = '24')
      )
    ORDER BY
        CASE
            WHEN (
                    @txt LIKE '%ONP%'
                 OR @txt LIKE '%19990%'
                 OR @txt LIKE '%SISTEMA NACIONAL DE PENS%'
                 OR @txt LIKE '%DECRETO LEY 19990%'
                )
             AND pt.pdt IN ('02', '2')
                THEN 0
            WHEN UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) = @txt THEN 1
            ELSE 2
        END,
        CASE WHEN pt.pensiontype LIKE 'LIMA' + @cia + '%' THEN 0 WHEN pt.pensiontype LIKE @cia + '%' THEN 1 ELSE 2 END,
        pt.pensiontype;

    /* Respaldo ONP: texto T-Registro DL 19990 sin coincidencia literal en catálogo */
    IF @pension_type_id IS NULL
       AND (
            @txt LIKE '%ONP%'
         OR @txt LIKE '%19990%'
         OR @txt LIKE '%DECRETO LEY 19990%'
         OR @txt LIKE '%SISTEMA NACIONAL DE PENS%'
         OR @txt LIKE '%S.N.P.%'
         OR @txt LIKE '%SNP%'
       )
    BEGIN
        SELECT TOP 1 @pension_type_id = pt.pensiontype
        FROM pr_pensiontype pt (NOLOCK)
        WHERE (pt.company = @cia OR pt.pensiontype LIKE @cia + '%')
          AND pt.pdt IN ('02', '2')
          AND UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) LIKE '%19990%'
        ORDER BY
            CASE WHEN pt.company = @cia AND pt.pensiontype NOT LIKE 'LIMA%' THEN 0 ELSE 1 END,
            pt.pensiontype;
    END;

    /* AFP en T-Registro (SPP / CUSPP) → marcar flag AFP mixta por defecto */
    SET @flag_mixta = 'N';
    IF @pension_type_id IS NOT NULL
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM pr_pensiontype pt (NOLOCK)
            WHERE pt.pensiontype = @pension_type_id
              AND (
                    pt.pdt IN ('21', '23', '24', '25')
                 OR (
                        (
                            UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) LIKE '%SPP%'
                         OR UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) LIKE '%AFP%'
                        )
                    AND UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) NOT LIKE '%ONP%'
                 )
              )
        )
            SET @flag_mixta = 'Y';
    END;
    IF @flag_mixta = 'N'
    BEGIN
        SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@regimen_pension, ''))));
        IF @txt LIKE '%SPP%'
           OR @txt LIKE '%INTEGRA%'
           OR @txt LIKE '%PRIMA%'
           OR @txt LIKE '%PROFUTURO%'
           OR @txt LIKE '%HABITAT%'
           OR @txt LIKE '%AFP%'
            SET @flag_mixta = 'Y';
        IF @txt LIKE '%ONP%' OR @txt LIKE '%19990%'
            SET @flag_mixta = 'N';
        IF NULLIF(LTRIM(RTRIM(ISNULL(@cuspp, ''))), '') IS NOT NULL
           AND @txt NOT LIKE '%ONP%'
            SET @flag_mixta = 'Y';
    END;

    /* Trabajador con régimen AFP (no ONP) → asignar concepto AFP_FLUJO */
    SET @tiene_afp = 'N';
    IF @pension_type_id IS NOT NULL
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM pr_pensiontype pt (NOLOCK)
            WHERE pt.pensiontype = @pension_type_id
              AND (
                    pt.pdt IN ('21', '23', '24', '25')
                 OR (
                        (
                            UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) LIKE '%SPP%'
                         OR UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) LIKE '%AFP%'
                        )
                    AND UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) NOT LIKE '%ONP%'
                 )
              )
        )
            SET @tiene_afp = 'Y';
    END;
    IF @tiene_afp = 'N'
    BEGIN
        SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@regimen_pension, ''))));
        IF (
               @txt LIKE '%SPP%'
            OR @txt LIKE '%INTEGRA%'
            OR @txt LIKE '%PRIMA%'
            OR @txt LIKE '%PROFUTURO%'
            OR @txt LIKE '%HABITAT%'
            OR @txt LIKE '%AFP%'
           )
           AND @txt NOT LIKE '%ONP%'
           AND @txt NOT LIKE '%19990%'
            SET @tiene_afp = 'Y';
        IF NULLIF(LTRIM(RTRIM(ISNULL(@cuspp, ''))), '') IS NOT NULL
           AND @txt NOT LIKE '%ONP%'
           AND @txt NOT LIKE '%19990%'
            SET @tiene_afp = 'Y';
    END;

    /* --- Salud --- */
    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@regimen_salud, ''))));
    IF @txt LIKE '%ESSALUD%REGULAR%'
        SET @txt = 'ESSALUD REGULAR (Exclusivamente)';

    SELECT TOP 1 @regime_health_id = rh.regimehealth
    FROM pr_regimehealth rh (NOLOCK)
    WHERE UPPER(LTRIM(RTRIM(ISNULL(rh.description, '')))) = @txt
       OR UPPER(LTRIM(RTRIM(ISNULL(rh.description, '')))) LIKE '%ESSALUD REGULAR%'
    ORDER BY CASE WHEN rh.regimehealth LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END, rh.regimehealth;

    /* --- Forma de pago --- */
    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@tipo_pago, ''))));
    IF @txt LIKE '%DEPOS%' OR @txt LIKE '%DEPÓS%'
        SET @txt = 'DEPOSITO';
    ELSE IF @txt LIKE '%EFECTIV%'
        SET @txt = 'EFECTIVO';

    SELECT TOP 1 @collection_form_id = cf.collectionform
    FROM te_collectionform cf (NOLOCK)
    WHERE UPPER(LTRIM(RTRIM(ISNULL(cf.description, '')))) = @txt
       OR UPPER(LTRIM(RTRIM(ISNULL(cf.description, '')))) LIKE '%' + @txt + '%'
    ORDER BY CASE WHEN cf.collectionform LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END;

    /* --- Banco salario --- */
    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@entidad_financiera, ''))));
    IF @txt <> ''
    BEGIN
        SELECT TOP 1 @salary_bank_id = b.bank
        FROM erp_bank b (NOLOCK)
        WHERE (b.company = @cia OR b.bank LIKE 'LIMA' + @cia + '%')
          AND (
                UPPER(LTRIM(RTRIM(ISNULL(b.name, '')))) = @txt
             OR UPPER(LTRIM(RTRIM(ISNULL(b.name, '')))) LIKE '%' + @txt + '%'
             OR (@txt LIKE '%BBVA%' AND UPPER(b.name) LIKE '%CONTINENTAL%')
             OR (@txt LIKE '%CONTINENTAL%' AND UPPER(b.name) LIKE '%CONTINENTAL%')
             OR (@txt LIKE '%BCP%' AND UPPER(b.name) LIKE '%CREDITO%')
             OR (@txt LIKE '%INTERBANK%' AND UPPER(b.name) LIKE '%INTERBANK%')
          )
        ORDER BY CASE WHEN b.bank LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END, b.bank;
    END;

    /* --- Situación especial --- */
    SET @txt = UPPER(LTRIM(RTRIM(ISNULL(@situacion_especial, ''))));
    IF @txt IN ('', 'NINGUNA', 'NINGUNO', '0')
        SET @txt = 'NINGUNA';

    SELECT TOP 1 @special_status_id = ss.specialstatus
    FROM pr_specialstatus ss (NOLOCK)
    WHERE ss.specialstatus LIKE 'LIMA' + @cia + '%'
      AND (
            UPPER(LTRIM(RTRIM(ISNULL(ss.description, '')))) = @txt
         OR UPPER(LTRIM(RTRIM(ISNULL(ss.description, '')))) LIKE '%' + @txt + '%'
      )
    ORDER BY CASE WHEN ss.specialstatus LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END;

    /* --- Categoría y estado empleado (defaults compañía) --- */
    SELECT TOP 1 @employee_category_id = ec.employeecategory
    FROM pr_employeecategory ec (NOLOCK)
    WHERE ec.company = @cia OR ec.employeecategory LIKE 'LIMA' + @cia + '%'
    ORDER BY CASE WHEN ec.pdt = '1' THEN 0 ELSE 1 END,
             CASE WHEN ec.employeecategory LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END,
             ec.employeecategory;

    SELECT TOP 1 @employee_status_id = es.employeestatus
    FROM pr_employeestatus es (NOLOCK)
    WHERE (es.company = @cia OR es.employeestatus LIKE 'LIMA' + @cia + '%')
      AND (es.pdt IN ('11', '10') OR UPPER(es.description) LIKE '%ACTIVO%')
    ORDER BY CASE WHEN es.pdt = '11' THEN 0 WHEN es.pdt = '10' THEN 1 ELSE 2 END,
             CASE WHEN es.employeestatus LIKE 'LIMA' + @cia + '%' THEN 0 ELSE 1 END;

    /* --- Defaults laborales (sin cargo ni centro de costo; vienen vacíos) --- */
    SET @position_id = NULL;
    SET @costcenter_id = NULL;
    SET @costcentername = NULL;

    SELECT TOP 1
        @payroll_type_id = e.payrolltype,
        @accountprofile_id = e.accountprofile,
        @salaryaccounttype_id = e.salaryaccounttype,
        @sctr_health_id = e.sctrhealth,
        @sctr_pension_id = e.sctrpension
    FROM pr_employee e (NOLOCK)
    WHERE e.company = @cia
      AND (
            (@employee_type_id IS NOT NULL AND e.employeetype = @employee_type_id)
         OR (@employee_type_id IS NULL)
      )
    ORDER BY
        CASE WHEN @employee_type_id IS NOT NULL AND e.employeetype = @employee_type_id THEN 0 ELSE 1 END,
        e.xlastdate DESC;

    IF @payroll_type_id IS NULL
    BEGIN
        SELECT TOP 1 @payroll_type_id = pt.payrolltype
        FROM pr_payrolltype pt (NOLOCK)
        WHERE pt.company = @cia
        ORDER BY pt.payrolltype;
    END;

    IF @salaryaccounttype_id IS NULL
        SELECT TOP 1 @salaryaccounttype_id = e.salaryaccounttype
        FROM pr_employee e (NOLOCK)
        WHERE e.company = @cia AND e.salaryaccounttype IS NOT NULL
        ORDER BY e.xlastdate DESC;

    IF NOT EXISTS (
        SELECT 1
        FROM sy_replicationunit (NOLOCK)
        WHERE replicationunit = @replicationunit
           OR UPPER(LTRIM(RTRIM(ISNULL(description, '')))) = @replicationunit
           OR UPPER(LTRIM(RTRIM(ISNULL(name, '')))) = @replicationunit
    )
    BEGIN
        RAISERROR('Unidad de replicación no válida: %s', 16, 1, @replicationunit);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO sy_person (
            person, flaguserid, persontype, name, address,
            documenttype, documentnumber, email, status, flagrucpersontype,
            isvendor, iscustomer, xlastuser, xlastdate, company,
            replicationunit, isemployee, sectelephone, name2, lastname1,
            name1, lastname2, birthdate, instructionlevel, sex,
            employeedocumenttype, flagkeep, flagname, flagoutsourcingin,
            flagoutsourcingout, isdomiciled, nacionalidad, flagperceptionagent,
            flagsunat5, istrainer, isrecruiter, issupervisor, indicator,
            flaglockca, licensecondition
        )
        VALUES (
            @person, 'N', 'NN', @nombre_completo, @direccion,
            @doc_type_id, @num_doc_norm, @email, 'A', 'XX',
            'Y', 'N', @xlastuser, GETDATE(), @cia,
            @replicationunit, 'Y', @telefono, @name2, @apellido_paterno,
            @name1, NULLIF(@apellido_materno, ''), @birthdate_dt, @instruction_level_id, @sex_code,
            @doc_type_id, 'N', 'P', 'N',
            'N', '1', @nacionalidad, 'N',
            'N', 'N', 'N', 'N', '1',
            'N', 'L'
        );

        INSERT INTO pr_employee (
            person, company, employeecode, employeetype, employeecategory,
            entrydate, reentrydate, pensiontype, pensioninscriptiondate,
            salarybank, salaryaccounttype, salarycurrency, salaryaccount,
            costcenter, position, accountprofile, payrolltype, employeestatus,
            flagessaludvida, status, xlastdate, xlastuser, replicationunit,
            costcentername, flagdistribution, contractmodality, considerincalc,
            flagparticipar, regimenlabour, sctrhealth, sctrpension,
            flagalternativeregimen, flagmaxworkinghours, flagnightschedule,
            otherincomerenttax, isunionized, affiliatedowneps, relievedrenttax,
            specialstatus, collectionform, workingdaystype, professionalcategory,
            pensionmembership, ocupation, regimehealth, accidentinsurance,
            confirmcessation, rembasica, salary, afpcard, flagmixta
        )
        VALUES (
            @person, @cia, @person, @employee_type_id, @employee_category_id,
            @entrydate_dt, @entrydate_dt, @pension_type_id, @pensiondate_dt,
            @salary_bank_id, @salaryaccounttype_id, 'LO', NULLIF(@nro_cuenta, ''),
            @costcenter_id, @position_id, @accountprofile_id, @payroll_type_id, @employee_status_id,
            'N', 'N', GETDATE(), @xlastuser, @replicationunit,
            @costcentername, 'H', @contract_modality_id, 'Y',
            'Y', @regimen_labour_id, @sctr_health_id, @sctr_pension_id,
            '0', '0', '0',
            '0', @is_unionized, '0', '0',
            @special_status_id, @collection_form_id, 'S', @prof_category_id,
            '0', @ocupation_id, @regime_health_id, '0',
            'N', @rembasica, @rembasica, NULLIF(LTRIM(RTRIM(ISNULL(@cuspp, ''))), ''), @flag_mixta
        );

        /*
            Asignación permanente REM_BASICA desde el periodo de ingreso.
            No aplica a Construcción Civil (planilla/tipo CONSTRUCCION): usan jornal diario.
        */
        SET @es_construccion = 'N';
        IF EXISTS (
            SELECT 1
            FROM pr_employeetype et (NOLOCK)
            WHERE et.employeetype = @employee_type_id
              AND (
                    et.pdt = '27'
                 OR UPPER(LTRIM(RTRIM(ISNULL(et.description, '')))) LIKE '%CONSTRUCCION%'
              )
        )
            SET @es_construccion = 'Y';

        IF @es_construccion = 'N' AND EXISTS (
            SELECT 1
            FROM pr_payrolltype pt (NOLOCK)
            WHERE pt.payrolltype = @payroll_type_id
              AND (
                    UPPER(LTRIM(RTRIM(ISNULL(pt.description, '')))) LIKE '%CONSTRUCCION%'
                 OR UPPER(LTRIM(RTRIM(ISNULL(pt.shortname, '')))) LIKE '%CONSTRUCCION%'
              )
        )
            SET @es_construccion = 'Y';

        IF @es_construccion = 'N'
           AND @rembasica IS NOT NULL
           AND @rembasica > 0
           AND @payroll_type_id IS NOT NULL
           AND @entrydate_dt IS NOT NULL
        BEGIN
            SET @concept_rembasica = NULL;
            SELECT TOP 1 @concept_rembasica = c.concept
            FROM pr_concept c (NOLOCK)
            WHERE c.company = @cia
              AND c.formulacode = 'REM_BASICA'
              AND c.status = 'A'
            ORDER BY c.concept;

            SET @period_start = NULL;
            SELECT TOP 1 @period_start = p.prperiod
            FROM pr_period p (NOLOCK)
            WHERE p.company = @cia
              AND p.payrolltype = @payroll_type_id
              AND @entrydate_dt BETWEEN p.datebegin AND p.dateend
            ORDER BY p.prperiod;

            IF @period_start IS NULL
            BEGIN
                /* Si aún no hay periodo que contenga la fecha, usar el más cercano posterior o el último anterior. */
                SELECT TOP 1 @period_start = p.prperiod
                FROM pr_period p (NOLOCK)
                WHERE p.company = @cia
                  AND p.payrolltype = @payroll_type_id
                  AND p.datebegin >= @entrydate_dt
                ORDER BY p.datebegin ASC, p.prperiod ASC;

                IF @period_start IS NULL
                    SELECT TOP 1 @period_start = p.prperiod
                    FROM pr_period p (NOLOCK)
                    WHERE p.company = @cia
                      AND p.payrolltype = @payroll_type_id
                      AND p.datebegin <= @entrydate_dt
                    ORDER BY p.datebegin DESC, p.prperiod DESC;
            END;

            SET @cc_asignacion = ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(@costcenter_id, ''))), ''), '');
            SET @cc_code_asignacion = ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(@costcentername, ''))), ''), @cc_asignacion);

            IF @concept_rembasica IS NOT NULL
               AND @period_start IS NOT NULL
               AND NOT EXISTS (
                    SELECT 1
                    FROM pr_employeeconcept ec (NOLOCK)
                    WHERE ec.person = @person
                      AND ec.company = @cia
                      AND ec.concept = @concept_rembasica
                      AND ec.payrolltype = @payroll_type_id
                      AND ec.prperiodstart = @period_start
                      AND ec.costcenter = @cc_asignacion
               )
            BEGIN
                INSERT INTO pr_employeeconcept (
                    person, company, concept, payrolltype, prperiodstart, costcenter,
                    prperiodend, conceptvalue, application, conceptcurrency, comments,
                    flagapplyformula, flagfrecuencytype, replicationunit,
                    xlastuser, xlastdate, conceptvaluelo, conceptvalueex, exchangerate,
                    costcentercode, project, projectcode, percentagedistribution, flagcopy
                )
                VALUES (
                    @person, @cia, @concept_rembasica, @payroll_type_id, @period_start, @cc_asignacion,
                    NULL, @rembasica, NULL, 'LO', NULL,
                    'N', 'P', @replicationunit,
                    @xlastuser, GETDATE(), @rembasica, 0, 0,
                    @cc_code_asignacion, '', '', 'A', NULL
                );
            END;
        END;

        /*
            Asignación permanente AFP_FLUJO (=1) desde el periodo de ingreso.
            Aplica a todo trabajador con AFP, sin excepción por tipo de planilla.
        */
        IF @tiene_afp = 'Y'
           AND @payroll_type_id IS NOT NULL
           AND @entrydate_dt IS NOT NULL
        BEGIN
            SET @concept_afp_flujo = NULL;
            SELECT TOP 1 @concept_afp_flujo = c.concept
            FROM pr_concept c (NOLOCK)
            WHERE c.company = @cia
              AND c.formulacode = 'AFP_FLUJO'
              AND c.status = 'A'
            ORDER BY c.concept;

            IF @period_start IS NULL
            BEGIN
                SELECT TOP 1 @period_start = p.prperiod
                FROM pr_period p (NOLOCK)
                WHERE p.company = @cia
                  AND p.payrolltype = @payroll_type_id
                  AND @entrydate_dt BETWEEN p.datebegin AND p.dateend
                ORDER BY p.prperiod;

                IF @period_start IS NULL
                BEGIN
                    SELECT TOP 1 @period_start = p.prperiod
                    FROM pr_period p (NOLOCK)
                    WHERE p.company = @cia
                      AND p.payrolltype = @payroll_type_id
                      AND p.datebegin >= @entrydate_dt
                    ORDER BY p.datebegin ASC, p.prperiod ASC;

                    IF @period_start IS NULL
                        SELECT TOP 1 @period_start = p.prperiod
                        FROM pr_period p (NOLOCK)
                        WHERE p.company = @cia
                          AND p.payrolltype = @payroll_type_id
                          AND p.datebegin <= @entrydate_dt
                        ORDER BY p.datebegin DESC, p.prperiod DESC;
                END;
            END;

            SET @cc_asignacion = ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(@costcenter_id, ''))), ''), '');
            SET @cc_code_asignacion = ISNULL(NULLIF(LTRIM(RTRIM(ISNULL(@costcentername, ''))), ''), @cc_asignacion);

            IF @concept_afp_flujo IS NOT NULL
               AND @period_start IS NOT NULL
               AND NOT EXISTS (
                    SELECT 1
                    FROM pr_employeeconcept ec (NOLOCK)
                    WHERE ec.person = @person
                      AND ec.company = @cia
                      AND ec.concept = @concept_afp_flujo
                      AND ec.payrolltype = @payroll_type_id
                      AND ec.prperiodstart = @period_start
                      AND ec.costcenter = @cc_asignacion
               )
            BEGIN
                INSERT INTO pr_employeeconcept (
                    person, company, concept, payrolltype, prperiodstart, costcenter,
                    prperiodend, conceptvalue, application, conceptcurrency, comments,
                    flagapplyformula, flagfrecuencytype, replicationunit,
                    xlastuser, xlastdate, conceptvaluelo, conceptvalueex, exchangerate,
                    costcentercode, project, projectcode, percentagedistribution, flagcopy
                )
                VALUES (
                    @person, @cia, @concept_afp_flujo, @payroll_type_id, @period_start, @cc_asignacion,
                    NULL, 1, NULL, 'LO', NULL,
                    'N', 'P', @replicationunit,
                    @xlastuser, GETDATE(), 1, 0, 0,
                    @cc_code_asignacion, '', '', 'A', NULL
                );
            END;
        END;

        COMMIT TRANSACTION;

        SET @person_out = @person;
        SET @mensaje_out = 'Trabajador registrado correctamente.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        DECLARE @err VARCHAR(500) = LEFT(ERROR_MESSAGE(), 500);
        RAISERROR('%s', 16, 1, @err);
        RETURN;
    END CATCH;
END
GO
