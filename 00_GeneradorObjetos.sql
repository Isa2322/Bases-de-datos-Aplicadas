/*
Base de datos aplicadas
Com:3641
Fecha de entrega: 7/11
Grupo 11

Miembros:
Hidalgo, Eduardo - 41173099
Quispe, Milagros Soledad - 45064110
Puma, Florencia - 42945609
Fontanet Caniza, Camila - 44892126
Altamiranda, Isaias Taiel - 43094671
Pastori, Ximena - 42300128

Enunciado:
Base de datos lineamientos generales
Se requiere que importe toda la informacion antes mencionada a la base de datos:
- Genere los objetos necesarios (store procedures, funciones, etc.) para importar los
archivos antes mencionados. Tenga en cuenta que cada mes se recibiran archivos de
novedades con la misma estructura, pero datos nuevos para agregar a cada maestro.
- Considere este comportamiento al generar el codigo. Debe admitir la importacion de
novedades periodicamente sin eliminar los datos ya cargados y sin generar
duplicados.
- Cada maestro debe importarse con un SP distinto. No se aceptaran scripts que
realicen tareas por fuera de un SP. Se proveeran archivos para importar en MIEL.
- La estructura/esquema de las tablas a generar sera decision suya. Puede que deba
realizar procesos de transformacion sobre los maestros recibidos para adaptarlos a la
estructura requerida. Estas adaptaciones deberan hacerla en la DB y no en los
archivos provistos.
- Los archivos CSV/JSON no deben modificarse. En caso de que haya datos mal
cargados, incompletos, erroneos, etc., debera contemplarlo y realizar las correcciones
en la fuente SQL. (Seria una excepcion si el archivo esta malformado y no es posible
interpretarlo como JSON o CSV, pero los hemos verificado cuidadosamente).
- Tener en cuenta que para la ampliacion del software no existen datos; se deben
preparar los datos de prueba necesarios para cumplimentar los requisitos planteados.
- El codigo fuente no debe incluir referencias hardcodeadas a nombres o ubicaciones
de archivo. Esto debe permitirse ser provisto por parametro en la invocacion. En el
codigo de ejemplo se vera donde el grupo decidio ubicar los archivos, pero si cambia
el entorno de ejecucion debería adaptarse sin modificar el fuente (si obviamente el
script de testing). La configuracion escogida debe aparecer en comentarios del
módulo.
- El uso de SQL dinamico no esta exigido en forma explicita… pero puede que
encuentre que es la unica forma de resolver algunos puntos. No abuse del SQL
dinamico, debera justificar su uso siempre.
- Respecto a los informes XML: no se espera que produzcan un archivo nuevo en el
filesystem, basta con que el resultado de la consulta sea XML.
- Se espera que apliquen en todo el trabajo las pautas consignadas en la Unidad 3
respecto a optimización de codigo y de tipos de datos.
*/

EXEC msdb.dbo.sp_delete_database_backuphistory @database_name = N'Com5600G11'
GO
USE [master]
GO

-- Forzar desconexion de la base de datos
ALTER DATABASE Com5600G11 SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
go

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'Com5600G11')
BEGIN
    CREATE DATABASE Com5600G11;
END;
GO

use [Com5600G11];
go 

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Operaciones')
BEGIN
    EXEC('CREATE SCHEMA Operaciones');
    PRINT N'schema "Operaciones" no existía: se creó correctamente.';
END
ELSE
BEGIN
    PRINT N'schema "Operaciones" ya existe: no se creó nada.';
END
GO

-- Nos fijamos que no exista antes de crearlo
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Negocio')
BEGIN
    EXEC('CREATE SCHEMA Negocio');
    PRINT N'schema "Negocio" no existía: se creó correctamente.';
END
ELSE
BEGIN
    PRINT N'schema "Negocio" ya existe: no se creó nada.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Consorcio')
BEGIN
    EXEC('CREATE SCHEMA Consorcio');
    PRINT N'schema "Consorcio" no existía: se creó correctamente.';
END
ELSE
BEGIN
    PRINT N'schema "Consorcio" ya existe: no se creó nada.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Pago')
BEGIN
    EXEC('CREATE SCHEMA Pago');
    PRINT N'schema "Pago" no existía: se creó correctamente.';
