/*
    Agrega dias anuales de vacaciones por tipo de planilla.
    Valor por defecto: 30 dias.
*/
IF COL_LENGTH('dbo.PR_PayRollType', 'DiasVacaciones') IS NULL
BEGIN
    ALTER TABLE dbo.PR_PayRollType
        ADD DiasVacaciones INT NOT NULL
            CONSTRAINT DF_PR_PayRollType_DiasVacaciones DEFAULT (30);
END
GO

UPDATE dbo.PR_PayRollType
SET DiasVacaciones = 30
WHERE DiasVacaciones IS NULL;
GO
