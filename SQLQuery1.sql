CREATE TABLE Consorcio.UnidadFuncional 
(
    id INT IDENTITY(1,1) PRIMARY KEY,
    CVU_CBUPersona CHAR(22) NOT NULL, 
    consorcioId INT NOT NULL, 
    departamento VARCHAR(10),
    piso VARCHAR(10),
    numero VARCHAR(10),
    metrosCuadrados DECIMAL(10, 2) NOT NULL,
    porcentajeExpensas DECIMAL(5, 2) NOT NULL,
    tipo VARCHAR(50),
	CONSTRAINT FK_CVUCBUPersona FOREIGN KEY (CVU_CBUPersona) REFERENCES Consorcio.CuentaBancaria(CVU_CBU),
	CONSTRAINT FK_consorcioId FOREIGN KEY (consorcioId) REFERENCES Consorcio.Consorcio(id)
);
GO

CREATE TABLE Consorcio.Cochera 
(
    id INT IDENTITY(1,1) PRIMARY KEY,
    unidadFuncionalId INT, 
    numero VARCHAR(10) NOT NULL,
    porcentajeExpensas DECIMAL(5, 2) NOT NULL,
    CONSTRAINT FK_Cochera_UnidadFuncional FOREIGN KEY (unidadFuncionalId) REFERENCES UnidadFuncional(id)
);
GO

CREATE TABLE Consorcio.Baulera 
(
    id INT IDENTITY(1,1) PRIMARY KEY,
    unidadFuncionalId INT,
    numero VARCHAR(10) NOT NULL,
    porcentajeExpensas DECIMAL(5, 2) NOT NULL,
    CONSTRAINT FK_Baulera_UnidadFuncional FOREIGN KEY (unidadFuncionalId) REFERENCES UnidadFuncional(id)
);
GO