END
ELSE
BEGIN
    PRINT N'schema "Pago" ya existe: no se creó nada.';
END
GO



-- Nos fijamos que no exista antes de crearlo
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Negocio')
BEGIN
    EXEC('CREATE SCHEMA Negocio');
    PRINT N'schema "Negocio" no existía: se creó correctamente.';
END
ELSE
BEGIN
    PRINT N'schema "Negocio" ya existe: no se creó nada.';
END
GO



-- Nos fijamos que no exista antes de crear la tabla Expensa para la FK
DROP TABLE IF EXISTS Negocio.Expensa;
CREATE TABLE Negocio.Expensa(
    id INT PRIMARY KEY,
    consorcio_id INT,
    saldoAnterior DECIMAL(10,2),
    ingresosEnTermino DECIMAL(10,2),
    ingresosAdeudados DECIMAL(10,2),
    ingresosAdelantados DECIMAL(10,2),
    egresos DECIMAL(10,2),
    saldoCierre DECIMAL(10,2),
    FOREIGN KEY (consorcio_id) REFERENCES Negocio.Consorcio(id)
);


DROP TABLE IF EXISTS Negocio.DetalleExpensa;
CREATE TABLE Negocio.DetalleExpensa(
    id INT PRIMARY KEY,
    expensaId INT,
    idUnidadFuncional INT,
    prorrateoOrdinario DECIMAL(10,2),
    prorrateoExtraordinario DECIMAL(10,2),
    interesMora DECIMAL(10,2),
    totalaPagar DECIMAL(10,2),
    saldoAnteriorAbonado DECIMAL(10,2),
    pagosRecibidos DECIMAL(10,2),
    primerVencimiento DATE,
    segundoVencimiento DATE,
    FOREIGN KEY (expensaId) REFERENCES Negocio.Expensa(id),
    FOREIGN KEY (idUnidadFuncional) REFERENCES Consorcio.UnidadFuncional(id)
);


IF OBJECT_ID(N'Negocio.GastoOrdinario', 'U') IS NULL
CREATE TABLE Negocio.GastoOrdinario (
    idGasto INT PRIMARY KEY IDENTITY,
    idExpensa INT NOT NULL,  -- FK hacia Expensa
    nombreEmpresaoPersona VARCHAR(200) NULL,
    nroFactura VARCHAR(50) NULL,
    fechaEmision DATE NULL,
    importeTotal DECIMAL(18, 2) NOT NULL,
    detalle VARCHAR(500) NULL,
    tipoServicio VARCHAR(50) NULL,
    CONSTRAINT FK_GastoOrd_Expensa FOREIGN KEY (idExpensa) 
        REFERENCES Negocio.Expensa(id)
)
ELSE
    PRINT N'Ya existe la tabla.'
GO

IF OBJECT_ID(N'Negocio.GastoExtraordinario', 'U') IS NULL
CREATE TABLE Negocio.GastoExtraordinario (
    idGasto INT PRIMARY KEY IDENTITY,
    idExpensa INT NOT NULL, 
    nombreEmpresaoPersona VARCHAR(200) NULL,
    nroFactura VARCHAR(50) NULL,
    fechaEmision DATE NULL,
    importeTotal DECIMAL(18, 2) NOT NULL,
    detalle VARCHAR(500) NULL,
    esPagoTotal BIT NOT NULL,
    nroCuota INT NULL,
    totalCuota DECIMAL(18, 2) NOT NULL,
    CONSTRAINT FK_GastoExt_Expensa FOREIGN KEY (idExpensa) 
        REFERENCES Negocio.Expensa(id)
)
ELSE
    PRINT N'Ya existe la tabla.'
GO

IF OBJECT_ID(N'Consorcio.UnidadFuncional', 'U') IS NULL
BEGIN
    CREATE TABLE Consorcio.UnidadFuncional
    (
        id INT IDENTITY(1,1) PRIMARY KEY,
        CVU_CBUPersona CHAR(22) NOT NULL,
        consorcioId INT NOT NULL,
        departamento VARCHAR(10) NULL,
        piso VARCHAR(10) NULL,
        numero VARCHAR(10) NULL,
        metrosCuadrados DECIMAL(10, 2) NOT NULL,
        porcentajeExpensas DECIMAL(5, 2) NOT NULL,
        tipo VARCHAR(50) NULL,
        
        CONSTRAINT FK_UF_CuentaBancaria FOREIGN KEY (CVU_CBUPersona) 
            REFERENCES Persona.CuentaBancaria(CVU_CBU), 
            
        CONSTRAINT FK_UF_Consorcio FOREIGN KEY (consorcioId) 
            REFERENCES Consorcio.ConsorcioMaster(idConsorcio)
    );
