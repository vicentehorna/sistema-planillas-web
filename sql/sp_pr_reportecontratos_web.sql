/*
    Listado / reporte de contratos (migración DW PB9 LISTADO DE CONTRATOS).
    Usado por: POST /reporte_contratos (reporte_contratos.html).

    Parámetros:
      @cia              — compañía
      @payrolltype      — tipo planilla; '0' = todos
      @person           — persona; '0' = todos
      @cesados          — T=todos, Y=con fecha de cese (CeaseDate not null), N=sin fecha de cese
                          (mismo criterio que saldo vacaciones / PB9)
      @contractmodality — modalidad; '0' = todas
      @filtro_contrato  — A=contrato activo, S=sin contrato activo (1 fila/persona), T=todos

    Columnas (headers web):
      codigo, trabajador, f_ingreso, cargo, cc, estado, inicio, termino, f_cese, modalidad
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_reportecontratos_web]
    @cia              VARCHAR(4),
    @payrolltype      VARCHAR(20) = '0',
    @person           VARCHAR(20) = '0',
    @cesados          CHAR(1) = 'T',
    @contractmodality VARCHAR(20) = '0',
    @filtro_contrato  CHAR(1) = 'T'
AS
BEGIN
    SET NOCOUNT ON;

    SET @cia = LTRIM(RTRIM(ISNULL(@cia, '')));
    SET @payrolltype = LTRIM(RTRIM(ISNULL(@payrolltype, '0')));
    IF @payrolltype = '' SET @payrolltype = '0';
    SET @person = LTRIM(RTRIM(ISNULL(@person, '0')));
    IF @person = '' SET @person = '0';
    SET @cesados = UPPER(LTRIM(RTRIM(ISNULL(@cesados, 'T'))));
    IF @cesados NOT IN ('T', 'Y', 'N') SET @cesados = 'T';
    SET @contractmodality = LTRIM(RTRIM(ISNULL(@contractmodality, '0')));
    IF @contractmodality = '' SET @contractmodality = '0';
    SET @filtro_contrato = UPPER(LTRIM(RTRIM(ISNULL(@filtro_contrato, 'T'))));
    IF @filtro_contrato NOT IN ('A', 'S', 'T') SET @filtro_contrato = 'T';

    ;WITH base AS (
        SELECT
            ISNULL(NULLIF(LTRIM(RTRIM(e.EmployeeCode)), ''), e.Person) AS codigo,
            LTRIM(RTRIM(
                ISNULL(p.LastName1, '') + ' ' +
                ISNULL(p.LastName2, '') + ' ' +
                ISNULL(p.Name1, '') + ' ' +
                ISNULL(p.Name2, '')
            )) AS trabajador,
            CONVERT(varchar(10), ISNULL(e.ReEntryDate, e.EntryDate), 23) AS f_ingreso,
            ISNULL(
                (
                    SELECT TOP 1 LTRIM(RTRIM(pos.Description))
                    FROM PR_Position pos (NOLOCK)
                    WHERE pos.Position = ISNULL(pc.position, e.Position)
                      AND (pos.Company = e.Company OR pos.Company IS NULL)
                ),
                ISNULL(e.POSITION_DESC, '')
            ) AS cargo,
            ISNULL(NULLIF(LTRIM(RTRIM(e.Costcentername)), ''), LTRIM(RTRIM(ISNULL(e.CostCenter, '')))) AS cc,
            CASE
                WHEN pc.Person IS NULL THEN NULL
                WHEN LTRIM(RTRIM(ISNULL(pc.Status, ''))) = 'A'
                     AND (pc.enddate IS NULL OR CONVERT(date, pc.enddate) >= CONVERT(date, GETDATE()))
                    THEN 'ACTIVO'
                WHEN LTRIM(RTRIM(ISNULL(pc.Status, ''))) = 'A' THEN 'INACTIVO'
                WHEN LTRIM(RTRIM(ISNULL(pc.Status, ''))) = 'I' THEN 'INACTIVO'
                ELSE LTRIM(RTRIM(ISNULL(pc.Status, '')))
            END AS estado,
            CONVERT(varchar(10), pc.startdate, 23) AS inicio,
            CONVERT(varchar(10), pc.enddate, 23) AS termino,
            CONVERT(varchar(10), e.CeaseDate, 23) AS f_cese,
            ISNULL(
                (
                    SELECT TOP 1 LTRIM(RTRIM(m.Description))
                    FROM HR_ContractModality m (NOLOCK)
                    WHERE m.Company = e.Company
                      AND m.ContractModality = e.ContractModality
                ),
                CASE WHEN NULLIF(LTRIM(RTRIM(e.ContractModality)), '') IS NULL THEN 'Ninguno' ELSE LTRIM(RTRIM(e.ContractModality)) END
            ) AS modalidad,
            e.Person AS person,
            e.Company AS company,
            pc.Contractno AS contractno,
            pc.Status AS contract_status,
            pc.startdate AS contract_start,
            pc.enddate AS contract_end,
            CASE
                WHEN EXISTS (
                    SELECT 1
                    FROM PR_PersonContract pca (NOLOCK)
                    WHERE pca.Company = e.Company
                      AND pca.Person = e.Person
                      AND LTRIM(RTRIM(ISNULL(pca.Status, ''))) = 'A'
                      AND (pca.enddate IS NULL OR CONVERT(date, pca.enddate) >= CONVERT(date, GETDATE()))
                ) THEN 'Y'
                ELSE 'N'
            END AS tiene_activo
        FROM PR_Employee e (NOLOCK)
        INNER JOIN SY_Person p (NOLOCK)
            ON p.Person = e.Person
        LEFT JOIN PR_PersonContract pc (NOLOCK)
            ON pc.Person = e.Person
           AND pc.Company = e.Company
        WHERE e.Company = @cia
          AND (@payrolltype = '0' OR e.PayRollType = @payrolltype)
          AND (@person = '0' OR e.Person = @person)
          AND (
                @cesados = 'T'
                OR (@cesados = 'Y' AND e.CeaseDate IS NOT NULL)
                OR (@cesados = 'N' AND e.CeaseDate IS NULL)
          )
          AND (
                @contractmodality = '0'
                OR e.ContractModality = @contractmodality
          )
    ),
    filtrado AS (
        SELECT
            b.*,
            ROW_NUMBER() OVER (
                PARTITION BY b.person
                ORDER BY
                    CASE WHEN b.contractno IS NULL THEN 1 ELSE 0 END,
                    ISNULL(b.contract_end, CONVERT(datetime, '19000101')) DESC,
                    ISNULL(b.contract_start, CONVERT(datetime, '19000101')) DESC,
                    ISNULL(b.contractno, 0) DESC
            ) AS rn_sin
        FROM base b
        WHERE
            (
                @filtro_contrato = 'T'
                OR (@filtro_contrato = 'A' AND b.tiene_activo = 'Y' AND b.estado = 'ACTIVO')
                OR (
                    @filtro_contrato = 'S'
                    AND b.tiene_activo = 'N'
                    AND (
                        b.contractno IS NULL
                        OR NOT (
                            LTRIM(RTRIM(ISNULL(b.contract_status, ''))) = 'A'
                            AND (b.contract_end IS NULL OR CONVERT(date, b.contract_end) >= CONVERT(date, GETDATE()))
                        )
                    )
                )
            )
    )
    SELECT
        codigo,
        trabajador,
        f_ingreso,
        cargo,
        cc,
        estado,
        inicio,
        termino,
        f_cese,
        modalidad
    FROM filtrado
    WHERE @filtro_contrato <> 'S' OR rn_sin = 1
    ORDER BY trabajador, contract_start, contractno;
END
GO
