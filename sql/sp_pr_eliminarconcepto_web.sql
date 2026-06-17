/*
    Elimina un concepto del maestro (PR_Concept) si no está en uso.

    No permite eliminar si el concepto existe en:
      - PR_EmployeeConcept
      - PR_EmployeePayRollConcept
      - PR_EmployeeAFP (vía movimientos de planilla vinculados a AFP)

    Usado por: POST /api/conceptos/eliminar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarconcepto_web]
    @company VARCHAR(4),
    @concept VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @concept = LTRIM(RTRIM(ISNULL(@concept, '')));

    IF @company = '' OR @concept = ''
    BEGIN
        RAISERROR('Indique compañía y concepto a eliminar.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Concept (NOLOCK)
        WHERE Company = @company
          AND Concept = @concept
    )
    BEGIN
        RAISERROR('El concepto no existe o no pertenece a la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_EmployeeConcept (NOLOCK)
        WHERE Company = @company
          AND Concept = @concept
    )
    BEGIN
        RAISERROR('No se puede eliminar: el concepto está asignado a empleados (PR_EmployeeConcept).', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_EmployeePayRollConcept (NOLOCK)
        WHERE Company = @company
          AND Concept = @concept
    )
    BEGIN
        RAISERROR('No se puede eliminar: el concepto tiene movimientos de planilla (PR_EmployeePayRollConcept).', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_EmployeePayRollConcept P (NOLOCK)
            INNER JOIN PR_EmployeeAFP A (NOLOCK)
                ON A.Company = P.Company
               AND A.Person = P.Person
               AND A.PayRollType = P.PayRollType
               AND LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), P.PRPeriod))), 6)
                 = LEFT(LTRIM(RTRIM(CONVERT(VARCHAR(20), A.PRPeriod))), 6)
        WHERE P.Company = @company
          AND P.Concept = @concept
    )
    BEGIN
        RAISERROR('No se puede eliminar: el concepto está vinculado a registros AFP (PR_EmployeeAFP).', 16, 1);
        RETURN;
    END;

    DELETE FROM PR_Concept
    WHERE Company = @company
      AND Concept = @concept;

    IF @@ROWCOUNT = 0
    BEGIN
        RAISERROR('No se pudo eliminar el concepto.', 16, 1);
        RETURN;
    END;

    SELECT
        @concept AS concept,
        'Concepto eliminado correctamente.' AS mensaje;
END
GO