END
ELSE
    PRINT N'Ya existe la tabla Consorcio.UnidadFuncional.';
GO

---

IF OBJECT_ID(N'Consorcio.Cochera', 'U') IS NULL
BEGIN
    CREATE TABLE Consorcio.Cochera
    (
        id INT IDENTITY(1,1) PRIMARY KEY,
        unidadFuncionalId INT NULL,
        numero VARCHAR(10) NOT NULL,
        porcentajeExpensas DECIMAL(5, 2) NOT NULL,
        
        CONSTRAINT FK_Cochera_UnidadFuncional FOREIGN KEY (unidadFuncionalId) 
            REFERENCES Consorcio.UnidadFuncional(id)
    );
END
ELSE
    PRINT N'Ya existe la tabla Consorcio.Cochera.';
GO

---

IF OBJECT_ID(N'Consorcio.Baulera', 'U') IS NULL
BEGIN
    CREATE TABLE Consorcio.Baulera
    (
        id INT IDENTITY(1,1) PRIMARY KEY,
        unidadFuncionalId INT NULL,
        numero VARCHAR(10) NOT NULL,
        porcentajeExpensas DECIMAL(5, 2) NOT NULL,
        
        CONSTRAINT FK_Baulera_UnidadFuncional FOREIGN KEY (unidadFuncionalId) 
            REFERENCES Consorcio.UnidadFuncional(id)
    );
END
ELSE
    PRINT N'Ya existe la tabla Consorcio.Baulera.';
GO

IF OBJECT_ID(N'Pago.FormaDePago', 'U') IS NULL
BEGIN
    CREATE TABLE Pago.FormaDePago (
        idFormaPago INT IDENTITY(1,1) NOT NULL,
        
        descripcion VARCHAR(50) NOT NULL,
        
        confirmacion VARCHAR(20) NULL, 
        
        CONSTRAINT PK_FormaDePago PRIMARY KEY CLUSTERED (idFormaPago)
    );
END
GO


IF OBJECT_ID(N'Pago.Pago', 'U') IS NULL
BEGIN
    CREATE TABLE Pago.Pago (
        id INT IDENTITY(1,1) NOT NULL,
        
        idFormaPago INT NOT NULL, 
        
        cbuCuentaOrigen VARCHAR(50) NOT NULL, 
        
        fecha DATETIME2(0) NOT NULL DEFAULT GETDATE(),
        
        importe DECIMAL(18, 2) NOT NULL, 
        
        CONSTRAINT PK_Pago PRIMARY KEY CLUSTERED (id),
        
        CONSTRAINT FK_Pago_FormaDePago FOREIGN KEY (idFormaPago)
            REFERENCES Pago.FormaDePago (idFormaPago)
    );
END
GO


IF OBJECT_ID(N'Pago.PagoAplicado', 'U') IS NULL
BEGIN
    CREATE TABLE Pago.PagoAplicado (
        idPago INT NOT NULL, 
        
        idDetalleExpensa INT NOT NULL, 
        
        importeAplicado DECIMAL(18, 2) NOT NULL, 
        
        CONSTRAINT PK_PagoAplicado PRIMARY KEY CLUSTERED (idPago, idDetalleExpensa),
        
        CONSTRAINT FK_PagoAplicado_Pago FOREIGN KEY (idPago)
        REFERENCES Pago.Pago (id)
        
        -- La clave foránea a Consorcio.DetalleExpensa debe estar en la posición correcta
        -- del script general para asegurar que su padre también exista.
        -- CONSTRAINT FK_PagoAplicado_DetalleExpensa FOREIGN KEY (idDetalleExpensa)
        -- REFERENCES Consorcio.DetalleExpensa (idDetalleExpensa)
    );
END
GO