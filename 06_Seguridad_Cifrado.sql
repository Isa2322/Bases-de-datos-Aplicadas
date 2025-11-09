/* =========================================================================================
   ENTREGA 7 - SEGURIDAD Y CIFRADO
   Materia: 3641 - Bases de Datos Aplicada
   Comisión: 5600
   Grupo: 11
   Fecha: 07/11/2025
   Archivo: 07_Seguridad_Cifrado.sql

   Integrantes:
   - Hidalgo, Eduardo - 41173099
   - Quispe, Milagros Soledad - 45064110
   - Puma, Florencia - 42945609
   - Fontanet Caniza, Camila - 44892126
   - Altamiranda, Isaias Taiel - 43094671
   - Pastori, Ximena - 42300128

   Descripción:
   Implementación de medidas de seguridad requeridas:
   1) Creación de roles y asignación de permisos.
   2) Cifrado de datos sensibles/personales.
   3) Políticas y scripts de respaldo (backup).

========================================================================================= */


USE [Com5600G11];
GO


/* =========================================================================================
   1️ CREACIÓN DE ROLES Y ASIGNACIÓN DE PERMISOS
========================================================================================= */

IF OBJECT_ID('Operaciones.sp_SeguridadCifrado') IS NOT NULL
    DROP PROCEDURE Operaciones.sp_SeguridadCifrado;
GO

CREATE PROCEDURE Operaciones.sp_SeguridadCifrado
AS
BEGIN
    SET NOCOUNT ON;


PRINT '--- Creando roles de seguridad ---';

-- Eliminamos roles previos si existieran
IF EXISTS (SELECT *
    FROM sys.database_principals
    WHERE name = 'AdministrativoGeneral')
    DROP ROLE AdministrativoGeneral;
IF EXISTS (SELECT * 
FROM sys.database_principals
    WHERE name = 'AdministrativoBancario')
    DROP ROLE AdministrativoBancario;
IF EXISTS (SELECT * 
    FROM sys.database_principals
    WHERE name = 'AdministrativoOperativo')
    DROP ROLE AdministrativoOperativo;
IF EXISTS (SELECT *
    FROM sys.database_principals
    WHERE name = 'Sistemas')
    DROP ROLE Sistemas


-- Creación de roles
CREATE ROLE AdministrativoGeneral;
CREATE ROLE AdministrativoBancario;
CREATE ROLE AdministrativoOperativo;
CREATE ROLE Sistemas;


PRINT '--- Asignando permisos por área ---';

-- Administrativo General: puede modificar las Unidades Funcionales (UF) y ejecutar los SP de operaciones.
GRANT SELECT, INSERT, UPDATE, DELETE ON 
    Consorcio.UnidadFuncional TO
    AdministrativoGeneral;
GRANT EXECUTE ON SCHEMA::Operaciones TO
    AdministrativoGeneral;

-- Administrativo Bancario: tiene permiso para ejecutar el procedimiento de importación de pagos
-- y para leer cosas del esquema Pago (no puede modificar UF).
GRANT EXECUTE ON OBJECT::Pago.sp_ImportacionPago TO
    AdministrativoBancario;
GRANT SELECT ON SCHEMA::Pago TO
    AdministrativoBancario;
GRANT EXECUTE ON SCHEMA::Operaciones TO
    AdministrativoBancario;

-- Administrativo Operativo: puede consultar/actualizar UF (menos privilegios que AdministrativoGeneral)
GRANT SELECT, UPDATE ON Consorcio.UnidadFuncional TO
    AdministrativoOperativo;
GRANT EXECUTE ON SCHEMA::Operaciones TO 
    AdministrativoOperativo;

-- Sistemas: rol técnico. Solo ejecución de SP de operaciones y ver definiciones (para tareas de mantenimiento).
GRANT EXECUTE ON SCHEMA::Operaciones TO 
    Sistemas;
GRANT VIEW DEFINITION TO 
    Sistemas;


PRINT '--- Roles y permisos asignados correctamente ---';


/* =========================================================================================

   CIFRADO DE DATOS SENSIBLES
   Se aplicará cifrado simétrico (AES_256) sobre datos personales de la tabla Persona:
   - DNI
   - Email
   - CVU / CBU

========================================================================================= */

PRINT '--- Creando llaves de cifrado ---';

/*
 Usamos MASTER KEY + CERTIFICATE + SYMMETRIC KEY (AES_256).
 La contraseña de MASTER KEY está hardcodeada para el TP, en prod seria un secreto seguro.
*/

-- Crear MASTER KEY (solo una vez)
IF NOT EXISTS 
    (SELECT *
    FROM sys.symmetric_keys
    WHERE name LIKE '%DatabaseMasterKey%')
BEGIN
    CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'ClaveFuerte@2024';
END


-- Crear CERTIFICADO
IF NOT EXISTS 
    (SELECT *
    FROM sys.certificates
    WHERE name = 'CertificadoSeguridad')
BEGIN
    CREATE CERTIFICATE CertificadoSeguridad
    WITH SUBJECT = 'Cifrado de datos personales en Consorcio.Persona';
