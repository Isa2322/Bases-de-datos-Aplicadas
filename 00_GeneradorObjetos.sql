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
-Cada maestro debe importarse con un SP distinto. No se aceptaran scripts que
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
el entorno de ejecucion deberia adaptarse sin modificar el fuente (si obviamente el
script de testing). La configuracion escogida debe aparecer en comentarios del
modulo.
- El uso de SQL dinamico no esta exigido en forma explicita pero puede que
encuentre que es la unica forma de resolver algunos puntos. No abuse del SQL
dinamico, debera justificar su uso siempre.
- Respecto a los informes XML: no se espera que produzcan un archivo nuevo en el
filesystem, basta con que el resultado de la consulta sea XML.
- Se espera que apliquen en todo el trabajo las pautas consignadas en la Unidad 3
respecto a optimizacion de codigo y de tipos de datos.
*/

USE master;
GO
-- Me fijo si la base existe y si es asi cierro todo lo q se este haciendo con ella y la dropeo
IF DB_ID(N'Com5600G11') IS NOT NULL
BEGIN
    -- saco a todos los q la esten usando
    ALTER DATABASE [Com5600G11] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
    -- la dropeo
    DROP DATABASE [Com5600G11]
END
GO
-- CREO LA BASE
CREATE DATABASE [Com5600G11]
GO
-- USO LA BASE DEL TP
USE [Com5600G11]
GO

--   CREACION  DE  ESQUEMAS  _________________________________________________________
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Operaciones')
BEGIN
    EXEC('CREATE SCHEMA Operaciones');
    PRINT N'schema "Operaciones" no existia: se creo correctamente.';
END
ELSE
BEGIN
    PRINT N'schema "Operaciones" ya existe: no se creo nada.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Negocio')
BEGIN
    EXEC('CREATE SCHEMA Negocio');
    PRINT N'schema "Negocio" no existia: se creo correctamente.';
END
ELSE
BEGIN
    PRINT N'schema "Negocio" ya existe: no se creo nada.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Consorcio')
BEGIN
    EXEC('CREATE SCHEMA Consorcio');
    PRINT N'schema "Consorcio" no existia: se creo correctamente.';
END
ELSE
BEGIN
    PRINT N'schema "Consorcio" ya existe: no se creo nada.';
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'Pago')
BEGIN
    EXEC('CREATE SCHEMA Pago');
    PRINT N'schema "Pago" no existia: se creo correctamente.';
END
ELSE
BEGIN
    PRINT N'schema "Pago" ya existe: no se creo nada.';
END
GO

-- CREACION  DE   TABLAS   _________________________________________________________

--TIPO ROL
IF OBJECT_ID('Consorcio.TipoRol', 'U') IS NOT NULL
DROP TABLE Consorcio.TipoRol;
GO

CREATE TABLE Consorcio.TipoRol (
    idTipoRol INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(200)
);
GO

-- Tabla: Persona
IF OBJECT_ID('Consorcio.Persona', 'U') IS NOT NULL
    DROP TABLE Consorcio.Persona;
GO

CREATE TABLE Consorcio.Persona (
    idPersona INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    dni VARCHAR(20) NOT NULL,
    email VARCHAR(150),
    telefono VARCHAR(50),
    CVU_CBU VARCHAR(22),
    idTipoRol INT NOT NULL,
    CONSTRAINT FK_Consorcio_TipoRol FOREIGN KEY (idTipoRol) 
        REFERENCES Consorcio.TipoRol(idTipoRol)
);
GO



IF OBJECT_ID(N'Consorcio.CuentaBancaria','U') IS NULL
BEGIN
	CREATE TABLE Consorcio.CuentaBancaria(
		CVU_CBU CHAR(22) PRIMARY KEY,
		nombreTitular VARCHAR(50),
		saldo DECIMAL(10,2)
		)
END
GO

--PERSONA
IF OBJECT_ID('Consorcio.Persona', 'U') IS NOT NULL
DROP TABLE Consorcio.Persona;
GO
BEGIN
    CREATE TABLE Consorcio.Persona 
    (
        idPersona INT IDENTITY(1,1) PRIMARY KEY,
        nombre VARCHAR(100) NOT NULL,
        apellido VARCHAR(100) NOT NULL,
        dni VARCHAR(20) NOT NULL,
        email VARCHAR(150),
        telefono VARCHAR(50),
        CVU_CBU VARCHAR(22),
        idTipoRol INT NOT NULL,
        CONSTRAINT FK_Consorcio_TipoRol FOREIGN KEY (idTipoRol) 
            REFERENCES Consorcio.TipoRol(idTipoRol)
    )
