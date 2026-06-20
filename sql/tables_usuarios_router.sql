/*
    Tabla enrutadora usuario -> base de datos del cliente.
    Ejecutar SOLO en la base hm_planillas (no en hm_aci, hm_ultra, etc.).
*/
IF OBJECT_ID('dbo.USUARIOS_ROUTER', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.USUARIOS_ROUTER (
        usuario VARCHAR(50) NOT NULL PRIMARY KEY,
        base_datos_name VARCHAR(100) NOT NULL
    );
END
GO
