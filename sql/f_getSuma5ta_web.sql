/*
    Suma conceptos configurados en PR_Configura5ta para seguimiento de 5ta.
    Usado por: sp_pr_5ta_trabajador_web
*/
CREATE OR ALTER FUNCTION [dbo].[f_getSuma5ta_web]
(
    @cia         VARCHAR(4),
    @person      VARCHAR(20),
    @period      VARCHAR(20),
    @payrolltype VARCHAR(20),
    @type        CHAR(2)
)
RETURNS NUMERIC(19, 4)
AS
BEGIN
    DECLARE @resultado NUMERIC(19, 4);

    SET @resultado = ISNULL((
        SELECT SUM(
            ISNULL(E.ConceptValueLo, E.ConceptValue)
            * CASE WHEN P.applysum = 'P' THEN 1 ELSE -1 END
        )
        FROM PR_EmployeePayRollConcept E
            INNER JOIN PR_Mapping M
                ON E.Company = M.Company AND M.Company = @cia
            INNER JOIN PR_Configura5ta P
                ON E.Concept = P.concept
               AND E.Company = @cia
               AND E.Person = @person
               AND E.PRPeriod = @period
               AND E.PayRollType = @payrolltype
               AND E.ProcessType = P.processtype
               AND P.plame = '14'
               AND P.type = @type
    ), 0);

    RETURN @resultado;
END
GO
