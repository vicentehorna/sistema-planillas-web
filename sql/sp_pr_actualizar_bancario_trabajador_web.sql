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
