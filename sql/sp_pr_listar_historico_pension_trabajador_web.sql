/*
    Lista histórico de régimen pensionario / inscripción (PR_HistoricoPension).
    Usado por: GET /api/trabajadores/historico-pension

    Si aún no hay filas, devuelve el régimen actual de PR_Employee (si existe).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_historico_pension_trabajador_web]
    @cia    VARCHAR(10),
    @person VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @person = LTRIM(RTRIM(ISNULL(@person, '')));

    IF @cia = '' OR @person = ''
    BEGIN
        RAISERROR('Indique compañía y trabajador.', 16, 1);
        RETURN;
    END

    IF OBJECT_ID(N'dbo.PR_HistoricoPension', N'U') IS NULL
    BEGIN
        /* Sin tabla: devolver solo el estado actual de ficha. */
        SELECT
            ISNULL(NULLIF(LTRIM(RTRIM(pt.Description)), ''), LTRIM(RTRIM(ISNULL(e.PensionType, '')))) AS regimen_pension,
            CASE
                WHEN e.PensionInscriptionDate IS NULL THEN ''
                ELSE CONVERT(VARCHAR(10), e.PensionInscriptionDate, 23)
            END AS fecha_inscripcion,
            e.PensionType AS pensiontype,
            'Y' AS vigente
        FROM PR_Employee e (NOLOCK)
        LEFT JOIN PR_PensionType pt (NOLOCK)
            ON pt.PensionType = e.PensionType
        WHERE e.Company = @cia
          AND e.Person = @person
          AND (
                NULLIF(LTRIM(RTRIM(ISNULL(e.PensionType, ''))), '') IS NOT NULL
             OR e.PensionInscriptionDate IS NOT NULL
          );
        RETURN;
    END

    IF EXISTS (
        SELECT 1
        FROM dbo.PR_HistoricoPension h (NOLOCK)
        WHERE h.Company = @cia
          AND h.Person = @person
    )
    BEGIN
        SELECT
            ISNULL(
                NULLIF(LTRIM(RTRIM(h.PensionTypeDesc)), ''),
                ISNULL(NULLIF(LTRIM(RTRIM(pt.Description)), ''), LTRIM(RTRIM(ISNULL(h.PensionType, ''))))
            ) AS regimen_pension,
            CASE
                WHEN h.FechaInscripcion IS NULL THEN ''
                ELSE CONVERT(VARCHAR(10), h.FechaInscripcion, 23)
            END AS fecha_inscripcion,
            h.PensionType AS pensiontype,
            CASE
                WHEN h.Line = (
                    SELECT MAX(h2.Line)
                    FROM dbo.PR_HistoricoPension h2 (NOLOCK)
                    WHERE h2.Company = @cia AND h2.Person = @person
                ) THEN 'Y'
                ELSE 'N'
            END AS vigente
        FROM dbo.PR_HistoricoPension h (NOLOCK)
        LEFT JOIN PR_PensionType pt (NOLOCK)
            ON pt.PensionType = h.PensionType
        WHERE h.Company = @cia
          AND h.Person = @person
        ORDER BY h.Line;
        RETURN;
    END

    /* Sin histórico aún: estado actual de ficha. */
    SELECT
        ISNULL(NULLIF(LTRIM(RTRIM(pt.Description)), ''), LTRIM(RTRIM(ISNULL(e.PensionType, '')))) AS regimen_pension,
        CASE
            WHEN e.PensionInscriptionDate IS NULL THEN ''
            ELSE CONVERT(VARCHAR(10), e.PensionInscriptionDate, 23)
        END AS fecha_inscripcion,
        e.PensionType AS pensiontype,
        'Y' AS vigente
    FROM PR_Employee e (NOLOCK)
    LEFT JOIN PR_PensionType pt (NOLOCK)
        ON pt.PensionType = e.PensionType
    WHERE e.Company = @cia
      AND e.Person = @person
      AND (
            NULLIF(LTRIM(RTRIM(ISNULL(e.PensionType, ''))), '') IS NOT NULL
         OR e.PensionInscriptionDate IS NOT NULL
      );
END
GO
