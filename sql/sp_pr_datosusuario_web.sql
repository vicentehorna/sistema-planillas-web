/*
    Datos del usuario / trabajador para perfil web.

    Usado por: get_datos_usuario_web (database.py).

    Parámetros:
      @userid — SY_User.UserID (código de acceso)
*/
CREATE OR ALTER PROCEDURE [dbo].[sp_pr_datosusuario_web]
    @userid VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SET @userid = LTRIM(RTRIM(ISNULL(@userid, '')));

    SELECT
        ISNULL(p.LastName1, '') AS primerapellido,
        ISNULL(p.LastName2, '') AS segundoapellido,
        ISNULL(p.Name1, '') + ' ' + ISNULL(p.Name2, '') AS nombres,
        ISNULL(SY_PersonDocumentType.Description, '') AS TipoDocumento,
        ISNULL(p.documentnumber, '') AS NroDocumento,
        ISNULL(PR_Nacionalidad.Description, '') AS LugarNacimiento,
        p.BirthDate AS FechaNacimiento,
        ISNULL(p.Telephone, '') AS TelefonoFijo,
        ISNULL(p.SecTelephone, '') AS Movil,
        ISNULL(p.EMail, '') AS email,
        ISNULL(p.Address, '') AS Direccion,
        ISNULL(SY_Localite.Name, '') AS distrito,
        ISNULL(SY_Province.Name, '') AS provincia,
        ISNULL(SY_Department.Name, '') AS departamento,
        '' AS Fotografia,
        E.Company AS company,
        E.Person AS person,
        p.Sex AS sexo,
        PP.Description AS cargo,
        B1.Name AS BancoSalario,
        E.SalaryAccount AS CuentaSalario,
        B2.Name AS BancoCTS,
        E.CTSAccount AS CuentaCTS,
        I.Description AS NivelInstruccion,
        PR_Institution.description AS Institucion,
        PR_Career.Description AS carrera,
        PR_EmployeeType.Description AS tipoempleado,
        ISNULL(E.ReEntryDate, E.EntryDate) AS FechaIngreso,
        HR_CONTRACTMODALITY.Description AS tipocontrato,
        PR_PensionType.Description AS Regimenenpension,
        ISNULL(E.AFPCard, '') AS cussp,
        'Si' AS AsignacionFamiliar,
        'Si' AS Afpmixta
    FROM SY_User u (NOLOCK)
        INNER JOIN SY_Person p (NOLOCK) ON p.UserID = u.UserID
        INNER JOIN PR_Employee E (NOLOCK) ON p.Person = E.Person AND E.Status = 'N'
        INNER JOIN PR_Position PP (NOLOCK) ON E.Position = PP.Position
        INNER JOIN SY_Company c (NOLOCK) ON E.Company = c.Company
        INNER JOIN SY_UserProfile up (NOLOCK) ON up.UserID = u.UserID
        INNER JOIN PR_mapping2 M (NOLOCK) ON c.Company = M.company
        LEFT JOIN SY_Localite (NOLOCK) ON p.Localite = SY_Localite.Localite
        LEFT JOIN SY_Province (NOLOCK)
            ON p.Province = SY_Province.Province
           AND SY_Province.Province = SY_Localite.Province
        LEFT JOIN SY_Department (NOLOCK)
            ON p.Department = SY_Department.Department
           AND SY_Province.Department = SY_Department.Department
        LEFT JOIN PR_Nacionalidad (NOLOCK) ON P.Nationality = PR_Nacionalidad.Nacionalidad
        INNER JOIN SY_PersonDocumentType (NOLOCK)
            ON P.EmployeeDocumentType = SY_PersonDocumentType.PersonDocumentType
        LEFT JOIN ERP_Bank B1 (NOLOCK) ON E.SalaryBank = B1.Bank
        LEFT JOIN ERP_Bank B2 (NOLOCK) ON E.CTSBank = B2.Bank
        LEFT JOIN PR_InstructionLevel I ON p.InstructionLevel = I.InstructionLevel
        LEFT JOIN PR_Institution
            ON p.costcenter1 = PR_Institution.pdt
           AND PR_Institution.Company = E.Company
        LEFT JOIN PR_Career
            ON PR_Institution.Institution = PR_Career.Institution
           AND PR_Career.pdt = p.costcenter2
        LEFT JOIN PR_EmployeeType ON E.employeetype = PR_EmployeeType.employeetype
        LEFT JOIN HR_CONTRACTMODALITY ON E.ContractModality = HR_CONTRACTMODALITY.ContractModality
        LEFT JOIN PR_PensionType ON E.PensionType = PR_PensionType.PensionType
    WHERE u.UserID = @userid;
END
GO
