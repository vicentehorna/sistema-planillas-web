/*
    Guarda en PR_Mapping2 los conceptos de préstamo por proceso.
    Si no existe fila de la compañía, la crea.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardarconfiguracion_mapping2_web]
    @company                 VARCHAR(10),
    @loanconceptfinmes       VARCHAR(20) = NULL,
    @loanconceptvacaciones   VARCHAR(20) = NULL,
    @loanconceptutilidades   VARCHAR(20) = NULL,
    @loanconceptgratificacion VARCHAR(20) = NULL,
    @xlastuser               VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @loanconceptfinmes = NULLIF(LTRIM(RTRIM(ISNULL(@loanconceptfinmes, ''))), '');
    SET @loanconceptvacaciones = NULLIF(LTRIM(RTRIM(ISNULL(@loanconceptvacaciones, ''))), '');
    SET @loanconceptutilidades = NULLIF(LTRIM(RTRIM(ISNULL(@loanconceptutilidades, ''))), '');
    SET @loanconceptgratificacion = NULLIF(LTRIM(RTRIM(ISNULL(@loanconceptgratificacion, ''))), '');
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @company = ''
    BEGIN
        RAISERROR('Seleccione una empresa.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM SY_Company WHERE Company = @company)
    BEGIN
        RAISERROR('La empresa no existe.', 16, 1);
        RETURN;
    END;

    IF @loanconceptfinmes IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM PR_Concept WHERE Company = @company AND Concept = @loanconceptfinmes)
    BEGIN
        RAISERROR('Concepto Fin de Mes inválido para la compañía.', 16, 1);
        RETURN;
    END;
    IF @loanconceptvacaciones IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM PR_Concept WHERE Company = @company AND Concept = @loanconceptvacaciones)
    BEGIN
        RAISERROR('Concepto Vacaciones inválido para la compañía.', 16, 1);
        RETURN;
    END;
    IF @loanconceptutilidades IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM PR_Concept WHERE Company = @company AND Concept = @loanconceptutilidades)
    BEGIN
        RAISERROR('Concepto Utilidades inválido para la compañía.', 16, 1);
        RETURN;
    END;
    IF @loanconceptgratificacion IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM PR_Concept WHERE Company = @company AND Concept = @loanconceptgratificacion)
    BEGIN
        RAISERROR('Concepto Gratificación inválido para la compañía.', 16, 1);
        RETURN;
    END;

    IF EXISTS (SELECT 1 FROM PR_Mapping2 WHERE Company = @company)
    BEGIN
        UPDATE PR_Mapping2
        SET LoanConceptFinMes = @loanconceptfinmes,
            LoanConceptVacaciones = @loanconceptvacaciones,
            LoanConceptUtilidades = @loanconceptutilidades,
            LoanConceptGratificacion = @loanconceptgratificacion,
            XLastUser = @xlastuser,
            XLastDate = GETDATE()
        WHERE Company = @company;
    END
    ELSE
    BEGIN
        INSERT INTO PR_Mapping2 (
            Company,
            LoanConceptFinMes,
            LoanConceptVacaciones,
            LoanConceptUtilidades,
            LoanConceptGratificacion,
            XLastUser,
            XLastDate
        )
        VALUES (
            @company,
            @loanconceptfinmes,
            @loanconceptvacaciones,
            @loanconceptutilidades,
            @loanconceptgratificacion,
            @xlastuser,
            GETDATE()
        );
    END;

    SELECT
        'OK' AS ok,
        N'Configuración guardada correctamente.' AS mensaje,
        @company AS company;
END
GO
