/*
    Actualiza datos laborales del trabajador (PR_Employee) y sincroniza REM_BASICA si existe.
    Fechas: VARCHAR(10) YYYY-MM-DD o vacío → NULL.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_datoslaborales_trabajador_web]
    @cia                VARCHAR(10),
    @person             VARCHAR(20),
    @employeetype       VARCHAR(20) = NULL,
    @employeecategory   VARCHAR(20) = NULL,
    @entrydate          VARCHAR(10) = '',
    @reentrydate        VARCHAR(10) = '',
    @contractmodality   VARCHAR(20) = NULL,
    @ocupation          VARCHAR(20) = NULL,
    @specialstatus      VARCHAR(20) = NULL,
    @position           VARCHAR(20) = NULL,
    @costcenter         VARCHAR(20) = NULL,
    @payrolltype        VARCHAR(20) = NULL,
    @accountprofile     VARCHAR(20) = NULL,
    @sueldo             VARCHAR(20) = NULL,
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

    DECLARE @fecha_ingreso DATETIME = NULL;
    DECLARE @fecha_reingreso DATETIME = NULL;
    DECLARE @rembasica NUMERIC(18, 4) = NULL;
    DECLARE @costcentername VARCHAR(20) = NULL;

    IF RTRIM(ISNULL(@entrydate, '')) <> '' AND ISDATE(@entrydate) = 1
        SET @fecha_ingreso = CONVERT(DATETIME, @entrydate, 120);

    IF RTRIM(ISNULL(@reentrydate, '')) <> '' AND ISDATE(@reentrydate) = 1
        SET @fecha_reingreso = CONVERT(DATETIME, @reentrydate, 120);

    IF RTRIM(ISNULL(@sueldo, '')) <> ''
    BEGIN
        SET @rembasica = TRY_CONVERT(NUMERIC(18, 4), REPLACE(@sueldo, ',', ''));
        IF @rembasica IS NULL
        BEGIN
            RAISERROR('El sueldo indicado no es un valor numérico válido.', 16, 1);
            RETURN;
        END
    END

    IF NULLIF(LTRIM(RTRIM(ISNULL(@costcenter, ''))), '') IS NOT NULL
    BEGIN
        SELECT TOP 1 @costcentername = LTRIM(RTRIM(ISNULL(cc.Name, '')))
        FROM AC_CostCenter cc (NOLOCK)
        WHERE cc.Company = @cia
          AND cc.CostCenter = LTRIM(RTRIM(@costcenter));
    END

    UPDATE pr_employee
    SET
        employeetype = NULLIF(LTRIM(RTRIM(@employeetype)), ''),
        employeecategory = NULLIF(LTRIM(RTRIM(@employeecategory)), ''),
        entrydate = @fecha_ingreso,
        reentrydate = @fecha_reingreso,
        contractmodality = NULLIF(LTRIM(RTRIM(@contractmodality)), ''),
        ocupation = NULLIF(LTRIM(RTRIM(@ocupation)), ''),
        specialstatus = NULLIF(LTRIM(RTRIM(@specialstatus)), ''),
        position = NULLIF(LTRIM(RTRIM(@position)), ''),
        costcenter = NULLIF(LTRIM(RTRIM(@costcenter)), ''),
        costcentername = CASE
            WHEN NULLIF(LTRIM(RTRIM(@costcenter)), '') IS NULL THEN NULL
            ELSE NULLIF(@costcentername, '')
        END,
        payrolltype = NULLIF(LTRIM(RTRIM(@payrolltype)), ''),
        accountprofile = NULLIF(LTRIM(RTRIM(@accountprofile)), ''),
        rembasica = CASE WHEN @rembasica IS NULL THEN rembasica ELSE @rembasica END,
        salary = CASE WHEN @rembasica IS NULL THEN salary ELSE @rembasica END,
        xlastdate = GETDATE(),
        xlastuser = NULLIF(LTRIM(RTRIM(@xlastuser)), '')
    WHERE company = @cia
      AND person = @person;

    IF @rembasica IS NOT NULL
    BEGIN
        UPDATE ec
        SET
            ec.ConceptValue = @rembasica,
            ec.ConceptValueLo = CASE
                WHEN UPPER(LTRIM(RTRIM(ISNULL(ec.ConceptCurrency, 'LO')))) = 'LO'
                    THEN @rembasica
                ELSE ec.ConceptValueLo
            END,
            ec.XLastDate = GETDATE(),
            ec.XLastUser = NULLIF(LTRIM(RTRIM(@xlastuser)), '')
        FROM PR_EmployeeConcept ec
            INNER JOIN PR_Concept c
                ON c.Concept = ec.Concept
               AND c.Company = ec.Company
        WHERE ec.Company = @cia
          AND ec.Person = @person
          AND c.FormulaCode = 'REM_BASICA'
          AND ec.FlagFrecuencyType = 'P'
          AND ec.PRPeriodEnd IS NULL;
    END
END
GO
