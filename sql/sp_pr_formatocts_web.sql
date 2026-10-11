/*
    Formato de CTS — Liquidación de depósito semestral de CTS (RPR006 de PowerBuilder).

    Lee los datos grabados por sp_pr_control_datos_cts_persona (PR_EmployeeCTS,
    PR_EmployeeCTSConcept, PR_CTSPeriod). Una fila por concepto de remuneración
    computable con los datos de cabecera repetidos.

    Usado por: generar_pdf_formato_cts (app.py)

    Parámetros:
      @cia          — compañía
      @payrolltype  — tipo de planilla
      @period       — periodo de cálculo PRPeriod (20260505, 20261111, ...)
      @person       — código persona
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_formatocts_web]
    @cia         VARCHAR(4),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @remset VARCHAR(20);
    SELECT TOP 1 @remset = CTSRemSet FROM PR_Mapping WHERE Company = @cia;

    SELECT
        LTRIM(RTRIM(
            ISNULL(SP.LastName1, '') + ' ' + ISNULL(SP.LastName2, '') + ' '
            + ISNULL(SP.Name1, '') + ' ' + ISNULL(SP.Name2, '')
        )) AS nombre,
        H.Person AS person,
        SP.DocumentNumber AS documento,
        ISNULL((SELECT DT.Description FROM SY_PersonDocumentType DT
                WHERE DT.PersonDocumentType = SP.EmployeeDocumentType), '') AS tipodocumento,
        ISNULL(POS.Description, '') AS cargo,
        C.Description AS empresa,
        C.RUC AS ruc,
        C.Address AS direccion,
        C.Representative AS representante,
        C.Rep_Position AS representante_cargo,
        C.Rep_DocNumber AS representante_documento,
        E.CTSAccount AS cuenta_cts,
        E.CTSCurrency AS moneda_cts,
        ISNULL((SELECT B.Name FROM ERP_Bank B WHERE B.Bank = E.CTSBank), '') AS banco_cts,
        ISNULL(E.ReEntryDate, E.EntryDate) AS fecha_ingreso,
        P.DateBegin AS fecha_inicio,
        P.DateEnd AS fecha_fin,
        P.PaymentDate AS fecha_pago,
        H.CTSNumber AS ctsnumber,
        H.Days AS dias,
        H.Amount AS importe,
        H.AmountLo AS importe_lo,
        H.AmountEx AS importe_ex,
        H.ExchangeRate AS tipo_cambio,
        D.Concept AS concepto,
        ISNULL(NULLIF(LTRIM(RTRIM(CO.PrintText)), ''), CO.Description) AS concepto_texto,
        CO.ConceptOrder AS concepto_orden,
        ISNULL((SELECT TOP 1 ISNULL(S.Groups, 1) FROM PR_ConceptSetDetail S
                WHERE S.ConceptSet = @remset AND S.Concept = D.Concept), 1) AS grupo,
        D.ConceptValueLo AS valor_lo,
        D.ConceptValueEx AS valor_ex
    FROM PR_EmployeeCTS H
        INNER JOIN SY_Person SP ON SP.Person = H.Person
        INNER JOIN PR_Employee E ON E.Company = H.Company AND E.Person = H.Person
        INNER JOIN SY_Company C ON C.Company = H.Company
        INNER JOIN PR_CTSPeriod P
            ON P.CTSNumber = H.CTSNumber
           AND P.PayRollType = H.PayRollType
           AND P.PRPeriod = H.PRPeriod
        LEFT JOIN PR_Position POS ON POS.Position = E.Position
        LEFT JOIN PR_EmployeeCTSConcept D
            ON D.Company = H.Company
           AND D.PayRollType = H.PayRollType
           AND D.CTSNumber = H.CTSNumber
           AND D.PRPeriod = H.PRPeriod
           AND D.Person = H.Person
        LEFT JOIN PR_Concept CO ON CO.Company = D.Company AND CO.Concept = D.Concept
    WHERE H.Company = @cia
      AND H.PayRollType = @payrolltype
      AND H.PRPeriod = @period
      AND H.Person = @person
    ORDER BY grupo, CO.ConceptOrder, concepto_texto;
END
GO