END
GO

--CUENTA BANCARIA
IF OBJECT_ID(N'Consorcio.CuentaBancaria','U') IS NOT NULL
DROP TABLE Consorcio.CuentaBancaria
GO
BEGIN
	CREATE TABLE Consorcio.CuentaBancaria
    (
		CVU_CBU CHAR(22) PRIMARY KEY,
		nombreTitular VARCHAR(50),
		saldo DECIMAL(10,2)
	)
END
GO

--CONSORCIO
IF OBJECT_ID(N'Consorcio.Consorcio','U') IS NOT NULL
DROP TABLE Consorcio.Consorcio
GO
BEGIN
	CREATE TABLE Consorcio.Consorcio
    (
		id INT IDENTITY(1,1),
		nombre VARCHAR(100) NOT NULL,
		CVU_CBU CHAR(22),
		direccion VARCHAR(200) NOT NULL,
		metrosCuadradosTotal DECIMAL(10,2),
		CONSTRAINT PK_id PRIMARY KEY(id),
		CONSTRAINT FK_CVU_CBU FOREIGN KEY (CVU_CBU) REFERENCES Consorcio.CuentaBancaria(CVU_CBU)
	)
END
GO

--FORMA DE PAGO
IF OBJECT_ID(N'Pago.FormaDePago', 'U') IS NOT NULL
DROP TABLE Pago.FormaDePago
GO
BEGIN
    CREATE TABLE Pago.FormaDePago 
    (
        idFormaPago INT IDENTITY(1,1) NOT NULL,
        descripcion VARCHAR(50) NOT NULL,
        confirmacion VARCHAR(20) NULL, 
        CONSTRAINT PK_FormaDePago PRIMARY KEY CLUSTERED (idFormaPago)
    )
END
GO

--EXPENSA
IF OBJECT_ID(N'Negocio.Expensa', 'U') IS NOT NULL
DROP TABLE Negocio.Expensa
GO
BEGIN
    CREATE TABLE Negocio.Expensa
    (
        id INT PRIMARY KEY,
        consorcio_id INT,
        saldoAnterior DECIMAL(10,2),
        ingresosEnTermino DECIMAL(10,2),
        ingresosAdeudados DECIMAL(10,2),
        ingresosAdelantados DECIMAL(10,2),
        egresos DECIMAL(10,2),
        saldoCierre DECIMAL(10,2),
        fechaPeriodoAnio INT NULL, 
        fechaPeriodoMes INT NULL,  
        FOREIGN KEY (consorcio_id) REFERENCES Consorcio.Consorcio(id)
    )
END
GO

--UNIDAD FUNCIONAL
IF OBJECT_ID(N'Consorcio.UnidadFuncional', 'U') IS NOT NULL
DROP TABLE Consorcio.UnidadFuncional
GO
BEGIN
    CREATE TABLE Consorcio.UnidadFuncional
    (
        id INT IDENTITY(1,1) PRIMARY KEY,
        CVU_CBU CHAR(22) NOT NULL,
        consorcioId INT NOT NULL,
        departamento VARCHAR(10) NULL,
        piso VARCHAR(10) NULL,
        numero VARCHAR(10) NULL,
        metrosCuadrados DECIMAL(10, 2) NOT NULL,
        porcentajeExpensas DECIMAL(5, 2) NOT NULL,
        tipo VARCHAR(50) NULL,
        CONSTRAINT FK_UF_CuentaBancaria FOREIGN KEY (CVU_CBU) REFERENCES Consorcio.CuentaBancaria(CVU_CBU), 
        CONSTRAINT FK_UF_Consorcio FOREIGN KEY (consorcioId) REFERENCES Consorcio.Consorcio(id)
    )
END
GO

