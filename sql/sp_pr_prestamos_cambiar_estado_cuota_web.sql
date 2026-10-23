/*
    Cambia el estado de una cuota (amortización): Pendiente / Amortizado / Anulado.
    Permite reabrir cuotas Amortizadas para editar montos y volver a Amortizado.

    Usado por: POST /api/prestamos/cambiar-estado-cuota
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_prestamos_cambiar_estado_cuota_web]
    @company         VARCHAR(4),
    @person          VARCHAR(20),
    @amort_secuence  INT,
    @nuevo_status    VARCHAR(1),
    @xlastuser       VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @loansecuence INT,
        @old_status   VARCHAR(1),
        @st           VARCHAR(1),
        @now          DATETIME,
        @loan_status  VARCHAR(1);

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));
    SET @xlastuser = LEFT(LTRIM(RTRIM(ISNULL(@xlastuser, 'web'))), 20);
    SET @st = UPPER(LTRIM(RTRIM(ISNULL(@nuevo_status, ''))));
    SET @now = GETDATE();

    IF @company = '' OR @person = '' OR ISNULL(@amort_secuence, 0) <= 0
    BEGIN
        RAISERROR('Indique compañía, trabajador y cuota.', 16, 1);
        RETURN;
    END;

    IF @st NOT IN ('P', 'A', 'N')
    BEGIN
        RAISERROR('Estado inválido. Use P (Pendiente), A (Amortizado) o N (Anulado).', 16, 1);
        RETURN;
    END;

    SELECT
        @loansecuence = CONVERT(INT, ISNULL(ea.LOANSECUENCE, 0)),
        @old_status = UPPER(LTRIM(RTRIM(ISNULL(ea.Status, ''))))
    FROM PR_EmployeeLoanAmortization ea WITH (UPDLOCK, HOLDLOCK)
    WHERE ea.Company = @company
      AND ea.Person = @person
      AND ea.Secuence = @amort_secuence;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('La cuota no existe.', 16, 1);
        RETURN;
    END;

    IF ISNULL(@loansecuence, 0) <= 0
    BEGIN
        RAISERROR('La cuota no está asociada a un préstamo.', 16, 1);
        RETURN;
    END;

    IF @old_status = @st
    BEGIN
        SELECT
            @company AS company,
            @person AS person,
            @amort_secuence AS amort_secuence,
            @loansecuence AS loan_secuence,
            @st AS status,
            'OK' AS resultado;
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRAN;

        UPDATE PR_EmployeeLoanAmortization
        SET Status = @st,
            XLastUser = @xlastuser,
            XLastDate = @now
        WHERE Company = @company
          AND Person = @person
          AND Secuence = @amort_secuence;

        /* Cabecera: Anulado se respeta; si no, P si hay pendientes, A si todas amortizadas. */
        IF EXISTS (
            SELECT 1
            FROM PR_EmployeeLoan el WITH (UPDLOCK, HOLDLOCK)
            WHERE el.Company = @company
              AND el.Person = @person
              AND el.Secuence = @loansecuence
              AND UPPER(LTRIM(RTRIM(ISNULL(el.Status, '')))) = 'N'
        )
            SET @loan_status = 'N';
        ELSE IF EXISTS (
            SELECT 1
            FROM PR_EmployeeLoanAmortization ea (NOLOCK)
            WHERE ea.Company = @company
              AND ea.Person = @person
              AND ea.LOANSECUENCE = @loansecuence
              AND UPPER(LTRIM(RTRIM(ISNULL(ea.Status, '')))) = 'P'
        )
            SET @loan_status = 'P';
        ELSE
            SET @loan_status = 'A';

        UPDATE PR_EmployeeLoan
        SET Status = @loan_status,
            XLastUser = @xlastuser,
            XLastDate = @now
        WHERE Company = @company
          AND Person = @person
          AND Secuence = @loansecuence
          AND UPPER(LTRIM(RTRIM(ISNULL(Status, '')))) <> 'N';

        COMMIT TRAN;

        SELECT
            @company AS company,
            @person AS person,
            @amort_secuence AS amort_secuence,
            @loansecuence AS loan_secuence,
            @st AS status,
            @loan_status AS loan_status,
            'OK' AS resultado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
        RETURN;
    END CATCH
END
GO
