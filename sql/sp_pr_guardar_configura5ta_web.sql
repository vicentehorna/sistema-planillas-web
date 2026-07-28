/*
    Guarda (reemplaza) la configuración de conceptos 5ta de una compañía.

    @xml filas:
      <rows>
        <r type="IN" line="1" processtype="..." concept="..." applysum="P"/>
        ...
      </rows>

    Plame siempre '14'. ApplySum por defecto 'P'.
    Usado por: POST /api/configura5ta/guardar
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardar_configura5ta_web]
    @cia      VARCHAR(4),
    @xml      XML,
    @userid   VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));

    IF @cia = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END

    IF @xml IS NULL
        SET @xml = CAST('<rows/>' AS XML);

    BEGIN TRY
        BEGIN TRANSACTION;

        DELETE FROM PR_Configura5ta
        WHERE Company = @cia;

        INSERT INTO PR_Configura5ta (
            Company, line, Plame, ProcessType, Concept, Type, ApplySum, XLastUser, XLastDate
        )
        SELECT
            @cia,
            ISNULL(r.value('@line', 'INT'), 0),
            '14',
            LTRIM(RTRIM(ISNULL(r.value('@processtype', 'VARCHAR(20)'), ''))),
            LTRIM(RTRIM(ISNULL(r.value('@concept', 'VARCHAR(20)'), ''))),
            UPPER(LTRIM(RTRIM(ISNULL(r.value('@type', 'VARCHAR(2)'), '')))),
            CASE
                WHEN UPPER(LTRIM(RTRIM(ISNULL(r.value('@applysum', 'VARCHAR(1)'), 'P')))) = 'P'
                    THEN 'P'
                ELSE 'M'
            END,
            NULLIF(@userid, ''),
            GETDATE()
        FROM @xml.nodes('/rows/r') AS T(r)
        WHERE LTRIM(RTRIM(ISNULL(r.value('@processtype', 'VARCHAR(20)'), ''))) <> ''
          AND LTRIM(RTRIM(ISNULL(r.value('@concept', 'VARCHAR(20)'), ''))) <> ''
          AND UPPER(LTRIM(RTRIM(ISNULL(r.value('@type', 'VARCHAR(2)'), '')))) IN ('IN', 'LI', 'UT', 'RE')
          AND ISNULL(r.value('@line', 'INT'), 0) > 0;

        COMMIT TRANSACTION;

        SELECT
            @cia AS company,
            COUNT(*) AS total,
            'Configuracion 5ta guardada correctamente.' AS mensaje
        FROM PR_Configura5ta (NOLOCK)
        WHERE Company = @cia;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        DECLARE @msg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@msg, 16, 1);
    END CATCH
END
GO
