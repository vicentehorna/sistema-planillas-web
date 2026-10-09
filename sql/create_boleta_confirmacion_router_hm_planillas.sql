/*
    hm_planillas (BD enrutadora): token de confirmación de boleta → BD cliente.

    El endpoint público /api/v1/boletas/confirmar no tiene sesión; con esta tabla
    resuelve en qué BD cliente está la fila PR_DocumentPerson del token.
*/
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID('dbo.BOLETA_CONFIRMACION_ROUTER', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.BOLETA_CONFIRMACION_ROUTER (
        Token           NVARCHAR(100) NOT NULL
            CONSTRAINT PK_BOLETA_CONFIRMACION_ROUTER PRIMARY KEY,
        base_datos_name NVARCHAR(128) NOT NULL,
        FechaCreacion   DATETIME2(0)  NOT NULL
            CONSTRAINT DF_BOLETA_CONFIRMACION_ROUTER_Fecha DEFAULT (GETDATE())
    );
END
GO
