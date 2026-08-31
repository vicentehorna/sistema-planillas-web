/*
    Actualiza datos laborales del trabajador (PR_Employee).
    Fechas: VARCHAR(10) YYYY-MM-DD o vacío → NULL.
    @modo_reingreso = 'Y': limpia cese, Status='N', EntryDate inmutable y valida nueva ReEntryDate.

    Nota: la asignación REM_BASICA solo se crea en sp_pr_registrar_trabajador_web (alta).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_actualizar_datoslaborales_trabajador_web]
    @cia                VARCHAR(10),
    @person             VARCHAR(20),
    @employeetype       VARCHAR(20) = NULL,
    @employeecategory   VARCHAR(20) = NULL,
    @entrydate          VARCHAR(10) = '',
    @reentrydate        VARCHAR(10) = '',
    @ceasedate          VARCHAR(10) = '',
    @ceasereason        VARCHAR(30) = NULL,
    @contractmodality   VARCHAR(20) = NULL,
    @ocupation          VARCHAR(20) = NULL,
    @specialstatus      VARCHAR(20) = NULL,
    @position           VARCHAR(20) = NULL,
    @costcenter         VARCHAR(20) = NULL,
    @payrolltype        VARCHAR(20) = NULL,
    @accountprofile     VARCHAR(20) = NULL,
    @sueldo             VARCHAR(20) = NULL,
    @flagasigfamiliar   VARCHAR(1) = 'N',
    @status             VARCHAR(1) = 'N',
    @xlastuser          VARCHAR(20) = NULL,
    @modo_reingreso     VARCHAR(1)  = 'N'
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

    IF RTRIM(ISNULL(@flagasigfamiliar, '')) NOT IN ('Y', 'N') SET @flagasigfamiliar = 'N';
    SET @status = UPPER(LTRIM(RTRIM(ISNULL(@status, 'N'))));
    IF @status NOT IN ('Y', 'N') SET @status = 'N';
    SET @modo_reingreso = UPPER(LTRIM(RTRIM(ISNULL(@modo_reingreso, 'N'))));
    IF @modo_reingreso NOT IN ('Y', 'N') SET @modo_reingreso = 'N';

    DECLARE @fecha_ingreso DATETIME = NULL;
    DECLARE @fecha_reingreso DATETIME = NULL;
    DECLARE @fecha_cese DATETIME = NULL;
    DECLARE @rembasica NUMERIC(18, 4) = NULL;
    DECLARE @costcentername VARCHAR(20) = NULL;
    DECLARE @entry_actual DATETIME = NULL;
    DECLARE @reentry_actual DATETIME = NULL;
    DECLARE @cese_actual DATETIME = NULL;
    DECLARE @fecha_efectiva_anterior DATE = NULL;

    SELECT
        @entry_actual = e.EntryDate,
        @reentry_actual = e.ReEntryDate,
        @cese_actual = e.CeaseDate
    FROM pr_employee e
    WHERE e.Company = @cia
      AND e.Person = @person;

    IF @modo_reingreso = 'Y'
    BEGIN
        IF @cese_actual IS NULL
        BEGIN
            RAISERROR('Solo se puede registrar reingreso de un trabajador cesado.', 16, 1);
            RETURN;
        END

        -- En reingreso la fecha de ingreso original no cambia.
        SET @fecha_ingreso = @entry_actual;
        SET @fecha_cese = NULL;
        SET @ceasereason = NULL;

        IF RTRIM(ISNULL(@reentrydate, '')) = '' OR ISDATE(@reentrydate) = 0
        BEGIN
            RAISERROR('Indique la fecha de reingreso.', 16, 1);
            RETURN;
        END

        SET @fecha_reingreso = CONVERT(DATETIME, @reentrydate, 120);
        SET @fecha_efectiva_anterior = CONVERT(DATE, ISNULL(@reentry_actual, @entry_actual));

        IF @fecha_efectiva_anterior IS NOT NULL
           AND CONVERT(DATE, @fecha_reingreso) <= @fecha_efectiva_anterior
        BEGIN
            RAISERROR('La fecha de reingreso debe ser posterior a la fecha de ingreso/reingreso anterior.', 16, 1);
            RETURN;
        END

        IF CONVERT(DATE, @fecha_reingreso) <= CONVERT(DATE, @cese_actual)
        BEGIN
            RAISERROR('La fecha de reingreso debe ser posterior a la fecha de cese.', 16, 1);
            RETURN;
        END
    END
    ELSE
    BEGIN
        IF RTRIM(ISNULL(@entrydate, '')) <> '' AND ISDATE(@entrydate) = 1
            SET @fecha_ingreso = CONVERT(DATETIME, @entrydate, 120);

        IF RTRIM(ISNULL(@reentrydate, '')) <> '' AND ISDATE(@reentrydate) = 1
            SET @fecha_reingreso = CONVERT(DATETIME, @reentrydate, 120);

        IF RTRIM(ISNULL(@ceasedate, '')) <> '' AND ISDATE(@ceasedate) = 1
            SET @fecha_cese = CONVERT(DATETIME, @ceasedate, 120);

        IF RTRIM(ISNULL(@ceasedate, '')) <> '' AND @fecha_cese IS NULL
        BEGIN
            RAISERROR('La fecha de cese indicada no es válida.', 16, 1);
            RETURN;
        END

        IF @fecha_cese IS NOT NULL AND NULLIF(LTRIM(RTRIM(ISNULL(@ceasereason, ''))), '') IS NULL
        BEGIN
            RAISERROR('Indique el motivo de cese cuando registra una fecha de cese.', 16, 1);
            RETURN;
        END
    END

    IF RTRIM(ISNULL(@sueldo, '')) <> ''
    BEGIN
        BEGIN TRY
            SET @rembasica = CONVERT(NUMERIC(18, 4), REPLACE(@sueldo, ',', ''));
        END TRY
        BEGIN CATCH
            SET @rembasica = NULL;
        END CATCH
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
        ceasedate = @fecha_cese,
        ceasereason = CASE
            WHEN @fecha_cese IS NULL THEN NULL
            ELSE NULLIF(LTRIM(RTRIM(@ceasereason)), '')
        END,
        Status = CASE
            WHEN @modo_reingreso = 'Y' THEN 'N'
            ELSE @status
        END,
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
        flagasigfamiliar = @flagasigfamiliar,
        xlastdate = GETDATE(),
        xlastuser = NULLIF(LTRIM(RTRIM(@xlastuser)), '')
    WHERE company = @cia
      AND person = @person;
END
GO
