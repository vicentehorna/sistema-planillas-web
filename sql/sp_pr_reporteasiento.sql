/*
    Prepara xx_asiento para exportación Alvisoft / TXT de asiento.

    Centro de costo: usa AC_CostCenter.CCCode (p.ej. 040101), no el nombre
    (p.ej. PROYECTOS) ni PR_Employee.CostCenterName cuando este guarda descripción.

    Compatible con xx_asiento de 9 columnas (sin afp/comments) o 11.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reporteasiento]
    @company     CHAR(4),
    @payrolltype VARCHAR(20),
    @processtype VARCHAR(20),
    @period      VARCHAR(8),
    @person_all  CHAR(1),
    @personid    VARCHAR(20),
    @voucher     VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM xx_asiento;

    IF OBJECT_ID('tempdb..#xx_asiento_src') IS NOT NULL
        DROP TABLE #xx_asiento_src;

    SELECT
        ROW_NUMBER() OVER (ORDER BY a.AccountCode) AS line,
        a.Voucher AS voucher,
        a.Account AS account,
        a.AccountCode AS accountcode,
        a.Person AS person,
        a.amountlo AS amount,
        (
            SELECT TOP 1 ReplicationUnit
            FROM SY_Person
            WHERE Person = a.Person
        ) AS ordentrabajo,
        (
            SELECT TOP 1 ExtensionNumber
            FROM PR_Employee
            WHERE Person = a.Person
        ) AS unidad,
        ISNULL(
            NULLIF(LTRIM(RTRIM(cc.CCCode)), ''),
            ISNULL(
                NULLIF(LTRIM(RTRIM(cc.Abbrev)), ''),
                ISNULL(
                    NULLIF(LTRIM(RTRIM(a.CostCenterCode)), ''),
                    (
                        SELECT TOP 1 CostCenterName
                        FROM PR_Employee
                        WHERE Person = a.Person
                    )
                )
            )
        ) AS centrocosto,
        a.Comments AS comments
    INTO #xx_asiento_src
    FROM AC_VoucherDetail a
    LEFT JOIN AC_CostCenter cc
        ON cc.CostCenter = a.CostCenter
    WHERE a.Voucher = @voucher;

    INSERT INTO xx_asiento (
        line, voucher, account, accountcode, person, amount,
        ordentrabajo, unidad, centrocosto
    )
    SELECT
        line, voucher, account, accountcode, person, amount,
        ordentrabajo, unidad, centrocosto
    FROM #xx_asiento_src;

    IF COL_LENGTH('dbo.xx_asiento', 'comments') IS NOT NULL
    BEGIN
        EXEC sp_executesql N'
            UPDATE x
            SET comments = s.comments
            FROM xx_asiento x
            INNER JOIN #xx_asiento_src s
                ON s.line = x.line
               AND s.voucher = x.voucher;
        ';
    END

    IF COL_LENGTH('dbo.xx_asiento', 'afp') IS NOT NULL
    BEGIN
        EXEC sp_executesql N'
            UPDATE xx_asiento
            SET afp = (
                SELECT TOP 1 afp
                FROM PR_Employee
                WHERE person = xx_asiento.person
            );
        ';
    END

    DROP TABLE #xx_asiento_src;
END
GO
