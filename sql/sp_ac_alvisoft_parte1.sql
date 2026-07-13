/*
    Cabecera TXT Alvisoft (registro tipo 0000).
    Optimizado para web: no modifica empleados; solo genera la cabecera.

    Usado por: POST /api/asientos/interfaz/generar-archivo
*/
CREATE OR ALTER PROCEDURE [dbo].[SP_AC_ALVISOFT_PARTE1]
    @Voucher VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        REPLICATE('0', 7 - LEN('1')) + '1' AS nroregistro1,
        '0000' AS tiporegistro1,
        '00' AS subtiporegistro1,
        '01' AS versiontiporegistro1,
        (SELECT CODECITY FROM SY_Company WHERE Company = AC_Voucher.Company) AS compania
    FROM AC_Voucher
    WHERE Voucher = @Voucher;
END
