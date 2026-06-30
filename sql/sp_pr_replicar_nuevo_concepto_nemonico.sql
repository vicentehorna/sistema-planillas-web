/*
    Replica un concepto por nemónico (FormulaCode) desde una compañía origen
    hacia una compañía destino, dentro de la misma base (hm_aci).

    Uso típico BGT -> SB03:
        EXEC dbo.sp_pr_replicar_nuevo_concepto_nemonico
            @cia = 'SB03',
            @formulacode = 'CANTHECTS';
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_replicar_nuevo_concepto_nemonico]
    @cia         VARCHAR(20),
    @formulacode VARCHAR(50),
    @cia_origen  VARCHAR(4) = 'BGT'
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id  VARCHAR(20);
    DECLARE @msg VARCHAR(500);

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @formulacode = LTRIM(RTRIM(ISNULL(@formulacode, '')));
    SET @cia_origen = LTRIM(RTRIM(ISNULL(@cia_origen, 'BGT')));

    IF @cia = '' OR @formulacode = ''
    BEGIN
        RAISERROR('Indique compañía destino y formulacode.', 16, 1);
        RETURN;
    END;

    IF @cia = @cia_origen
    BEGIN
        RAISERROR('La compañía destino debe ser distinta de la compañía origen.', 16, 1);
        RETURN;
    END;

    IF EXISTS (
        SELECT 1
        FROM PR_Concept
        WHERE Company = @cia
          AND FormulaCode = @formulacode
    )
    BEGIN
        SELECT
            c.Concept AS concept,
            c.FormulaCode AS formulacode,
            'El concepto ya existe en la compañía destino.' AS mensaje
        FROM PR_Concept c
        WHERE c.Company = @cia
          AND c.FormulaCode = @formulacode;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1
        FROM PR_Concept
        WHERE Company = @cia_origen
          AND FormulaCode = @formulacode
    )
    BEGIN
        SET @msg = 'No existe concepto origen en ' + @cia_origen
                 + ' con formulacode ' + @formulacode + '.';
        RAISERROR(@msg, 16, 1);
        RETURN;
    END;

    EXEC SP_SY_ObjectSecuence_Edit 'PR_CONCEPT', @cia, 'LIMA', @id OUTPUT;

    INSERT INTO PR_Concept (
        concept,
        Validation,
        ConceptGroup,
        ConceptType,
        FormulaCode,
        ConceptOrder,
        Description,
        ConceptCurrency,
        FlagIsMonetary,
        PrintText,
        FlagLiquidation,
        LiquidationText,
        LiquidationOrder,
        LiquidationSection,
        Flagassign,
        Status,
        Company,
        ReplicationUnit,
        XLastUser,
        XLastDate,
        flagcontract,
        FlagPayrollTicket,
        FlagPrevConcept,
        FLAGTEXTVALUEPRINT,
        pdt,
        flagconceptdeclare,
        RentOrder,
        PercentageDistribution,
        associatedconcept,
        formulacodeinterfaz
    )
    SELECT
        @id,
        T.Validation,
        (
            SELECT CGd.ConceptGroup
            FROM PR_ConceptGroup CGd
            WHERE CGd.Company = @cia
              AND CGd.Description = (
                    SELECT CGs.Description
                    FROM PR_ConceptGroup CGs
                    WHERE CGs.ConceptGroup = T.ConceptGroup
                      AND CGs.Company = T.Company
                )
        ),
        (
            SELECT CTd.ConceptType
            FROM PR_ConceptType CTd
            WHERE CTd.Company = @cia
              AND CTd.ShortName = (
                    SELECT CTs.ShortName
                    FROM PR_ConceptType CTs
                    WHERE CTs.ConceptType = T.ConceptType
                      AND CTs.Company = T.Company
                )
        ),
        T.FormulaCode,
        T.ConceptOrder,
        T.Description,
        T.ConceptCurrency,
        T.FlagIsMonetary,
        T.PrintText,
        T.FlagLiquidation,
        T.LiquidationText,
        T.LiquidationOrder,
        T.LiquidationSection,
        T.Flagassign,
        T.Status,
        @cia,
        'LIMA',
        'REPLICACIA',
        GETDATE(),
        T.flagcontract,
        T.FlagPayrollTicket,
        T.FlagPrevConcept,
        T.FLAGTEXTVALUEPRINT,
        T.pdt,
        T.flagconceptdeclare,
        T.RentOrder,
        T.PercentageDistribution,
        (
            SELECT Cd.Concept
            FROM PR_Concept Cs
            INNER JOIN PR_Concept Cd
                ON Cd.Company = @cia
               AND Cd.FormulaCode = Cs.FormulaCode
            WHERE Cs.Company = T.Company
              AND Cs.Concept = T.associatedconcept
        ),
        T.formulacodeinterfaz
    FROM PR_Concept T
    WHERE T.Company = @cia_origen
      AND T.FormulaCode = @formulacode;

    SELECT
        @id AS concept,
        @formulacode AS formulacode,
        'Concepto replicado correctamente.' AS mensaje;
END
GO
