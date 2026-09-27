/*
    Alta de empresa (SY_Company) desde el maestro web.
    Usado por: POST /api/empresas/registrar

    Replica lo que hacía el alta del sistema anterior, solo en lo que usa Planillas:
      - SY_Company con código correlativo (fn_pr_siguientecodigoempresa_web) y auditoría de creación.
      - SY_ObjectSecuence: todos los objetos × unidades de replicación, en 0
        (lo usa sp_pr_genera_correlativo_web para los IDs de conceptos, cargos, fórmulas, etc.).
      - PR_ConceptType: los 6 tipos de concepto, tomados de BGT.
      - SY_ApplicationCompany (ER), SY_BusinessUnit (GG) y PR_mapping2, como el sistema anterior.
      - SY_UserCompany para el usuario creador, si ese usuario trabaja con empresas asignadas.
    Los maestros de planilla (conceptos, fórmulas, tipos de planilla, periodos, PR_Mapping…)
    se copian en el paso Replicar.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_registrarempresa_web]
    @description    VARCHAR(255),
    @ruc            VARCHAR(15),
    @telephone      VARCHAR(15)  = NULL,
    @address        VARCHAR(255) = NULL,
    @localite       VARCHAR(20)  = NULL,
    @status         VARCHAR(1)   = 'A',
    @representative VARCHAR(100) = NULL,
    @rep_doctype    VARCHAR(20)  = NULL,
    @rep_docnumber  VARCHAR(15)  = NULL,
    @rep_position   VARCHAR(100) = NULL,
    @xlastuser      VARCHAR(20)  = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @description = LTRIM(RTRIM(ISNULL(@description, '')));
    SET @ruc = LTRIM(RTRIM(ISNULL(@ruc, '')));
    SET @telephone = NULLIF(LTRIM(RTRIM(ISNULL(@telephone, ''))), '');
    SET @address = NULLIF(LTRIM(RTRIM(ISNULL(@address, ''))), '');
    SET @localite = NULLIF(LTRIM(RTRIM(ISNULL(@localite, ''))), '');
    SET @status = CASE WHEN UPPER(LTRIM(RTRIM(ISNULL(@status, 'A')))) = 'I' THEN 'I' ELSE 'A' END;
    SET @representative = NULLIF(LTRIM(RTRIM(ISNULL(@representative, ''))), '');
    SET @rep_doctype = NULLIF(LTRIM(RTRIM(ISNULL(@rep_doctype, ''))), '');
    SET @rep_docnumber = NULLIF(LTRIM(RTRIM(ISNULL(@rep_docnumber, ''))), '');
    SET @rep_position = NULLIF(LTRIM(RTRIM(ISNULL(@rep_position, ''))), '');
    SET @xlastuser = NULLIF(LTRIM(RTRIM(ISNULL(@xlastuser, ''))), '');

    IF @description = ''
    BEGIN
        RAISERROR('Indique la razón social de la empresa.', 16, 1);
        RETURN;
    END;
    IF LEN(@ruc) <> 11 OR @ruc LIKE '%[^0-9]%'
    BEGIN
        RAISERROR('El RUC debe tener 11 dígitos.', 16, 1);
        RETURN;
    END;
    IF EXISTS (SELECT 1 FROM SY_Company (NOLOCK) WHERE LTRIM(RTRIM(ISNULL(RUC, ''))) = @ruc)
    BEGIN
        RAISERROR('El RUC ya está registrado en otra empresa.', 16, 1);
        RETURN;
    END;

    DECLARE @province VARCHAR(20), @department VARCHAR(20), @country VARCHAR(20);
    IF @localite IS NOT NULL
    BEGIN
        SELECT TOP 1
            @province = l.Province,
            @department = p.Department,
            @country = d.Country
        FROM SY_Localite l (NOLOCK)
            LEFT JOIN SY_Province p (NOLOCK) ON p.Province = l.Province
            LEFT JOIN SY_Department d (NOLOCK) ON d.Department = p.Department
        WHERE l.Localite = @localite;

        IF @province IS NULL
        BEGIN
            RAISERROR('El distrito seleccionado no existe.', 16, 1);
            RETURN;
        END;
    END;

    DECLARE @company VARCHAR(4);
    DECLARE @companyid VARCHAR(4);
    DECLARE @prefijo VARCHAR(8);
    DECLARE @ahora DATETIME = GETDATE();
    DECLARE @lock INT;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Serializa altas concurrentes mientras se calcula el correlativo.
        SELECT @lock = COUNT(*) FROM SY_Company WITH (TABLOCKX, HOLDLOCK);

        SET @company = dbo.fn_pr_siguientecodigoempresa_web();
        IF @company IS NULL
        BEGIN
            RAISERROR('No hay códigos de empresa disponibles.', 16, 1);
        END;

        SELECT TOP 1 @companyid = CompanyID
        FROM SY_Company
        WHERE ISNULL(CompanyID, '') <> ''
        GROUP BY CompanyID
        ORDER BY COUNT(*) DESC;
        SET @companyid = ISNULL(@companyid, 'BGT');

        INSERT INTO SY_Company (
            Company, Description, Abbrev, CompanyID, RUC, Telephone, Address,
            localite, province, department, country, Status,
            Representative, Rep_DocType, Rep_DocNumber, Rep_Position,
            ReplicationUnit, XCreateUser, XCreateDate, XLastUser, XLastDate
        )
        VALUES (
            @company, @description, @company, @companyid, @ruc, @telephone, @address,
            @localite, @province, @department, @country, @status,
            @representative, @rep_doctype, @rep_docnumber, @rep_position,
            'LIMA', @xlastuser, @ahora, @xlastuser, @ahora
        );

        INSERT INTO SY_ObjectSecuence (Company, Object, ReplicationUnit, Secuence, XLastUser, XLastDate)
        SELECT @company, o.Object, ru.ReplicationUnit, 0, @xlastuser, @ahora
        FROM (
            SELECT LTRIM(RTRIM(Object)) AS Object FROM SY_Object WHERE ISNULL(LTRIM(RTRIM(Object)), '') <> ''
            UNION
            SELECT DISTINCT LTRIM(RTRIM(Object)) FROM SY_ObjectSecuence WHERE ReplicationUnit = 'LIMA'
        ) o
        CROSS JOIN (
            SELECT LTRIM(RTRIM(ReplicationUnit)) AS ReplicationUnit FROM SY_ReplicationUnit WHERE ISNULL(LTRIM(RTRIM(ReplicationUnit)), '') <> ''
            UNION
            SELECT 'LIMA'
        ) ru
        WHERE NOT EXISTS (
            SELECT 1 FROM SY_ObjectSecuence s
            WHERE s.Company = @company AND s.Object = o.Object AND s.ReplicationUnit = ru.ReplicationUnit
        );

        -- Puede haber restos de una empresa eliminada con el mismo código: se reaprovechan.
        SET @prefijo = 'LIMA' + LEFT(@company + '    ', 4);

        INSERT INTO PR_ConceptType (ConceptType, Description, ShortName, Company, ReplicationUnit, XLastUser, XLastDate, orden)
        SELECT @prefijo + RIGHT(LTRIM(RTRIM(t.ConceptType)), 12), t.Description, t.ShortName, @company, 'LIMA', @xlastuser, @ahora, t.orden
        FROM PR_ConceptType t
        WHERE t.Company = 'BGT'
          AND NOT EXISTS (
              SELECT 1 FROM PR_ConceptType x
              WHERE x.ConceptType = @prefijo + RIGHT(LTRIM(RTRIM(t.ConceptType)), 12)
          );

        IF NOT EXISTS (SELECT 1 FROM PR_ConceptType WHERE Company = @company)
        BEGIN
            INSERT INTO PR_ConceptType (ConceptType, Description, ShortName, Company, ReplicationUnit, XLastUser, XLastDate, orden)
            SELECT @prefijo + RIGHT('000000000000' + CAST(v.n AS VARCHAR(2)), 12), v.descr, v.sn, @company, 'LIMA', @xlastuser, @ahora, v.orden
            FROM (VALUES
                (1, 'Ingresos', 'I', 1),
                (2, 'Descuentos', 'D', 2),
                (3, 'Aportes', 'A', 4),
                (4, 'Auxiliares', 'X', 6),
                (5, 'Totales', 'T', 3),
                (6, 'Totales Generales', 'G', 5)
            ) v (n, descr, sn, orden)
            WHERE NOT EXISTS (
                SELECT 1 FROM PR_ConceptType x
                WHERE x.ConceptType = @prefijo + RIGHT('000000000000' + CAST(v.n AS VARCHAR(2)), 12)
            );
        END;

        IF NOT EXISTS (SELECT 1 FROM SY_ApplicationCompany WHERE Application = 'ER' AND Company = @company)
            INSERT INTO SY_ApplicationCompany (Application, Company, XLastUser, XLastDate, ReplicationUnit)
            VALUES ('ER', @company, @xlastuser, @ahora, 'LIMA');

        IF NOT EXISTS (SELECT 1 FROM SY_BusinessUnit WHERE BusinessUnit = 'GG' AND Company = @company)
            INSERT INTO SY_BusinessUnit (BusinessUnit, Company, Description, BUParent, Status, XLastUser, ReplicationUnit, XLastDate)
            VALUES ('GG', @company, 'GERENCIA GENERAL', 'ROOT', 'A', @xlastuser, 'LIMA', @ahora);

        IF NOT EXISTS (SELECT 1 FROM PR_mapping2 WHERE company = @company)
            INSERT INTO PR_mapping2 (company) VALUES (@company);

        IF @xlastuser IS NOT NULL
           AND EXISTS (SELECT 1 FROM SY_UserCompany WHERE UserID = @xlastuser)
           AND NOT EXISTS (SELECT 1 FROM SY_UserCompany WHERE UserID = @xlastuser AND idcompany = @company)
        BEGIN
            INSERT INTO SY_UserCompany (company, UserID, XLastUser, ReplicationUnit, XLastDate, idcompany)
            SELECT
                ISNULL(NULLIF(LTRIM(RTRIM(u.Company)), ''), 'BGT'),
                @xlastuser,
                @xlastuser,
                ISNULL(NULLIF(LTRIM(RTRIM(u.ReplicationUnit)), ''), 'LIMA'),
                @ahora,
                @company
            FROM SY_User u
            WHERE u.UserID = @xlastuser;
        END;

        COMMIT TRANSACTION;

        SELECT
            @company AS company,
            'I' AS modo,
            'Empresa ' + @company + ' registrada correctamente.' AS mensaje;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO
