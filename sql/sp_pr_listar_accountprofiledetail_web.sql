/*
    Lista detalle de perfil contable (asociación concepto ↔ cuentas).
    Filtros: compañía + perfil + proceso (obligatorios) y búsqueda opcional.
    Usado por: POST /api/asientos/configurar-conceptos/listado
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_accountprofiledetail_web]
    @company         VARCHAR(4),
    @accountprofile  VARCHAR(20),
    @processtype     VARCHAR(20),
    @busqueda        VARCHAR(80) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @accountprofile = LTRIM(RTRIM(ISNULL(@accountprofile, '')));
    SET @processtype = LTRIM(RTRIM(ISNULL(@processtype, '')));
    SET @busqueda = NULLIF(LTRIM(RTRIM(ISNULL(@busqueda, ''))), '');

    IF @company = '' OR @accountprofile = '' OR @processtype = ''
    BEGIN
        RAISERROR('Indique compañía, perfil contable y proceso.', 16, 1);
        RETURN;
    END;

    SELECT
        LTRIM(RTRIM(d.Detail)) AS detail,
        LTRIM(RTRIM(d.AccountProfile)) AS accountprofile,
        LTRIM(RTRIM(d.Concept)) AS concept,
        LTRIM(RTRIM(ISNULL(c.Description, ''))) AS concept_description,
        LTRIM(RTRIM(ISNULL(c.FormulaCode, ''))) AS formulacode,
        LTRIM(RTRIM(d.ProcessType)) AS processtype,
        LTRIM(RTRIM(ISNULL(pt.Description, ''))) AS process_description,
        LTRIM(RTRIM(ISNULL(d.DebitAccount, ''))) AS debitaccount,
        LTRIM(RTRIM(ISNULL(d.DebitAccountCode, ''))) AS debitaccountcode,
        LTRIM(RTRIM(ISNULL(d.CreditAccount, ''))) AS creditaccount,
        LTRIM(RTRIM(ISNULL(d.CreditAccountCode, ''))) AS creditaccountcode,
        LTRIM(RTRIM(ISNULL(d.FlagSumType, 'T'))) AS flagsumtype,
        CASE LTRIM(RTRIM(ISNULL(d.FlagSumType, 'T')))
            WHEN 'T' THEN 'Trabajador'
            WHEN 'C' THEN 'Centro de Costo'
            WHEN 'O' THEN 'Concepto'
            ELSE LTRIM(RTRIM(ISNULL(d.FlagSumType, '')))
        END AS flagsumtype_desc,
        LTRIM(RTRIM(ISNULL(d.currency, 'LO'))) AS currency,
        LTRIM(RTRIM(ISNULL(d.Company, ''))) AS company,
        LTRIM(RTRIM(ISNULL(d.ReplicationUnit, ''))) AS replicationunit,
        LTRIM(RTRIM(ISNULL(d.XLastUser, ''))) AS xlastuser,
        d.XLastDate AS xlastdate
    FROM PR_AccountProfileDetail d (NOLOCK)
        LEFT JOIN PR_Concept c (NOLOCK)
            ON c.Concept = d.Concept
           AND c.Company = d.Company
        LEFT JOIN PR_ProcessType pt (NOLOCK)
            ON pt.ProcessType = d.ProcessType
           AND pt.Company = d.Company
    WHERE d.Company = @company
      AND d.AccountProfile = @accountprofile
      AND d.ProcessType = @processtype
      AND (
            @busqueda IS NULL
         OR ISNULL(c.Description, '') LIKE '%' + @busqueda + '%'
         OR ISNULL(c.FormulaCode, '') LIKE '%' + @busqueda + '%'
         OR ISNULL(d.DebitAccountCode, '') LIKE '%' + @busqueda + '%'
         OR ISNULL(d.CreditAccountCode, '') LIKE '%' + @busqueda + '%'
      )
    ORDER BY
        ISNULL(c.Description, ''),
        d.Detail;
END
GO
