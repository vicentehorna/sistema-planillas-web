/*
    Reporte Envío de Boletas — registros BOL en PR_DocumentPerson con FechaEnvio.

    Usado por: POST /api/reportes/envio-boletas (reporte_envio_boletas.html).

    Parámetros:
      @cia          — compañía (obligatorio)
      @payrolltype  — tipo planilla; '0' = todos
      @processtype  — proceso; '0' = todos
      @period       — periodo PRPeriod o yyyymm; '0' = todos
                      (match por LEFT 6 dígitos vs DocumentPerson.period portal)
      @person       — código persona; '0' = todos

    Solo filas Tipodocumento = 'BOL' con FechaEnvio no nula.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteenvioboletas_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20) = '0',
    @processtype VARCHAR(20) = '0',
    @period      VARCHAR(20) = '0',
    @person      VARCHAR(20) = '0'
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '0')));
    IF @payrolltype = '' SET @payrolltype = '0';
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '0')));
    IF @processtype = '' SET @processtype = '0';
    SET @period = LTRIM(RTRIM(ISNULL(@period, '0')));
    IF @period = '' SET @period = '0';
    SET @person = LTRIM(RTRIM(ISNULL(@person, '0')));
    IF @person = '' SET @person = '0';

    DECLARE @period6 VARCHAR(6) = NULL;
    IF @period <> '0' AND LEN(@period) >= 6
        SET @period6 = LEFT(@period, 6);
    ELSE IF @period <> '0'
        SET @period6 = @period;

    SELECT
        LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''))) AS dni,
        LTRIM(RTRIM(ISNULL(p.Name, ''))) AS nombre,
        LTRIM(RTRIM(ISNULL(p.EMail, ''))) AS email,
        ISNULL(
            NULLIF(LTRIM(RTRIM(pt.ShortName)), ''),
            LTRIM(RTRIM(ISNULL(dp.payrolltype, '')))
        ) AS tipo_planilla,
        LTRIM(RTRIM(ISNULL(dp.period, ''))) AS periodo,
        LTRIM(RTRIM(ISNULL(dp.Filename, ''))) AS nombre_archivo,
        CONVERT(VARCHAR(16), dp.FechaEnvio, 120) AS fecha_envio
    FROM PR_DocumentPerson dp
        INNER JOIN SY_Person p
            ON p.Person = dp.Person
        LEFT JOIN PR_PayRollType pt
            ON pt.Company = dp.Company
           AND pt.PayRollType = dp.payrolltype
    WHERE dp.Company = @cia
      AND dp.Tipodocumento = 'BOL'
      AND dp.FechaEnvio IS NOT NULL
      AND (@payrolltype = '0' OR LTRIM(RTRIM(ISNULL(dp.payrolltype, ''))) = @payrolltype)
      AND (@processtype = '0' OR LTRIM(RTRIM(ISNULL(dp.processtype, ''))) = @processtype)
      AND (
            @period6 IS NULL
         OR LEFT(LTRIM(RTRIM(ISNULL(dp.period, ''))), 6) = @period6
         OR LTRIM(RTRIM(ISNULL(dp.period, ''))) = @period
      )
      AND (@person = '0' OR dp.Person = @person)
    ORDER BY
        dp.FechaEnvio DESC,
        p.Name,
        dp.period,
        dp.Line;
END
GO
