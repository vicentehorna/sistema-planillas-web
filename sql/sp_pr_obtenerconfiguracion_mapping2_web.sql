/*
    Obtiene configuración PR_Mapping2 de una compañía (para pantalla Configuraciones).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtenerconfiguracion_mapping2_web]
    @company VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    IF @company = ''
    BEGIN
        RAISERROR('Seleccione una empresa.', 16, 1);
        RETURN;
    END;

    SELECT
        c.Company AS company,
        LTRIM(RTRIM(ISNULL(c.Description, ''))) AS description,
        LTRIM(RTRIM(ISNULL(c.Status, 'A'))) AS status,
        LTRIM(RTRIM(ISNULL(m.LoanConceptFinMes, ''))) AS loanconceptfinmes,
        LTRIM(RTRIM(ISNULL(m.LoanConceptVacaciones, ''))) AS loanconceptvacaciones,
        LTRIM(RTRIM(ISNULL(m.LoanConceptUtilidades, ''))) AS loanconceptutilidades,
        LTRIM(RTRIM(ISNULL(m.LoanConceptGratificacion, ''))) AS loanconceptgratificacion,
        LTRIM(RTRIM(ISNULL(m.XLastUser, ''))) AS xlastuser,
        m.XLastDate AS xlastdate
    FROM SY_Company c (NOLOCK)
    LEFT JOIN PR_Mapping2 m (NOLOCK) ON m.Company = c.Company
    WHERE c.Company = @company;
END
GO
