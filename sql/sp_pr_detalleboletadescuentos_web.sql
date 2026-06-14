/*
    Generar boletas — detalle de descuentos para el PDF.

    Usado por: generar_pdf_en_memoria (app.py).

    Parámetros:
      @cia, @process, @payrolltype, @period, @person
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_detalleboletadescuentos_web]
    @cia         VARCHAR(4),
    @process     VARCHAR(20),
    @payrolltype VARCHAR(20),
    @period      VARCHAR(20),
    @person      VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        C.person,
        pr_concepttype.shortname,
        pr_concept.printtext,
        C.conceptvalue,
        pr_concept.conceptorder
    FROM pr_concept (NOLOCK),
         pr_concepttype (NOLOCK),
         pr_employeepayrollconcept C (NOLOCK)
    WHERE C.concept = pr_concept.concept
      AND pr_concept.concepttype = pr_concepttype.concepttype
      AND C.company = @cia
      AND C.processtype = @process
      AND C.payrolltype = @payrolltype
      AND C.prperiod = @period
      AND C.person = @person
      AND ISNULL(pr_concept.flagpayrollticket, 'N') = 'Y'
      AND pr_concepttype.shortname = 'D'
    ORDER BY 5;
END
GO