--GASTO ORDINARIO
IF OBJECT_ID(N'Negocio.GastoOrdinario', 'U') IS NOT NULL
DROP TABLE Negocio.GastoOrdinario
GO
BEGIN
    CREATE TABLE Negocio.GastoOrdinario 
    (
        idGasto INT PRIMARY KEY IDENTITY,
        idExpensa INT NOT NULL, 
        nombreEmpresaoPersona VARCHAR(200) NULL,
        nroFactura CHAR(10) NOT NULL, -- CHAR(10) y NOT NULL
        fechaEmision DATE NULL,
        importeTotal DECIMAL(18, 2) NOT NULL,
        detalle VARCHAR(500) NULL,
        tipoServicio VARCHAR(50) NULL,

        -- RESTRICCIONES DE UNICIDAD Y FORMATO
        CONSTRAINT UQ_NroFactura UNIQUE (nroFactura),
        CONSTRAINT CHK_NroFactura_Numerico CHECK (
            ISNUMERIC(nroFactura) = 1 
            AND LEN(nroFactura) = 10 
            AND CAST(nroFactura AS BIGINT) > 0
        ),
        
        -- Llave Foránea a Negocio.Expensa
        CONSTRAINT FK_GastoOrd_Expensa FOREIGN KEY (idExpensa) REFERENCES Negocio.Expensa(id)
    )
END
GO

--GASTO EXTRAORDINARIO
IF OBJECT_ID(N'Negocio.GastoExtraordinario', 'U') IS NOT NULL
DROP TABLE Negocio.GastoExtraordinario
GO
BEGIN
    CREATE TABLE Negocio.GastoExtraordinario 
    (
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
        CONSTRAINT FK_GastoExt_Expensa FOREIGN KEY (idExpensa) REFERENCES Negocio.Expensa(id) 
    )
END
GO

--PAGO
IF OBJECT_ID(N'Pago.Pago', 'U') IS NOT NULL
DROP TABLE Pago.Pago
GO
BEGIN
    CREATE TABLE Pago.Pago 
    (
        id INT IDENTITY(1,1) NOT NULL,
        idFormaPago INT NOT NULL, 
        cbuCuentaOrigen VARCHAR(50) NOT NULL, 
        fecha DATETIME2(0) NOT NULL DEFAULT GETDATE(),
        importe DECIMAL(18, 2) NOT NULL, 
        CONSTRAINT PK_Pago PRIMARY KEY CLUSTERED (id),
        CONSTRAINT FK_Pago_FormaDePago FOREIGN KEY (idFormaPago) REFERENCES Pago.FormaDePago (idFormaPago)
    );
END
GO

--DETALLE EXPENSA
IF OBJECT_ID(N'Negocio.DetalleExpensa', 'U') IS NOT NULL
DROP TABLE Negocio.DetalleExpensa
GO
BEGIN
    CREATE TABLE Negocio.DetalleExpensa
    (
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
    )
END
GO

--COCHERA
IF OBJECT_ID(N'Consorcio.Cochera', 'U') IS NOT NULL
DROP TABLE Consorcio.Cochera
GO
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
GO

--BAULERA
IF OBJECT_ID(N'Consorcio.Baulera', 'U') IS NOT NULL
DROP TABLE Consorcio.Baulera
GO
BEGIN
    CREATE TABLE Consorcio.Baulera
    (
        id INT IDENTITY(1,1) PRIMARY KEY,
        unidadFuncionalId INT NULL,
        numero VARCHAR(10) NOT NULL,
        porcentajeExpensas DECIMAL(5, 2) NOT NULL,
        CONSTRAINT FK_Baulera_UnidadFuncional FOREIGN KEY (unidadFuncionalId) REFERENCES Consorcio.UnidadFuncional(id)
    )
END
GO

--PAGO APLICADO
IF OBJECT_ID(N'Pago.PagoAplicado', 'U') IS NOT NULL
DROP TABLE Pago.PagoAplicado
GO
BEGIN
    CREATE TABLE Pago.PagoAplicado 
    (
        idPago INT NOT NULL, 
        idDetalleExpensa INT NOT NULL, 
        importeAplicado DECIMAL(18, 2) NOT NULL, 
        CONSTRAINT PK_PagoAplicado PRIMARY KEY CLUSTERED (idPago, idDetalleExpensa),
        CONSTRAINT FK_PagoAplicado_Pago FOREIGN KEY (idPago) REFERENCES Pago.Pago (id), 
        CONSTRAINT FK_PagoAplicado_DetalleExpensa FOREIGN KEY (idDetalleExpensa) REFERENCES Negocio.DetalleExpensa (id)
    )
END
GO
