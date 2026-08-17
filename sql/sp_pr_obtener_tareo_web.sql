/*
    Obtiene cabecera + detalle de un tareo.
    Resultset 1: cabecera
    Resultset 2: detalle (con nombre de persona)
    Usado por: POST /api/tareo/registro/obtener
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_obtener_tareo_web]
    @tareoheader VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @tareoheader = LTRIM(RTRIM(ISNULL(@tareoheader, '')));

    IF @tareoheader = ''
    BEGIN
        RAISERROR('Indique el tareo.', 16, 1);
        RETURN;
    END;

    IF NOT EXISTS (SELECT 1 FROM PR_TareoHeader (NOLOCK) WHERE TareoHeader = @tareoheader)
    BEGIN
        RAISERROR('El tareo no existe.', 16, 1);
        RETURN;
    END;

    SELECT
        H.TareoHeader AS tareoheader,
        H.company,
        H.payrolltype,
        LTRIM(RTRIM(ISNULL(PT.Description, ''))) AS payrolltype_name,
        H.prperiod,
        H.costcenter,
        LTRIM(RTRIM(ISNULL(CC.Name, ISNULL(CC.Description, '')))) AS costcenter_name,
        CONVERT(varchar(19), H.registerdate, 120) AS registerdate,
        CONVERT(varchar(19), H.LastProcessDate, 120) AS lastprocessdate,
        LTRIM(RTRIM(ISNULL(H.xlastuser, ''))) AS xlastuser,
        CONVERT(varchar(19), H.xlastdate, 120) AS xlastdate
    FROM PR_TareoHeader H (NOLOCK)
    LEFT JOIN PR_PayRollType PT (NOLOCK)
        ON PT.Company = H.company
       AND PT.PayRollType = H.payrolltype
    LEFT JOIN AC_CostCenter CC (NOLOCK)
        ON CC.Company = H.company
       AND CC.CostCenter = H.costcenter
    WHERE H.TareoHeader = @tareoheader;

    SELECT
        G.line,
        LTRIM(RTRIM(ISNULL(G.person, ''))) AS person,
        LTRIM(RTRIM(
            ISNULL(P.LASTNAME1, '') + ' ' +
            ISNULL(P.LASTNAME2, '') + ' ' +
            ISNULL(P.NAME1, '') + ' ' +
            ISNULL(P.NAME2, '')
        )) AS person_name,
        G.hour01, G.hour02, G.hour03, G.hour04, G.hour05, G.hour06, G.hour07, G.hour08,
        G.hour09, G.hour10, G.hour11, G.hour12, G.hour13, G.hour14, G.hour15, G.hour16,
        G.hour17, G.hour18, G.hour19, G.hour20, G.hour21, G.hour22, G.hour23, G.hour24,
        G.hour25, G.hour26, G.hour27, G.hour28, G.hour29, G.hour30, G.hour31,
        LTRIM(RTRIM(ISNULL(G.tipo01, ''))) AS tipo01,
        LTRIM(RTRIM(ISNULL(G.tipo02, ''))) AS tipo02,
        LTRIM(RTRIM(ISNULL(G.tipo03, ''))) AS tipo03,
        LTRIM(RTRIM(ISNULL(G.tipo04, ''))) AS tipo04,
        LTRIM(RTRIM(ISNULL(G.tipo05, ''))) AS tipo05,
        LTRIM(RTRIM(ISNULL(G.tipo06, ''))) AS tipo06,
        LTRIM(RTRIM(ISNULL(G.tipo07, ''))) AS tipo07,
        LTRIM(RTRIM(ISNULL(G.tipo08, ''))) AS tipo08,
        LTRIM(RTRIM(ISNULL(G.tipo09, ''))) AS tipo09,
        LTRIM(RTRIM(ISNULL(G.tipo10, ''))) AS tipo10,
        LTRIM(RTRIM(ISNULL(G.tipo11, ''))) AS tipo11,
        LTRIM(RTRIM(ISNULL(G.tipo12, ''))) AS tipo12,
        LTRIM(RTRIM(ISNULL(G.tipo13, ''))) AS tipo13,
        LTRIM(RTRIM(ISNULL(G.tipo14, ''))) AS tipo14,
        LTRIM(RTRIM(ISNULL(G.tipo15, ''))) AS tipo15,
        LTRIM(RTRIM(ISNULL(G.tipo16, ''))) AS tipo16,
        LTRIM(RTRIM(ISNULL(G.tipo17, ''))) AS tipo17,
        LTRIM(RTRIM(ISNULL(G.tipo18, ''))) AS tipo18,
        LTRIM(RTRIM(ISNULL(G.tipo19, ''))) AS tipo19,
        LTRIM(RTRIM(ISNULL(G.tipo20, ''))) AS tipo20,
        LTRIM(RTRIM(ISNULL(G.tipo21, ''))) AS tipo21,
        LTRIM(RTRIM(ISNULL(G.tipo22, ''))) AS tipo22,
        LTRIM(RTRIM(ISNULL(G.tipo23, ''))) AS tipo23,
        LTRIM(RTRIM(ISNULL(G.tipo24, ''))) AS tipo24,
        LTRIM(RTRIM(ISNULL(G.tipo25, ''))) AS tipo25,
        LTRIM(RTRIM(ISNULL(G.tipo26, ''))) AS tipo26,
        LTRIM(RTRIM(ISNULL(G.tipo27, ''))) AS tipo27,
        LTRIM(RTRIM(ISNULL(G.tipo28, ''))) AS tipo28,
        LTRIM(RTRIM(ISNULL(G.tipo29, ''))) AS tipo29,
        LTRIM(RTRIM(ISNULL(G.tipo30, ''))) AS tipo30,
        LTRIM(RTRIM(ISNULL(G.tipo31, ''))) AS tipo31
    FROM PR_TareoGeneral G (NOLOCK)
    LEFT JOIN SY_Person P (NOLOCK)
        ON P.Person = G.person
    WHERE G.TareoHeader = @tareoheader
    ORDER BY G.line;
END
GO
