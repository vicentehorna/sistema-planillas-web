/*
    Cuenta días con descanso médico (PDT) en un rango sumando tramos recortados.
    Si hay tramos superpuestos el mismo día puede contarse más de una vez (caso raro).
    Usado por sp_pr_saldovacaciones_web.
*/
CREATE OR ALTER FUNCTION [dbo].[f_count_medical_rest_days_web]
(
    @company       CHAR(4),
    @person        VARCHAR(20),
    @pdt           VARCHAR(2),
    @range_start   DATETIME,
    @range_end     DATETIME,
    @inclusive_end BIT
)
RETURNS INT
AS
BEGIN
    DECLARE @eff_end DATETIME;
    DECLARE @result INT = 0;

    IF @range_start IS NULL OR @range_end IS NULL
        RETURN 0;

    SET @range_start = CAST(@range_start AS DATE);
    SET @range_end = CAST(@range_end AS DATE);

    IF @inclusive_end = 0
        SET @eff_end = DATEADD(DAY, -1, @range_end);
    ELSE
        SET @eff_end = @range_end;

    IF @eff_end < @range_start
        RETURN 0;

    SELECT @result = ISNULL(SUM(
        CASE
            WHEN bounds.rs <= bounds.re THEN DATEDIFF(DAY, bounds.rs, bounds.re) + 1
            ELSE 0
        END
    ), 0)
    FROM PR_EmployeeMedicalRest emr
        INNER JOIN PR_MedicalRestType mrt
            ON emr.MedicalRestType = mrt.MedicalRestType
           AND mrt.PDT = @pdt
        CROSS APPLY (
            SELECT
                CASE
                    WHEN CAST(emr.DateBegin AS DATE) > @range_start THEN CAST(emr.DateBegin AS DATE)
                    ELSE @range_start
                END AS rs,
                CASE
                    WHEN CAST(emr.DateEnd AS DATE) < @eff_end THEN CAST(emr.DateEnd AS DATE)
                    ELSE @eff_end
                END AS re
        ) bounds
    WHERE emr.Person = @person
      AND emr.Company = @company
      AND CAST(emr.DateBegin AS DATE) <= @eff_end
      AND CAST(emr.DateEnd AS DATE) >= @range_start;

    RETURN ISNULL(@result, 0);
END
GO
