/*
    Elimina una fórmula completa (cabecera + detalle) en la empresa origen
    y en todas las demás empresas activas con la misma fórmula
    (FormulaCode + planilla ShortName + proceso ShortName).

    Usado por: POST /api/formulas/eliminar  (todas_cias=1)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminarformula_todas_cias_web]
    @cia           VARCHAR(4),
    @formulaheader VARCHAR(20),
    @xlastuser     VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @formulaheader = LTRIM(RTRIM(ISNULL(@formulaheader, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @cia = '' OR @formulaheader = ''
    BEGIN
        RAISERROR('Indique compañía y fórmula a eliminar.', 16, 1);
        RETURN;
    END;

    DECLARE
        @formulacode VARCHAR(50) = NULL,
        @planilla    VARCHAR(50) = NULL,
        @proceso     VARCHAR(50) = NULL;

    SELECT
        @planilla = LTRIM(RTRIM(ISNULL(prt.ShortName, ''))),
        @proceso  = LTRIM(RTRIM(ISNULL(pt.ShortName, '')))
    FROM PR_FormulaHeader fh (NOLOCK)
        INNER JOIN PR_PayRollType prt (NOLOCK)
            ON fh.Payrolltype = prt.PayRollType
        INNER JOIN PR_ProcessType pt (NOLOCK)
            ON fh.Proccestype = pt.ProcessType
    WHERE fh.Company = @cia
      AND fh.FormulaHeader = @formulaheader;

    SELECT @formulacode = LTRIM(RTRIM(ISNULL(c.FormulaCode, '')))
    FROM PR_FormulaHeader fh (NOLOCK)
        INNER JOIN PR_Concept c (NOLOCK)
            ON fh.Concept = c.Concept
           AND fh.Company = c.Company
    WHERE fh.Company = @cia
      AND fh.FormulaHeader = @formulaheader;

    IF @formulacode IS NULL OR @formulacode = ''
    BEGIN
        SELECT @formulacode = LTRIM(RTRIM(ISNULL(fh.formulacode, '')))
        FROM PR_FormulaHeader fh (NOLOCK)
        WHERE fh.Company = @cia
          AND fh.FormulaHeader = @formulaheader;
    END;

    SET @formulacode = NULLIF(LTRIM(RTRIM(@formulacode)), '');
    SET @planilla = NULLIF(@planilla, '');
    SET @proceso = NULLIF(@proceso, '');

    IF @formulacode IS NULL OR @planilla IS NULL OR @proceso IS NULL
    BEGIN
        RAISERROR(
            'No se pudo resolver FormulaCode / planilla / proceso de la fórmula origen.',
            16, 1
        );
        RETURN;
    END;

    DECLARE
        @company      VARCHAR(4),
        @fh_dest      VARCHAR(20),
        @empresas_ok  INT = 0,
        @origen_ok    BIT = 0;

    DECLARE empresas CURSOR LOCAL FAST_FORWARD FOR
        SELECT Company
        FROM SY_Company (NOLOCK)
        WHERE ISNULL(status, 'A') = 'A'
        ORDER BY CASE WHEN Company = @cia THEN 0 ELSE 1 END, Company;

    OPEN empresas;
    FETCH NEXT FROM empresas INTO @company;

    BEGIN TRY
        BEGIN TRANSACTION;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @fh_dest = NULL;

            IF @company = @cia
            BEGIN
                SET @fh_dest = @formulaheader;
            END
            ELSE
            BEGIN
                SELECT TOP 1 @fh_dest = fh.FormulaHeader
                FROM PR_FormulaHeader fh (NOLOCK)
                    INNER JOIN PR_Concept c_dest (NOLOCK)
                        ON fh.Concept = c_dest.Concept
                       AND fh.Company = c_dest.Company
                       AND LTRIM(RTRIM(ISNULL(c_dest.FormulaCode, ''))) = @formulacode
                    INNER JOIN PR_PayRollType prt (NOLOCK)
                        ON prt.Company = @company
                       AND prt.PayRollType = fh.Payrolltype
                       AND LTRIM(RTRIM(ISNULL(prt.ShortName, ''))) = @planilla
                    INNER JOIN PR_ProcessType pt (NOLOCK)
                        ON pt.Company = @company
                       AND pt.ProcessType = fh.Proccestype
                       AND LTRIM(RTRIM(ISNULL(pt.ShortName, ''))) = @proceso
                WHERE fh.Company = @company
                ORDER BY fh.FormulaHeader;
            END;

            IF @fh_dest IS NOT NULL AND @fh_dest <> ''
               AND EXISTS (
                    SELECT 1
                    FROM PR_FormulaHeader (NOLOCK)
                    WHERE Company = @company
                      AND FormulaHeader = @fh_dest
               )
            BEGIN
                DELETE FROM PR_FormulaDetail
                WHERE FormulaHeader = @fh_dest;

                DELETE FROM PR_FormulaHeader
                WHERE Company = @company
                  AND FormulaHeader = @fh_dest;

                IF @@ROWCOUNT > 0
                BEGIN
                    SET @empresas_ok = @empresas_ok + 1;
                    IF @company = @cia
                        SET @origen_ok = 1;
                END;
            END;

            FETCH NEXT FROM empresas INTO @company;
        END;

        CLOSE empresas;
        DEALLOCATE empresas;

        IF @origen_ok = 0
        BEGIN
            RAISERROR('No se pudo eliminar la fórmula en la empresa origen.', 16, 1);
            ROLLBACK TRANSACTION;
            RETURN;
        END;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        IF CURSOR_STATUS('local', 'empresas') >= 0
        BEGIN
            CLOSE empresas;
            DEALLOCATE empresas;
        END;
        DECLARE @err NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('%s', 16, 1, @err);
        RETURN;
    END CATCH;

    SELECT
        @formulaheader AS formulaheader,
        @formulacode AS formulacode,
        @empresas_ok AS empresas_afectadas,
        CASE
            WHEN @empresas_ok <= 1 THEN
                'Fórmula eliminada en la empresa actual.'
            ELSE
                'Fórmula eliminada en ' + CONVERT(VARCHAR(10), @empresas_ok)
                + ' empresas (origen + demás).'
        END AS mensaje;
END
GO
