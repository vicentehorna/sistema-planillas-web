/*
    sp_pr_reportecontratistas_web — Planilla de Contratistas (hm_divisa).
    Versión web de sp_pr_reportecontratistas (PowerBuilder): mismo layout de 16 filas,
    sin tabla física PR_REPORTECONTRATISTA ni cursor (seguro con usuarios concurrentes).

    Parámetros:
      @cia        — compañía
      @payroll    — tipo de planilla (PR_PayRollType.PayRollType)
      @process    — proceso (PR_ProcessType.ProcessType)
      @period     — PRPeriod (se compara por mes: LEFT(@period, 6))
      @person     — '0' = todos
      @cesados    — T = todos, Y = solo cesados, N = sin cese

    Resultado: fila, es_titulo, detalle, cantidad, montoplanilla, porcentaje, banco,
               fechapago, montopagado, company
    Filas título: 1, 6 y 10.

    Usado por: POST /reporte_contratistas
*/
CREATE OR ALTER PROCEDURE dbo.sp_pr_reportecontratistas_web
    @cia      VARCHAR(20),
    @payroll  VARCHAR(20),
    @process  VARCHAR(20),
    @period   VARCHAR(20),
    @person   VARCHAR(20) = '0',
    @cesados  CHAR(1)     = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payroll = LTRIM(RTRIM(ISNULL(@payroll, '')));
    SET @process = LTRIM(RTRIM(ISNULL(@process, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '0')));
    IF @person = '' SET @person = '0';
    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';

    DECLARE @mes CHAR(6) = LEFT(@period, 6);

    DECLARE @filas TABLE (
        fila        INT           NOT NULL PRIMARY KEY,
        es_titulo   CHAR(1)       NOT NULL,
        detalle     NVARCHAR(255) NOT NULL,
        porcentaje  NVARCHAR(100) NULL,
        banco       NVARCHAR(255) NULL
    );

    DECLARE @mapa TABLE (
        fila         INT         NOT NULL,
        formulacode  VARCHAR(50) NOT NULL
    );

    INSERT INTO @filas (fila, es_titulo, detalle, porcentaje, banco) VALUES
        (1,  'Y', N'FORMATO F- PLAME -PDT', NULL, NULL),
        (2,  'N', N'ESSALUD', N'9%', N'BNAC'),
        (3,  'N', N'ESSALUD VIDA', N'5.00 SOLES', NULL),
        (4,  'N', N'ONP', N'13%', N'BNAC'),
        (5,  'N', N'RENTA DE 5° CATEGORÍA', N'8%,15%, 17%Renta Neta', N'BNAC'),
        (6,  'Y', N'SCTR MAPFRE SEGUROS (PRIMA)', NULL, NULL),
        (7,  'N', N'SCTR PENSION', N'0.65%', N'BCP'),
        (8,  'N', N'SCTR SALUD', N'0.65%', N'BCP'),
        (9,  'N', N'VIDA LEY DL 688', N'0.45% Emp. y 0.65% Obr.', N'BCP'),
        (10, 'Y', N'CONCEPTOS Y APORTACIONES DEL TRABAJADOR', NULL, NULL),
        (11, 'N', N'INCREMENTO 2% TRABAJADOR (LEY 27252)', NULL, NULL),
        (12, 'N', N'AFP INTEGRA', N'12.96%+1% Trab+1%Empl.', N'BCP'),
        (13, 'N', N'AFP HORIZONTE', N'', NULL),
        (14, 'N', N'AFP PRIMA', N'13.04%+1% Trab+1%Empl.', N'BCP'),
        (15, 'N', N'AFP PROFUTURO', N'13.56% +1% Trab.+1%Empl.', N'BCP'),
        (16, 'N', N'AFP HABITAT', N'13.56% +1% Trab.+1%Empl.', N'BCP');

    -- En hm_divisa el concepto AFP_HORIZONTE es "AFP HABITAT" (fila 13 Horizonte va en cero).
    INSERT INTO @mapa (fila, formulacode) VALUES
        (2,  'ESSALUD9'),
        (3,  'ESSALUD_VIDA'),
        (4,  'ONP'),
        (5,  'RET_5TA_CATEGORIA'),
        (7,  'SCTR_PEN_PART'),
        (8,  'SCTR_SALUD_PART'),
        (9,  'VIDALEY'),
        (12, 'AFP_INTEGRA'),
        (14, 'AFP_PRIMA'),
        (15, 'AFP_PROFUTURO'),
        (16, 'AFP_HORIZONTE'),
        (16, 'AFP_HABITAT');

    DECLARE @fechapago DATETIME = (
        SELECT MAX(XLastDate)
        FROM PR_PayrollLog (NOLOCK)
        WHERE Company = @cia
          AND ProcessType = @process
          AND PayRollType = @payroll
          AND LEFT(PRPeriod, 6) = @mes
    );

    ;WITH datos AS (
        SELECT M.fila,
               COUNT(*) AS cantidad,
               SUM(ISNULL(EPC.ConceptValueLo, 0)) AS importe
        FROM PR_EmployeePayRollConcept EPC (NOLOCK)
            INNER JOIN PR_EmployeePayRoll EP (NOLOCK)
                ON EPC.Company = EP.Company
               AND EPC.PayRollType = EP.PayRollType
               AND EPC.ProcessType = EP.ProcessType
               AND EPC.PRPeriod = EP.PRPeriod
               AND EPC.Person = EP.Person
            INNER JOIN PR_Concept C (NOLOCK)
                ON C.Concept = EPC.Concept
            INNER JOIN @mapa M
                ON M.formulacode = C.FormulaCode
            LEFT JOIN PR_Employee E (NOLOCK)
                ON E.Company = EPC.Company
               AND E.Person = EPC.Person
        WHERE EP.Company = @cia
          AND EP.ProcessType = @process
          AND EP.PayRollType = @payroll
          AND LEFT(EP.PRPeriod, 6) = @mes
          AND (@person = '0' OR EP.Person = @person)
          AND (
                @cesados = 'T'
             OR (@cesados = 'Y' AND E.CeaseDate IS NOT NULL)
             OR (@cesados = 'N' AND E.CeaseDate IS NULL)
          )
        GROUP BY M.fila
    )
    SELECT F.fila,
           F.es_titulo,
           F.detalle,
           CASE WHEN F.es_titulo = 'Y' THEN NULL ELSE ISNULL(D.cantidad, 0) END AS cantidad,
           CASE WHEN F.es_titulo = 'Y' THEN NULL ELSE CAST(ISNULL(D.importe, 0) AS NUMERIC(19, 2)) END AS montoplanilla,
           F.porcentaje,
           F.banco,
           CASE WHEN F.es_titulo = 'Y' OR NOT EXISTS (SELECT 1 FROM @mapa X WHERE X.fila = F.fila)
                THEN NULL ELSE @fechapago END AS fechapago,
           CASE WHEN F.es_titulo = 'Y' THEN NULL ELSE CAST(ISNULL(D.importe, 0) AS NUMERIC(19, 2)) END AS montopagado,
           @cia AS company
    FROM @filas F
        LEFT JOIN datos D ON D.fila = F.fila
    ORDER BY F.fila;
END
GO
