/*
Trabajo Práctico Integrador - Bases de Datos Aplicada
Entrega 5 - Creación Tablas: Persona y TipoRol
Materia: 3641 - Bases de Datos Aplicada
*/

USE Com3900G02;
GO

-- Tabla: TipoRol
IF OBJECT_ID('Negocio.TipoRol', 'U') IS NOT NULL
    DROP TABLE Negocio.TipoRol;
GO

CREATE TABLE Negocio.TipoRol (
    idTipoRol INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(200)
);
GO

-- Tabla: Persona
IF OBJECT_ID('Negocio.Persona', 'U') IS NOT NULL
    DROP TABLE Negocio.Persona;
GO

CREATE TABLE Negocio.Persona (
    idPersona INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    dni VARCHAR(20) NOT NULL UNIQUE,
    email VARCHAR(150),
    telefono VARCHAR(50),
    cbu VARCHAR(22),
    cvu VARCHAR(22),
    idTipoRol INT NOT NULL,
    CONSTRAINT FK_Persona_TipoRol FOREIGN KEY (idTipoRol) 
        REFERENCES Negocio.TipoRol(idTipoRol)
);
GO
