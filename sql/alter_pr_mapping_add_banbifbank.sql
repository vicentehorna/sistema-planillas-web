/*
    Agrega la columna BanbifBank en PR_Mapping y la inicializa
    con el código de banco de ERP_Bank (BANCO BANBIF) por compañía.
*/
IF OBJECT_ID(N'dbo.PR_Mapping', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_Mapping', 'BanbifBank') IS NULL
BEGIN
    EXEC('ALTER TABLE dbo.PR_Mapping ADD BanbifBank VARCHAR(20) NULL');
END
GO

IF OBJECT_ID(N'dbo.PR_Mapping', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_Mapping', 'BanbifBank') IS NOT NULL
   AND OBJECT_ID(N'dbo.ERP_Bank', N'U') IS NOT NULL
BEGIN
    EXEC('
        UPDATE m
        SET BanbifBank = b.bank
        FROM dbo.PR_Mapping m
        INNER JOIN (
            SELECT Company, MIN(bank) AS bank
            FROM dbo.ERP_Bank
            WHERE name = ''BANCO BANBIF''
            GROUP BY Company
        ) b ON b.Company = m.Company
        WHERE m.BanbifBank IS NULL
    ');
END
GO
