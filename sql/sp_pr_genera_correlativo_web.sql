/*
    Genera el siguiente ID correlativo para un objeto (tabla maestra).

    Formato del ID:
      'LIMA' + LEFT(@cia + '    ', 4) + RIGHT('000000000000' + correlativo, 12)
      Ejemplo BGT:  'LIMABGT 000000001315'

    Lee e incrementa SY_ObjectSecuence (ReplicationUnit = LIMA).
    Devuelve el ID generado en resultset: id_generado.

    Usado por: sp_pr_guardarconcepto_web, sp_pr_guardarbankaccount_web,
               sp_pr_guardarposition_web y futuros maestros web.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_genera_correlativo_web]
    @cia        VARCHAR(4),
    @object     VARCHAR(20),
    @xlastuser  VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @replicationunit VARCHAR(4) = 'LIMA';
    DECLARE @secuence        NUMERIC(18, 0);
    DECLARE @next            NUMERIC(18, 0);
    DECLARE @id_generado     VARCHAR(20);
    DECLARE @prefix          VARCHAR(8);

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @object = UPPER(LTRIM(RTRIM(ISNULL(@object, ''))));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @cia = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @object = ''
    BEGIN
        RAISERROR('Indique el objeto correlativo.', 16, 1);
        RETURN;
    END;

    BEGIN TRY
        BEGIN TRANSACTION;

        SELECT @secuence = Secuence
        FROM SY_ObjectSecuence WITH (UPDLOCK, HOLDLOCK)
        WHERE Company = @cia
          AND Object = @object
          AND ReplicationUnit = @replicationunit;

        IF @secuence IS NULL
        BEGIN
            RAISERROR(
                'No existe correlativo en SY_ObjectSecuence para compañía %s, objeto %s y unidad %s.',
                16,
                1,
                @cia,
                @object,
                @replicationunit
            );
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        SET @next = @secuence + 1;
        SET @prefix = 'LIMA' + LEFT(@cia + '    ', 4);
        SET @id_generado = @prefix + RIGHT(
            '000000000000' + CONVERT(VARCHAR(12), CONVERT(BIGINT, @next)),
            12
        );

        UPDATE SY_ObjectSecuence
        SET Secuence = @next,
            XLastUser = ISNULL(@xlastuser, XLastUser),
            XLastDate = GETDATE()
        WHERE Company = @cia
          AND Object = @object
          AND ReplicationUnit = @replicationunit;

        COMMIT TRANSACTION;

        SELECT @id_generado AS id_generado;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
