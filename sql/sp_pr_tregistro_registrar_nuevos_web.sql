/*
    Registra en lote trabajadores NUEVOS del T-Registro.
    Recibe JSON (array de objetos) y delega en sp_pr_tregistro_registrar_trabajador_nuevo_web.

    NOTA: requiere SQL Server 2016+ (OPENJSON). En servidores anteriores la API web
    invoca sp_pr_tregistro_registrar_trabajador_nuevo_web en bucle desde Python.

    Usado por: POST /api/tregistro-importacion/registrar (fallback opcional)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_tregistro_registrar_nuevos_web]
    @cia            VARCHAR(10),
    @trabajadores   NVARCHAR(MAX),
    @replicationunit VARCHAR(20) = 'LIMA',
    @xlastuser      VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @replicationunit = UPPER(LTRIM(RTRIM(ISNULL(@replicationunit, 'LIMA'))));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @cia = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF @trabajadores IS NULL OR LTRIM(RTRIM(@trabajadores)) = ''
    BEGIN
        RAISERROR('No se recibieron trabajadores para registrar.', 16, 1);
        RETURN;
    END;

    IF ISJSON(@trabajadores) <> 1
    BEGIN
        RAISERROR('El formato de trabajadores no es JSON válido.', 16, 1);
        RETURN;
    END;

    CREATE TABLE #Resultado (
        num_doc         VARCHAR(15) NULL,
        nombre          VARCHAR(120) NULL,
        estado          VARCHAR(20) NOT NULL,
        person          VARCHAR(20) NULL,
        mensaje         VARCHAR(500) NULL
    );

    DECLARE @num_doc                VARCHAR(15);
    DECLARE @tipo_doc               VARCHAR(50);
    DECLARE @apellido_paterno       VARCHAR(40);
    DECLARE @apellido_materno       VARCHAR(40);
    DECLARE @nombres                VARCHAR(80);
    DECLARE @fecha_nac              VARCHAR(10);
    DECLARE @nacionalidad           VARCHAR(100);
    DECLARE @sexo                   VARCHAR(20);
    DECLARE @telefono               VARCHAR(15);
    DECLARE @email                  VARCHAR(255);
    DECLARE @direccion              VARCHAR(255);
    DECLARE @fecha_ingreso          VARCHAR(10);
    DECLARE @tipo_trabajador        VARCHAR(80);
    DECLARE @regimen_laboral        VARCHAR(80);
    DECLARE @cat_ocupacional        VARCHAR(80);
    DECLARE @ocupacion              VARCHAR(120);
    DECLARE @nivel_educativo        VARCHAR(80);
    DECLARE @tipo_contrato          VARCHAR(80);
    DECLARE @tipo_pago              VARCHAR(80);
    DECLARE @entidad_financiera     VARCHAR(120);
    DECLARE @nro_cuenta             VARCHAR(30);
    DECLARE @remun_bas              VARCHAR(20);
    DECLARE @regimen_pension        VARCHAR(80);
    DECLARE @regimen_pension_fec    VARCHAR(10);
    DECLARE @cuspp                  VARCHAR(20);
    DECLARE @regimen_salud          VARCHAR(80);
    DECLARE @regimen_salud_fec      VARCHAR(10);
    DECLARE @situacion_especial     VARCHAR(80);
    DECLARE @sindicalizado          VARCHAR(5);
    DECLARE @nombre_completo        VARCHAR(120);
    DECLARE @person_out             VARCHAR(20);
    DECLARE @mensaje_out            VARCHAR(500);
    DECLARE @err                    VARCHAR(500);

    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            JSON_VALUE(j.value, '$.tipo_doc'),
            JSON_VALUE(j.value, '$.num_doc'),
            JSON_VALUE(j.value, '$.apellido_paterno'),
            JSON_VALUE(j.value, '$.apellido_materno'),
            JSON_VALUE(j.value, '$.nombres'),
            JSON_VALUE(j.value, '$.fecha_nac'),
            JSON_VALUE(j.value, '$.nacionalidad'),
            JSON_VALUE(j.value, '$.sexo'),
            JSON_VALUE(j.value, '$.telefono'),
            JSON_VALUE(j.value, '$.email'),
            JSON_VALUE(j.value, '$.direccion'),
            JSON_VALUE(j.value, '$.fecha_ingreso'),
            JSON_VALUE(j.value, '$.tipo_trabajador'),
            JSON_VALUE(j.value, '$.regimen_laboral'),
            JSON_VALUE(j.value, '$.cat_ocupacional'),
            JSON_VALUE(j.value, '$.ocupacion'),
            JSON_VALUE(j.value, '$.nivel_educativo'),
            JSON_VALUE(j.value, '$.tipo_contrato'),
            JSON_VALUE(j.value, '$.tipo_pago'),
            JSON_VALUE(j.value, '$.entidad_financiera'),
            JSON_VALUE(j.value, '$.nro_cuenta'),
            JSON_VALUE(j.value, '$.remun_bas'),
            JSON_VALUE(j.value, '$.regimen_pension'),
            JSON_VALUE(j.value, '$.regimen_pension_fec'),
            JSON_VALUE(j.value, '$.cuspp'),
            JSON_VALUE(j.value, '$.regimen_salud'),
            JSON_VALUE(j.value, '$.regimen_salud_fec'),
            JSON_VALUE(j.value, '$.situacion_especial'),
            JSON_VALUE(j.value, '$.sindicalizado'),
            JSON_VALUE(j.value, '$.nombre_completo')
        FROM OPENJSON(@trabajadores) j;

    OPEN cur;
    FETCH NEXT FROM cur INTO
        @tipo_doc, @num_doc, @apellido_paterno, @apellido_materno, @nombres,
        @fecha_nac, @nacionalidad, @sexo, @telefono, @email, @direccion,
        @fecha_ingreso, @tipo_trabajador, @regimen_laboral, @cat_ocupacional,
        @ocupacion, @nivel_educativo, @tipo_contrato, @tipo_pago,
        @entidad_financiera, @nro_cuenta, @remun_bas, @regimen_pension,
        @regimen_pension_fec, @cuspp, @regimen_salud, @regimen_salud_fec,
        @situacion_especial, @sindicalizado, @nombre_completo;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @person_out = NULL;
        SET @mensaje_out = NULL;
        SET @err = NULL;

        BEGIN TRY
            EXEC sp_pr_tregistro_registrar_trabajador_nuevo_web
                @cia = @cia,
                @tipo_doc = @tipo_doc,
                @num_doc = @num_doc,
                @apellido_paterno = @apellido_paterno,
                @apellido_materno = @apellido_materno,
                @nombres = @nombres,
                @fecha_nac = @fecha_nac,
                @nacionalidad = @nacionalidad,
                @sexo = @sexo,
                @telefono = @telefono,
                @email = @email,
                @direccion = @direccion,
                @fecha_ingreso = @fecha_ingreso,
                @tipo_trabajador = @tipo_trabajador,
                @regimen_laboral = @regimen_laboral,
                @cat_ocupacional = @cat_ocupacional,
                @ocupacion = @ocupacion,
                @nivel_educativo = @nivel_educativo,
                @tipo_contrato = @tipo_contrato,
                @tipo_pago = @tipo_pago,
                @entidad_financiera = @entidad_financiera,
                @nro_cuenta = @nro_cuenta,
                @remun_bas = @remun_bas,
                @regimen_pension = @regimen_pension,
                @regimen_pension_fec = @regimen_pension_fec,
                @cuspp = @cuspp,
                @regimen_salud = @regimen_salud,
                @regimen_salud_fec = @regimen_salud_fec,
                @situacion_especial = @situacion_especial,
                @sindicalizado = @sindicalizado,
                @replicationunit = @replicationunit,
                @xlastuser = @xlastuser,
                @person_out = @person_out OUTPUT,
                @mensaje_out = @mensaje_out OUTPUT;

            INSERT INTO #Resultado (num_doc, nombre, estado, person, mensaje)
            VALUES (@num_doc, @nombre_completo, 'OK', @person_out, @mensaje_out);
        END TRY
        BEGIN CATCH
            SET @err = LEFT(ERROR_MESSAGE(), 500);
            INSERT INTO #Resultado (num_doc, nombre, estado, person, mensaje)
            VALUES (@num_doc, @nombre_completo, 'ERROR', NULL, @err);
        END CATCH;

        FETCH NEXT FROM cur INTO
            @tipo_doc, @num_doc, @apellido_paterno, @apellido_materno, @nombres,
            @fecha_nac, @nacionalidad, @sexo, @telefono, @email, @direccion,
            @fecha_ingreso, @tipo_trabajador, @regimen_laboral, @cat_ocupacional,
            @ocupacion, @nivel_educativo, @tipo_contrato, @tipo_pago,
            @entidad_financiera, @nro_cuenta, @remun_bas, @regimen_pension,
            @regimen_pension_fec, @cuspp, @regimen_salud, @regimen_salud_fec,
            @situacion_especial, @sindicalizado, @nombre_completo;
    END;

    CLOSE cur;
    DEALLOCATE cur;

    SELECT
        num_doc,
        nombre,
        estado,
        person,
        mensaje
    FROM #Resultado
    ORDER BY nombre, num_doc;

    SELECT
        COUNT(*) AS total,
        SUM(CASE WHEN estado = 'OK' THEN 1 ELSE 0 END) AS registrados,
        SUM(CASE WHEN estado = 'ERROR' THEN 1 ELSE 0 END) AS errores
    FROM #Resultado;
END
GO
