/*
    Traslada PR_TareoGeneral (ancho) → PR_REGISTERHOUR (1 fila por día).
    Versión web set-based: sin cursor, sin SQL dinámico, secuencia bulk.

    Reglas de negocio (hm_ultra):
      - Un trabajador puede estar en varios tareos del mes, pero no el mismo día.
      - Al reprocesar: limpia filas de este tareoheader y cualquier
        Person+Company+fecha que este tareo vaya a regenerar.

    Cálculo de horas (equivalente a sp_pr_TrasladarTareo legado):
      @horasdia = 8
      hourday / extrahour25 / extrahour35 / extrahour100 / descansolab
      según tipo de día.

    Usado por: POST /api/tareo/registro/guardar (automático tras guardar).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_trasladar_tareo_web]
    @cia         VARCHAR(4),
    @idtareo     VARCHAR(20),
    @xlastuser   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @horasdia NUMERIC(19, 4) = 8;
    DECLARE @now DATETIME = GETDATE();
    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @n INT = 0;
    DECLARE @seq_start NUMERIC(18, 0);
    DECLARE @seq_end NUMERIC(18, 0);
    DECLARE @company_hdr VARCHAR(4);
    DECLARE @repunit_hdr VARCHAR(20);
    DECLARE @costcenter_hdr VARCHAR(20);

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @idtareo = LTRIM(RTRIM(ISNULL(@idtareo, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');
    IF @xlastuser IS NULL SET @xlastuser = 'WEB';

    IF @cia = '' OR @idtareo = ''
    BEGIN
        RAISERROR('Indique compañía y tareo.', 16, 1);
        RETURN;
    END;

    SELECT
        @company_hdr = LTRIM(RTRIM(ISNULL(H.company, ''))),
        @repunit_hdr = NULLIF(LTRIM(RTRIM(ISNULL(H.replicationunit, ''))), ''),
        @costcenter_hdr = NULLIF(LTRIM(RTRIM(ISNULL(H.costcenter, ''))), '')
    FROM PR_TareoHeader H (NOLOCK)
    WHERE H.TareoHeader = @idtareo;

    IF @company_hdr IS NULL
    BEGIN
        RAISERROR('El tareo no existe.', 16, 1);
        RETURN;
    END;

    IF @company_hdr <> @cia
    BEGIN
        RAISERROR('El tareo no pertenece a la compañía indicada.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM SY_ObjectSecuence (NOLOCK)
        WHERE Company = @cia
          AND Object = 'PR_REGHOUR'
          AND ReplicationUnit = @replicationunit
    )
    BEGIN
        RAISERROR(
            'No existe correlativo PR_REGHOUR / LIMA para la compañía %s.',
            16, 1, @cia
        );
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        ;WITH src AS (
            SELECT
                G.line,
                LTRIM(RTRIM(ISNULL(G.person, ''))) AS person,
                LTRIM(RTRIM(ISNULL(G.Prperiod, H.prperiod))) AS prperiod,
                LTRIM(RTRIM(ISNULL(G.payrolltype, H.payrolltype))) AS payrolltype,
                ISNULL(@repunit_hdr, H.replicationunit) AS replicationunit,
                D.dia,
                UPPER(LTRIM(RTRIM(ISNULL(D.tipo, '')))) AS tipo,
                CONVERT(NUMERIC(19, 4), ISNULL(D.horas, 0)) AS horas
            FROM PR_TareoGeneral G (NOLOCK)
            INNER JOIN PR_TareoHeader H (NOLOCK)
                ON H.TareoHeader = G.TareoHeader
            CROSS APPLY (VALUES
                (1,  G.tipo01, G.hour01), (2,  G.tipo02, G.hour02), (3,  G.tipo03, G.hour03),
                (4,  G.tipo04, G.hour04), (5,  G.tipo05, G.hour05), (6,  G.tipo06, G.hour06),
                (7,  G.tipo07, G.hour07), (8,  G.tipo08, G.hour08), (9,  G.tipo09, G.hour09),
                (10, G.tipo10, G.hour10), (11, G.tipo11, G.hour11), (12, G.tipo12, G.hour12),
                (13, G.tipo13, G.hour13), (14, G.tipo14, G.hour14), (15, G.tipo15, G.hour15),
                (16, G.tipo16, G.hour16), (17, G.tipo17, G.hour17), (18, G.tipo18, G.hour18),
                (19, G.tipo19, G.hour19), (20, G.tipo20, G.hour20), (21, G.tipo21, G.hour21),
                (22, G.tipo22, G.hour22), (23, G.tipo23, G.hour23), (24, G.tipo24, G.hour24),
                (25, G.tipo25, G.hour25), (26, G.tipo26, G.hour26), (27, G.tipo27, G.hour27),
                (28, G.tipo28, G.hour28), (29, G.tipo29, G.hour29), (30, G.tipo30, G.hour30),
                (31, G.tipo31, G.hour31)
            ) D(dia, tipo, horas)
            WHERE G.TareoHeader = @idtareo
              AND LTRIM(RTRIM(ISNULL(G.person, ''))) <> ''
        ),
        days AS (
            SELECT
                s.person,
                s.prperiod,
                s.payrolltype,
                s.replicationunit,
                s.dia,
                CASE WHEN s.tipo = '' THEN 'X' ELSE s.tipo END AS tipo,
                s.horas,
                LEFT(s.prperiod, 6) + RIGHT('0' + CONVERT(VARCHAR(2), s.dia), 2) AS fecha8
            FROM src s
            WHERE LEN(LTRIM(RTRIM(ISNULL(s.prperiod, '')))) >= 6
              AND ISDATE(LEFT(s.prperiod, 6) + RIGHT('0' + CONVERT(VARCHAR(2), s.dia), 2)) = 1
        )
        SELECT
            ROW_NUMBER() OVER (ORDER BY person, dia) AS rn,
            person,
            payrolltype,
            replicationunit,
            tipo,
            horas,
            CONVERT(DATETIME, fecha8, 112) AS registerdate,
            fecha8
        INTO #days
        FROM days;

        SELECT @n = COUNT(1) FROM #days;

        -- Limpia este tareo y cualquier Person+fecha que se regenerará
        DELETE FROM PR_REGISTERHOUR
        WHERE tareoheader = @idtareo;

        IF @n > 0
        BEGIN
            DELETE RH
            FROM PR_REGISTERHOUR RH
            INNER JOIN #days D
                ON RH.Person = D.person
               AND RH.Company = @cia
               AND CONVERT(VARCHAR(8), RH.RegisterDate, 112) = D.fecha8;

            UPDATE SY_ObjectSecuence WITH (UPDLOCK, HOLDLOCK)
            SET @seq_start = Secuence + 1,
                @seq_end = Secuence + @n,
                Secuence = Secuence + @n,
                XLastUser = @xlastuser,
                XLastDate = @now
            WHERE Company = @cia
              AND Object = 'PR_REGHOUR'
              AND ReplicationUnit = @replicationunit;

            IF @seq_start IS NULL
            BEGIN
                RAISERROR('No se pudo reservar correlativos PR_REGHOUR.', 16, 1);
            END;

            INSERT INTO PR_REGISTERHOUR (
                Registerhour, Person, RegisterDate, RegisterType, personname,
                hourday, extrahour25, extrahour35, extrahour100,
                ReplicationUnit, Company, XLastDate, XLastuser,
                Payrolltype, descansolab, tareoheader, CostCenter
            )
            SELECT
                LEFT(@replicationunit + SPACE(3), 4)
                    + LEFT(@cia + SPACE(3), 4)
                    + RIGHT(REPLICATE('0', 11) + CONVERT(VARCHAR(20), CONVERT(BIGINT, @seq_start + D.rn - 1)), 12),
                D.person,
                D.registerdate,
                D.tipo,
                LTRIM(RTRIM(ISNULL(P.Name, ''))),
                /* hourday */
                CASE
                    WHEN D.tipo IN ('D', 'DP', 'D9', 'D10', 'D11', 'D6', 'D7', 'HP') THEN
                        CASE WHEN D.horas - @horasdia > 0 THEN @horasdia ELSE D.horas END
                    ELSE 0
                END,
                /* extrahour25 */
                CASE
                    WHEN D.tipo IN ('D', 'DP', 'D9', 'D10', 'D11', 'D6', 'D7',
                                    'N', 'NP', 'N9', 'N10', 'N11', 'N13', 'N14') THEN
                        CASE
                            WHEN D.horas >= 8 THEN
                                CASE WHEN (D.horas - @horasdia) > 2 THEN 2 ELSE (D.horas - @horasdia) END
                            ELSE 0
                        END
                    ELSE 0
                END,
                /* extrahour35 */
                CASE
                    WHEN D.tipo IN ('D', 'DP', 'D9', 'D10', 'D11', 'D6', 'D7',
                                    'N', 'NP', 'N9', 'N10', 'N11', 'N13', 'N14') THEN
                        CASE WHEN (D.horas - @horasdia) > 2 THEN (D.horas - @horasdia) - 2 ELSE 0 END
                    ELSE 0
                END,
                /* extrahour100 */
                CASE
                    WHEN D.tipo IN ('N', 'NP', 'N9', 'N10', 'N11', 'N13', 'N14') THEN
                        CASE WHEN D.horas - @horasdia > 0 THEN @horasdia ELSE D.horas END
                    WHEN D.tipo = 'FTN' THEN
                        CASE WHEN D.horas - @horasdia > 0 THEN @horasdia ELSE D.horas END
                    ELSE 0
                END,
                LEFT(ISNULL(D.replicationunit, @replicationunit) + SPACE(3), 4),
                @cia,
                @now,
                @xlastuser,
                D.payrolltype,
                CASE WHEN D.tipo IN ('FTN', 'FTD') THEN D.horas ELSE 0 END,
                @idtareo,
                @costcenter_hdr
            FROM #days D
            LEFT JOIN SY_Person P (NOLOCK)
                ON P.Person = D.person;
        END;

        UPDATE PR_TareoHeader
        SET LastProcessDate = @now
        WHERE TareoHeader = @idtareo
          AND company = @cia;

        COMMIT TRANSACTION;

        SELECT
            @idtareo AS tareoheader,
            @n AS filas,
            'Tareo procesado en PR_REGISTERHOUR.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
