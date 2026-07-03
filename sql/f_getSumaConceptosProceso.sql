/*
    Suma valores de uno o varios conceptos en un rango de periodos y proceso.
    @conceptlist: IDs separados por | (pipe). Si vacío, devuelve 0.
*/
CREATE OR ALTER FUNCTION [dbo].[f_getSumaConceptosProceso](
    @cia           VARCHAR(20),
    @person        VARCHAR(20),
    @payrolltype   VARCHAR(20),
    @process       VARCHAR(20),
    @period_begin  VARCHAR(20),
    @period_end    VARCHAR(20),
    @conceptlist   VARCHAR(500)
)
RETURNS NUMERIC(19, 4)
AS
BEGIN
    DECLARE @result NUMERIC(19, 4);
    DECLARE @xml XML;

    IF ISNULL(LTRIM(RTRIM(@conceptlist)), '') = ''
        RETURN 0;

    IF @period_begin IS NULL OR @period_end IS NULL
        RETURN 0;

    SET @xml = CAST(
        '<i>' + REPLACE(REPLACE(LTRIM(RTRIM(@conceptlist)), '&', '&amp;'), '|', '</i><i>') + '</i>' AS XML
    );

    SELECT @result = SUM(ISNULL(epc.ConceptValueLo, epc.ConceptValue))
    FROM PR_EmployeePayRollConcept epc (NOLOCK)
        INNER JOIN (
            SELECT LTRIM(RTRIM(T.c.value('.', 'VARCHAR(20)'))) AS Concept
            FROM @xml.nodes('/i') AS T(c)
            WHERE LTRIM(RTRIM(T.c.value('.', 'VARCHAR(20)'))) <> ''
        ) c ON epc.Concept = c.Concept
    WHERE epc.Company = @cia
      AND epc.PayRollType = @payrolltype
      AND epc.Person = @person
      AND epc.PRPeriod BETWEEN @period_begin AND @period_end
      AND epc.ProcessType = @process;

    RETURN ISNULL(@result, 0);
END
GO
