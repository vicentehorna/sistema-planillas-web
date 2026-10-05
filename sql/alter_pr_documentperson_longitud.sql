/*
    PR_DocumentPerson.longitud — requerido por el registro de FechaEnvio al enviar boletas
    (database.registrar_fecha_envio_boleta / subir_boletas_portal). Sin esta columna el
    INSERT falla y el Reporte Envío de Boletas queda vacío.
    Idempotente; mismo tipo que hm_aci.
*/
IF OBJECT_ID('dbo.PR_DocumentPerson', 'U') IS NOT NULL
   AND COL_LENGTH('dbo.PR_DocumentPerson', 'longitud') IS NULL
    ALTER TABLE dbo.PR_DocumentPerson ADD longitud NUMERIC(19, 4) NULL;
GO
