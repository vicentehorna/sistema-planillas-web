/*
    Selector de unidades de replicación activas (SY_ReplicationUnit).
    Usado por: GET /api/selectores/unidades (asignacion_conceptos.html y otros).
    Campo en persona: SY_Person.ReplicationUnit.
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectorunidades_web]
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        SY_ReplicationUnit.ReplicationUnit AS replicationunit,
        SY_ReplicationUnit.Description AS description
    FROM SY_ReplicationUnit
    WHERE SY_ReplicationUnit.status = 'A'
    ORDER BY SY_ReplicationUnit.Description ASC;
END
GO
