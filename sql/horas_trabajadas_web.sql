/*
    Tablas → Horas Trabajadas (solo hm_garc).
    Horas trabajadas máximas por periodo; única por empresa principal (BGT), sin réplica.

    Usado por: POST /api/horas-trabajadas/listado | guardar | eliminar
*/
SET NOCOUNT ON;

IF OBJECT_ID('dbo.PR_HorasTrabajadas', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.PR_HorasTrabajadas (
        Company    VARCHAR(4)  NOT NULL,
        Period     CHAR(8)     NOT NULL,
        NroHoras   INT         NOT NULL,
        XLastUser  VARCHAR(20) NULL,
        XLastDate  DATETIME    NULL,
        CONSTRAINT PK_PR_HorasTrabajadas PRIMARY KEY (Company, Period)
    );
END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_pr_listar_horas_trabajadas_web]
    @company VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));

    SELECT
        H.Period AS period,
        SUBSTRING(H.Period, 1, 4) + '-'
            + SUBSTRING(H.Period, 5, 2) + '-'
            + SUBSTRING(H.Period, 7, 2) AS periodo,
        H.NroHoras AS nrohoras,
        ISNULL(H.XLastUser, '') AS xlastuser,
        H.XLastDate AS xlastdate
    FROM dbo.PR_HorasTrabajadas H (NOLOCK)
    WHERE H.Company = @company
    ORDER BY H.Period DESC;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_pr_guardar_horas_trabajadas_web]
    @modo       CHAR(1),
    @company    VARCHAR(4),
    @period     VARCHAR(8),
    @nrohoras   INT,
    @xlastuser  VARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @modo = UPPER(LTRIM(RTRIM(ISNULL(@modo, ''))));
    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @modo NOT IN ('I', 'U')
    BEGIN
        RAISERROR('Modo de operación inválido.', 16, 1);
        RETURN;
    END;

    IF @company = ''
    BEGIN
        RAISERROR('Indique la compañía.', 16, 1);
        RETURN;
    END;

    IF LEN(@period) <> 8 OR @period LIKE '%[^0-9]%'
    BEGIN
        RAISERROR('Seleccione un periodo válido.', 16, 1);
        RETURN;
    END;

    IF @nrohoras IS NULL OR @nrohoras < 1 OR @nrohoras > 744
    BEGIN
        RAISERROR('El número de horas debe ser un entero entre 1 y 744.', 16, 1);
        RETURN;
    END;

    IF @modo = 'I'
    BEGIN
        IF EXISTS (
            SELECT 1 FROM dbo.PR_HorasTrabajadas (NOLOCK)
            WHERE Company = @company AND Period = @period
        )
        BEGIN
            RAISERROR('Ya existen horas registradas para el periodo seleccionado.', 16, 1);
            RETURN;
        END;

        INSERT INTO dbo.PR_HorasTrabajadas (Company, Period, NroHoras, XLastUser, XLastDate)
        VALUES (@company, @period, @nrohoras, @xlastuser, GETDATE());

        SELECT @period AS period, 'Horas trabajadas registradas correctamente.' AS mensaje;
        RETURN;
    END;

    IF NOT EXISTS (
        SELECT 1 FROM dbo.PR_HorasTrabajadas (NOLOCK)
        WHERE Company = @company AND Period = @period
    )
    BEGIN
        RAISERROR('No se encontró el periodo a actualizar.', 16, 1);
        RETURN;
    END;

    UPDATE dbo.PR_HorasTrabajadas
    SET NroHoras = @nrohoras,
        XLastUser = @xlastuser,
        XLastDate = GETDATE()
    WHERE Company = @company
      AND Period = @period;

    SELECT @period AS period, 'Horas trabajadas actualizadas correctamente.' AS mensaje;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[sp_pr_eliminar_horas_trabajadas_web]
    @company VARCHAR(4),
    @period  VARCHAR(8)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @company = LTRIM(RTRIM(ISNULL(@company, '')));
    SET @period = LTRIM(RTRIM(ISNULL(@period, '')));

    IF NOT EXISTS (
        SELECT 1 FROM dbo.PR_HorasTrabajadas (NOLOCK)
        WHERE Company = @company AND Period = @period
    )
    BEGIN
        RAISERROR('No se encontró el periodo.', 16, 1);
        RETURN;
    END;

    DELETE FROM dbo.PR_HorasTrabajadas
    WHERE Company = @company
      AND Period = @period;

    SELECT @period AS period, 'Horas trabajadas eliminadas correctamente.' AS mensaje;
END
GO
