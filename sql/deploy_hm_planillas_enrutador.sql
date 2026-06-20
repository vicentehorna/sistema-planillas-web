/*
  DEPLOY ENRUTADOR - Ejecutar UNA SOLA VEZ en hm_planillas
  Relaciona usuarios web con la base de datos del cliente.

  Ejemplo de datos:
    INSERT INTO USUARIOS_ROUTER (usuario, base_datos_name) VALUES ('vhorna', 'hm_aci');
    INSERT INTO USUARIOS_ROUTER (usuario, base_datos_name) VALUES ('jmendoza', 'hm_ultra');
*/

SET NOCOUNT ON;
GO

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
