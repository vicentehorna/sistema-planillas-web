/*
    Elimina un trabajador solo de la compañía indicada (@cia + @person).

    - Borra dependencias de planillas / contratos / vacaciones / etc. filtradas por Company.
    - Si el trabajador NO existe en otra compañía (PR_Employee), también elimina
      SY_Person y tablas personales sin Company (p.ej. PR_CapitalHumano).
    - Si existe en otra compañía, conserva SY_Person y datos generales.

    Basado en sp_pr_deleteperson (hm_aci2), adaptado a filtro por compañía.
    Usado por: POST /api/trabajadores/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_deletepersoncompany_web]
    @cia    VARCHAR(10),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @cia_n VARCHAR(10) = LTRIM(RTRIM(ISNULL(@cia, '')));
    DECLARE @person_n VARCHAR(20) = LTRIM(RTRIM(ISNULL(@person, '')));
    DECLARE @otras_cias INT = 0;
    DECLARE @borro_sy_person CHAR(1) = 'N';
    DECLARE @nombre VARCHAR(200) = '';

    IF @cia_n = '' OR @person_n = ''
    BEGIN
        RAISERROR('Debe indicar compañía y trabajador.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Employee (NOLOCK)
        WHERE Company = @cia_n
          AND Person = @person_n
    )
    BEGIN
        RAISERROR('El trabajador no existe en la compañía indicada.', 16, 1);
        RETURN;
    END;

    SELECT TOP 1
        @nombre = LTRIM(RTRIM(ISNULL(p.Name, '')))
    FROM SY_Person p (NOLOCK)
    WHERE p.Person = @person_n;

    SELECT @otras_cias = COUNT(DISTINCT e.Company)
    FROM PR_Employee e (NOLOCK)
    WHERE e.Person = @person_n
      AND e.Company <> @cia_n;

    BEGIN TRY
        BEGIN TRAN;

        DELETE FROM PR_EmployeeCTS
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_EmployeeAFP
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_EmployeeConcept
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_EmployeePayRollConcept
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_EmployeePayRoll
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_VacationProvisionedDays
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_VacationProvisionTxn
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_VacationProvision
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_VacationPay
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_VacationDetail
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_Vacation
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_TaxRentEmployee
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_PersonContract
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_EmployeeMedicalRest
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_EmployeeLoanAmortization
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_EmployeeLoan
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_EmployeeCurrentAccount
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM AR_PersonProfile
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM CA_Photocheck
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_EmployeeLocal
        WHERE Company = @cia_n
          AND (Employee = @person_n OR Person = @person_n);

        DELETE FROM SY_Dependant
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM CA_Resumenmarcas
        WHERE person = @person_n AND company = @cia_n;

        DELETE FROM ca_papeleta
        WHERE person = @person_n AND company = @cia_n;

        DELETE FROM CA_Check
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM CA_CheckSummary
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM CA_CheckApprove
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PR_EmployeeSchedule
        WHERE Person = @person_n AND Company = @cia_n;

        DELETE FROM PeriodsIndicators
        WHERE person = @person_n AND company = @cia_n;

        DELETE FROM PR_Employee
        WHERE Person = @person_n AND Company = @cia_n;

        IF @otras_cias = 0
        BEGIN
            DELETE FROM PR_CapitalHumano
            WHERE Person = @person_n;

            DELETE FROM SY_Person
            WHERE Person = @person_n;

            SET @borro_sy_person = 'Y';
        END;

        COMMIT TRAN;

        SELECT
            CAST(1 AS INT) AS ok,
            @cia_n AS cia,
            @person_n AS person,
            @nombre AS nombre,
            @borro_sy_person AS borro_sy_person,
            CASE
                WHEN @borro_sy_person = 'Y'
                    THEN 'Trabajador eliminado completamente del sistema.'
                ELSE 'Trabajador eliminado de la compania. Se conservaron sus datos generales porque existe en otra empresa.'
            END AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN;

        DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@err, 16, 1);
    END CATCH
END
GO
