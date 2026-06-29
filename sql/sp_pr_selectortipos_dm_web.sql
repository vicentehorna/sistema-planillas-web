/*
    Tipos de descanso médico por compañía (PR_MedicalRestType).
    Usado por: GET /api/selectores/tipos-descanso-medico
               registro_descansos_medicos.html (selector del drawer).
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_selectortipos_dm_web]
    @cia VARCHAR(4)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        mrt.MedicalRestType AS medicalresttype,
        mrt.Description AS description,
        LTRIM(RTRIM(mrt.PDT)) AS pdt
    FROM PR_MedicalRestType mrt
    WHERE mrt.Company = @cia
    ORDER BY mrt.Description;
END
GO
