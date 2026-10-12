/*
    Solo hm_elclan.
    Campo sede en SY_Person (LIMA / PIURA / TRUJILLO) y carga inicial
    desde PR_Employee.extensionnumber, cruzando por person.

    LIM, LIMA -> LIMA
    PIU       -> PIURA
    TRU       -> TRUJILLO
*/
IF OBJECT_ID(N'dbo.SY_Person', N'U') IS NOT NULL
   AND COL_LENGTH('dbo.SY_Person', 'sede') IS NULL
BEGIN
    ALTER TABLE dbo.SY_Person ADD sede VARCHAR(20) NULL;
END
GO

UPDATE sp
SET sede = CASE UPPER(LTRIM(RTRIM(e.extensionnumber)))
        WHEN 'LIM'  THEN 'LIMA'
        WHEN 'LIMA' THEN 'LIMA'
        WHEN 'PIU'  THEN 'PIURA'
        WHEN 'TRU'  THEN 'TRUJILLO'
        ELSE sp.sede
    END
FROM dbo.SY_Person sp
INNER JOIN dbo.PR_Employee e
    ON e.person = sp.person
WHERE e.extensionnumber IS NOT NULL
  AND LTRIM(RTRIM(e.extensionnumber)) <> ''
  AND UPPER(LTRIM(RTRIM(e.extensionnumber))) IN ('LIM', 'LIMA', 'PIU', 'TRU');
GO