END


-- Crear LLAVE SIMÉTRICA con AES_256
IF NOT EXISTS
    (SELECT *
    FROM sys.symmetric_keys
    WHERE name = 'LlaveCifrado')
BEGIN
    CREATE SYMMETRIC KEY LlaveCifrado
    WITH ALGORITHM = AES_256
    ENCRYPTION BY CERTIFICATE CertificadoSeguridad;
END


PRINT '--- Aplicando cifrado sobre tabla Persona ---';

-- Agregamos columnas cifradas si no existen
IF COL_LENGTH('Consorcio.Persona', 'DNI_Encriptado') IS NULL
    ALTER TABLE Consorcio.Persona 
    ADD DNI_Encriptado VARBINARY(MAX);
IF COL_LENGTH('Consorcio.Persona', 'Email_Encriptado') IS NULL
    ALTER TABLE Consorcio.Persona
    ADD Email_Encriptado VARBINARY(MAX);
IF COL_LENGTH('Consorcio.Persona', 'CVU_Encriptado') IS NULL
    ALTER TABLE Consorcio.Persona
    ADD CVU_Encriptado VARBINARY(MAX);


-- Ciframos los datos
OPEN SYMMETRIC KEY LlaveCifrado DECRYPTION BY CERTIFICATE CertificadoSeguridad;

UPDATE Consorcio.Persona
SET 
    CVU_Encriptado   = EncryptByKey(Key_GUID('LlaveCifrado'), CAST(CVU_CBUPersona AS NVARCHAR(30)));

CLOSE SYMMETRIC KEY LlaveCifrado;


PRINT '--- Datos personales cifrados correctamente ---';

END;
-- Creamos una vista que "desencripta" los campos para lectura controlada.

-- IMPORTANTE: asegurar que solo los roles adecuados tengan SELECT sobre esta vista.
GO



CREATE OR ALTER VIEW Consorcio.vw_PersonasLegibles
AS
SELECT 
    p.idPersona,           -- usa el nombre real de tu PK
    p.nombre,
    CONVERT(VARCHAR, DecryptByKeyAutoCert(CERT_ID('CertificadoSeguridad'), NULL, DNI_Encriptado)) AS DNI,
    CONVERT(VARCHAR, DecryptByKeyAutoCert(CERT_ID('CertificadoSeguridad'), NULL, Email_Encriptado)) AS Email,
    CONVERT(VARCHAR, DecryptByKeyAutoCert(CERT_ID('CertificadoSeguridad'), NULL, CVU_Encriptado)) AS CVU
FROM Consorcio.Persona p;
GO

GRANT SELECT ON Consorcio.vw_PersonasLegibles TO AdministrativoGeneral, AdministrativoOperativo, Sistemas;
GO




/* =========================================================================================
   POLÍTICA DE BACKUP Y RECUPERACIÓN
========================================================================================= */



PRINT '--- Definiendo política de backup ---';

-- BACKUP COMPLETO (Semanal)

BACKUP DATABASE Com5600G11
TO DISK = 'D:\Backups\Com5600G11_Full.bak'
WITH INIT, NAME = 'Backup completo semanal - Com5600G11',
     COMPRESSION, STATS = 10;


-- BACKUP DIFERENCIAL (Diario)

BACKUP DATABASE Com5600G11
TO DISK = 'D:\Backups\Com5600G11_Diff.bak'
WITH DIFFERENTIAL, NAME = 'Backup diario diferencial - Com5600G11',
     COMPRESSION, STATS = 10;


-- BACKUP DE LOG DE TRANSACCIONES (Cada 4 horas)

BACKUP LOG Com5600G11
TO DISK = 'D:\Backups\Com5600G11_Log.trn'
WITH NOINIT, NAME = 'Backup de logs - cada 4 horas',
     STATS = 5;

PRINT '--- Backups configurados correctamente ---';

/*
    DOCUMENTACIÓN DE POLÍTICA DE RESPALDO:

- Backup completo: cada domingo 00:00 hs (archivo semanal).
- Backup diferencial: todos los días 02:00 hs (archivo diferencial diario).
- Backup de logs: cada 4 horas (archivos .trn para poder recuperar punto en tiempo).
- RPO (Recovery Point Objective): 4 horas (pérdida máxima aceptable).
- RTO (Recovery Time Objective): 2 horas (tiempo objetivo para recuperar el servicio).
- Responsable operativo: rol “Sistemas”.
- Almacenamiento secundario: copia a NAS corporativo + copia semanal a la nube (ej. blob storage).
- Verificación automática: crear job que valide integridad del backup
    (RESTORE VERIFYONLY o checksums).
- Observación: cambiar rutas D:\Backups y permisos de acceso en el
    servidor antes de usar en producción.

*/

PRINT '--- Fin de script de seguridad y cifrado ---';


END
GO

-- EJEMPLO DE INVOCACIÓN:
-- EXEC Operaciones.sp_SeguridadCifrado;
