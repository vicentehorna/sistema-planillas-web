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
