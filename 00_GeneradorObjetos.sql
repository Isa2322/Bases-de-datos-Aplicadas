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
Se requiere que importe toda la información antes mencionada a la base de datos:
• Genere los objetos necesarios (store procedures, funciones, etc.) para importar los
archivos antes mencionados. Tenga en cuenta que cada mes se recibirán archivos de
novedades con la misma estructura, pero datos nuevos para agregar a cada maestro.
• Considere este comportamiento al generar el código. Debe admitir la importación de
novedades periódicamente sin eliminar los datos ya cargados y sin generar
duplicados.
• Cada maestro debe importarse con un SP distinto. No se aceptarán scripts que
realicen tareas por fuera de un SP. Se proveerán archivos para importar en MIEL.
• La estructura/esquema de las tablas a generar será decisión suya. Puede que deba
realizar procesos de transformación sobre los maestros recibidos para adaptarlos a la
estructura requerida. Estas adaptaciones deberán hacerla en la DB y no en los
archivos provistos.
• Los archivos CSV/JSON no deben modificarse. En caso de que haya datos mal
cargados, incompletos, erróneos, etc., deberá contemplarlo y realizar las correcciones
en la fuente SQL. (Sería una excepción si el archivo está malformado y no es posible
interpretarlo como JSON o CSV, pero los hemos verificado cuidadosamente).
• Tener en cuenta que para la ampliación del software no existen datos; se deben
preparar los datos de prueba necesarios para cumplimentar los requisitos planteados.
• El código fuente no debe incluir referencias hardcodeadas a nombres o ubicaciones
de archivo. Esto debe permitirse ser provisto por parámetro en la invocación. En el
código de ejemplo se verá dónde el grupo decidió ubicar los archivos, pero si cambia
el entorno de ejecución debería adaptarse sin modificar el fuente (sí obviamente el
script de testing). La configuración escogida debe aparecer en comentarios del
módulo.
• El uso de SQL dinámico no está exigido en forma explícita… pero puede que
encuentre que es la única forma de resolver algunos puntos. No abuse del SQL
dinámico, deberá justificar su uso siempre.
• Respecto a los informes XML: no se espera que produzcan un archivo nuevo en el
filesystem, basta con que el resultado de la consulta sea XML.
• Se espera que apliquen en todo el trabajo las pautas consignadas en la Unidad 3
respecto a optimización de código y de tipos de datos.
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

DROP TABLE IF EXISTS Pago.FormaDePago
GO

CREATE TABLE Pago.FormaDePago (
    idFormaPago INT IDENTITY(1,1) NOT NULL,
    
    descripcion VARCHAR(50) NOT NULL,
    
    confirmacion VARCHAR(20) NULL, 
    
    CONSTRAINT PK_FormaDePago PRIMARY KEY CLUSTERED (idFormaPago)
);
GO

DROP TABLE IF EXISTS Pago.Pago
GO
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
GO

DROP TABLE IF EXISTS Pago.PagoAplicado
GO
CREATE TABLE Pago.PagoAplicado (
    idPago INT NOT NULL, 
    
    idDetalleExpensa INT NOT NULL, 
    
    importeAplicado DECIMAL(18, 2) NOT NULL, 
    
    CONSTRAINT PK_PagoAplicado PRIMARY KEY CLUSTERED (idPago, idDetalleExpensa),
    
    CONSTRAINT FK_PagoAplicado_Pago FOREIGN KEY (idPago)
    REFERENCES Pago.Pago (id),
    --CONSTRAINT FK_PagoAplicado_DetalleExpensa FOREIGN KEY (idDetalleExpensa)
    --REFERENCES Consorcio.DetalleExpensa (idDetalleExpensa)
);
GO


-- Nos fijamos que no exista antes de crear la tabla Expensa para la FK
IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE object_id = OBJECT_ID(N'Negocio.Expensa') AND type = 'U')
BEGIN
    CREATE TABLE Negocio.Expensa (
        id INT PRIMARY KEY IDENTITY,
        idConsorcio INT NULL,
        periodo NVARCHAR(50) NULL
    )
END
GO


IF OBJECT_ID(N'Negocio.GastoOrdinario', 'U') IS NULL
CREATE TABLE Negocio.GastoOrdinario (
    idGasto INT PRIMARY KEY IDENTITY,
    idExpensa INT NOT NULL,  -- FK hacia Expensa
    idConsorcio int not null, -- fk consorcio
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
    idConsorcio int not null, -- fk consorcio
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


IF NOT EXISTS(SELECT name FROM sys.tables WHERE name= 'Consorcio.CuentaBancaria')
BEGIN
		CREATE TABLE Consorcio.CuentaBancaria( 
		CVU_CBU CHAR(22)  NOT NULL,
		CUIL INT  NOT NULL,
		idPersona INT  NOT NULL,
		nombreTitular varchar(50),
		saldo decimal(10,2),
		CONSTRAINT PK_CVU_CBU PRIMARY KEY(CVU_CBU),
		CONSTRAINT FK_CUIL FOREIGN KEY (CUIL) 
		REFERENCES Consorcio.Persona(CUIL),
		CONSTRAINT FK_idPersona FOREIGN KEY(idPersona)
		REFERENCES Consorcio.Persona(idPersona),
		CONSTRAINT CHK_saldo CHECK(saldo >=0)
		)
END
GO

IF NOT EXISTS(SELECT name FROM sys.tables WHERE name='Consorsio.Consorcio')
BEGIN
		CREATE TABLE Consorcio.Consorcio(
		id INT IDENTITY (1,1) NOT NULL,
		nombre VARCHAR(50) NOT NULL,
		direccion VARCHAR(100),
		metrosCuadradosTotal decimal(10,2) NOT NULL,
		CONSTRAINT PK_id PRIMARY KEY(id),
		CONSTRAINT CHK_metrosCuadradosTotal CHECK(metrosCuadradosTotal>0)
		)
END
GO