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
      @estado       — confirmación de recepción: '-1' todos, '0' pendiente,
                      '1' confirmado, '2' con observación

    Solo filas Tipodocumento = 'BOL' con FechaEnvio no nula.
    Si la BD no tiene las columnas de confirmación (alter_pr_documentperson_confirmacion.sql),
    devuelve estado_confirmacion NULL y @estado se ignora.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteenvioboletas_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20) = '0',
    @processtype VARCHAR(20) = '0',
    @period      VARCHAR(20) = '0',
    @person      VARCHAR(20) = '0',
    @estado      VARCHAR(2)  = '-1'
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
    SET @estado = LTRIM(RTRIM(ISNULL(@estado, '-1')));
    IF @estado NOT IN ('0', '1', '2') SET @estado = '-1';

    DECLARE @period6 VARCHAR(6) = NULL;
    IF @period <> '0' AND LEN(@period) >= 6
        SET @period6 = LEFT(@period, 6);
    ELSE IF @period <> '0'
        SET @period6 = @period;

    DECLARE @conConfirmacion BIT = 0;
    IF COL_LENGTH('dbo.PR_DocumentPerson', 'EstadoConfirmacion') IS NOT NULL
        SET @conConfirmacion = 1;

    DECLARE @sql NVARCHAR(MAX) = N'
    SELECT
        LTRIM(RTRIM(ISNULL(p.DocumentNumber, ''''))) AS dni,
        LTRIM(RTRIM(ISNULL(p.Name, ''''))) AS nombre,
        LTRIM(RTRIM(ISNULL(p.EMail, ''''))) AS email,
        ISNULL(
            NULLIF(LTRIM(RTRIM(pt.ShortName)), ''''),
            LTRIM(RTRIM(ISNULL(dp.payrolltype, '''')))
        ) AS tipo_planilla,
        LTRIM(RTRIM(ISNULL(dp.period, ''''))) AS periodo,
        LTRIM(RTRIM(ISNULL(dp.Filename, ''''))) AS nombre_archivo,
        CONVERT(VARCHAR(16), dp.FechaEnvio, 120) AS fecha_envio,'
    + CASE WHEN @conConfirmacion = 1 THEN N'
        CASE WHEN dp.TokenConfirmacion IS NULL THEN NULL
             ELSE dp.EstadoConfirmacion END AS estado_confirmacion,
        CONVERT(VARCHAR(16), dp.FechaConfirmacion, 120) AS fecha_confirmacion,
        dp.IpConfirmacion AS ip_confirmacion'
      ELSE N'
        CAST(NULL AS SMALLINT) AS estado_confirmacion,
        CAST(NULL AS VARCHAR(16)) AS fecha_confirmacion,
        CAST(NULL AS NVARCHAR(45)) AS ip_confirmacion'
      END + N'
    FROM PR_DocumentPerson dp
        INNER JOIN SY_Person p
            ON p.Person = dp.Person
        LEFT JOIN PR_PayRollType pt
            ON pt.Company = dp.Company
           AND pt.PayRollType = dp.payrolltype
    WHERE dp.Company = @cia
      AND dp.Tipodocumento = ''BOL''
      AND dp.FechaEnvio IS NOT NULL
      AND (@payrolltype = ''0'' OR LTRIM(RTRIM(ISNULL(dp.payrolltype, ''''))) = @payrolltype)
      AND (@processtype = ''0'' OR LTRIM(RTRIM(ISNULL(dp.processtype, ''''))) = @processtype)
      AND (
            @period6 IS NULL
         OR LEFT(LTRIM(RTRIM(ISNULL(dp.period, ''''))), 6) = @period6
         OR LTRIM(RTRIM(ISNULL(dp.period, ''''))) = @period
      )
      AND (@person = ''0'' OR dp.Person = @person)'
    + CASE WHEN @conConfirmacion = 1 THEN N'
      AND (@estado = ''-1''
           OR (dp.TokenConfirmacion IS NOT NULL AND dp.EstadoConfirmacion = CONVERT(SMALLINT, @estado)))'
      ELSE N'' END + N'
    ORDER BY
        dp.FechaEnvio DESC,
        p.Name,
        dp.period,
        dp.Line;';

    EXEC sp_executesql
        @sql,
        N'@cia VARCHAR(4), @payrolltype VARCHAR(20), @processtype VARCHAR(20),
          @period VARCHAR(20), @period6 VARCHAR(6), @person VARCHAR(20), @estado VARCHAR(2)',
        @cia = @cia,
        @payrolltype = @payrolltype,
        @processtype = @processtype,
        @period = @period,
        @period6 = @period6,
        @person = @person,
        @estado = @estado;
END
GO
