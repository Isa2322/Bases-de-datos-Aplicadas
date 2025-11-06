-- =============================================

-- 1
IF OBJECT_ID('sp_analizar_flujo_egresos_semanal', 'P') IS NOT NULL
    DROP PROCEDURE sp_analizar_flujo_egresos_semanal;
GO

CREATE PROCEDURE sp_analizar_flujo_egresos_semanal
(
    @NombreConsorcio VARCHAR(100),
    @PeriodoAnio INT,
    @PeriodoMes INT
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IdConsorcio INT;
    DECLARE @IdExpensa INT;

    -- 1. Buscar la Expensa y el ID del Consorcio usando los tres par�metros
    SELECT 
        @IdConsorcio = C.id,
        @IdExpensa = E.id
    FROM Consorcio.Consorcio AS C
    INNER JOIN Negocio.Expensa AS E ON E.consorcio_id = C.id
    WHERE C.nombre = @NombreConsorcio 
      AND E.fechaPeriodoAnio = @PeriodoAnio 
      AND E.fechaPeriodoMes = @PeriodoMes;

    -- 2. Validar si la Expensa fue encontrada
    IF @IdExpensa IS NULL
    BEGIN
        IF @IdConsorcio IS NULL
        BEGIN
             RAISERROR('El Consorcio con nombre "%s" no fue encontrado.', 16, 1, @NombreConsorcio);
        END
        ELSE
        BEGIN
             RAISERROR('La Expensa para el Consorcio "%s" en el periodo %d/%d no fue encontrada.', 16, 1, @NombreConsorcio, @PeriodoMes, @PeriodoAnio);
        END
        RETURN;
    END;

    -- 3. Inicia la l�gica de CTE
    ; WITH EgresosCombinados AS ( 
        -- Ordinarios
        SELECT
            fechaEmision,
            importeTotal AS Gasto_Ordinario,
            0.00 AS Gasto_Extraordinario,
            importeTotal AS Gasto_Total
        FROM Negocio.GastoOrdinario
        WHERE idExpensa = @IdExpensa 
        
        UNION ALL
        
        -- Extraordinarios
        SELECT
            fechaEmision,
            0.00 AS Gasto_Ordinario,
            importeTotal AS Gasto_Extraordinario,
            importeTotal AS Gasto_Total
        FROM Negocio.GastoExtraordinario
        WHERE idExpensa = @IdExpensa
    ),
    EgresosSemanal AS ( 
        -- Agrupar los egresos por semana de todos los meses
        SELECT
            YEAR(fechaEmision) AS Anio,
            MONTH(fechaEmision) AS Mes,
            DATEPART(wk, fechaEmision) AS Semana, -- obtiene la semana 
            SUM(Gasto_Ordinario) AS Gasto_Ordinario_Semanal,
            SUM(Gasto_Extraordinario) AS Gasto_Extraordinario_Semanal,
            SUM(Gasto_Total) AS Gasto_Semanal_Total
        FROM EgresosCombinados
        GROUP BY YEAR(fechaEmision), MONTH(fechaEmision), DATEPART(wk, fechaEmision)
    )
    
    -- 4. SELECT final
    SELECT
        @NombreConsorcio AS Nombre_Consorcio, 
        @IdConsorcio AS ID_Consorcio,
        @IdExpensa AS ID_Expensa,
        FORMAT(CAST(CAST(@PeriodoAnio AS VARCHAR) + '-' + CAST(@PeriodoMes AS VARCHAR) + '-01' AS DATE), 'yyyy-MM') AS Periodo,
        ES.Anio,
        ES.Mes,
        ES.Semana,

        -- N2 : Numero 2 Digitos decimales
        FORMAT(ES.Gasto_Ordinario_Semanal, 'N2') AS Egreso_Ordinario,
        FORMAT(ES.Gasto_Extraordinario_Semanal, 'N2') AS Egreso_Extraordinario,
        FORMAT(ES.Gasto_Semanal_Total, 'N2') AS Egreso_Semanal_Total,
        
         -- Acumulado Progresivo
        FORMAT(SUM(ES.Gasto_Semanal_Total) OVER (
         ORDER BY ES.Anio, ES.Semana
        ROWS UNBOUNDED PRECEDING
        ), 'N2') AS Acumulado_Progresivo,
        
        -- Promedio en el Periodo
    FORMAT(AVG(ES.Gasto_Semanal_Total) OVER (), 'N2') AS Promedio_Periodo
        
    FROM EgresosSemanal AS ES
    where  @PeriodoAnio= ES.Anio AND @PeriodoMes =  ES.Mes
    ORDER BY ES.Anio, ES.Semana;
END
GO


-- 4
CREATE or alter PROCEDURE Negocio.SP_ObtenerTop5MesesGastosIngresos
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Top 5 meses con mayores gastos
    WITH GastosPorMes AS (
        SELECT 
            YEAR(e.fechaEmision) AS Anio,
            MONTH(e.fechaEmision) AS Mes,
            SUM(e.importeTotal) AS TotalGastos
        FROM (
            -- Union de gastos ordinarios y extraordinarios
            SELECT 
                idExpensa,
                fechaEmision,
                importeTotal
            FROM Negocio.GastoOrdinario
            WHERE fechaEmision IS NOT NULL
            
            UNION ALL
            
            SELECT 
                idExpensa,
                fechaEmision,
                importeTotal
            FROM Negocio.GastoExtraordinario
            WHERE fechaEmision IS NOT NULL
        ) e
        GROUP BY YEAR(e.fechaEmision), MONTH(e.fechaEmision)
    ),
    Top5Gastos AS (
        SELECT TOP 5
            Anio,
            Mes,
            DATENAME(MONTH, DATEFROMPARTS(Anio, Mes, 1)) AS NombreMes,
            TotalGastos,
            'Gasto' AS Tipo
        FROM GastosPorMes
        ORDER BY TotalGastos DESC
    ),
    
    -- Top 5 meses con mayores ingresos
    IngresosPorMes AS (
        SELECT 
            YEAR(de.primerVencimiento) AS Anio,
            MONTH(de.primerVencimiento) AS Mes,
            SUM(de.pagosRecibidos) AS TotalIngresos
        FROM Negocio.DetalleExpensa de
        WHERE de.primerVencimiento IS NOT NULL
            AND de.pagosRecibidos > 0
        GROUP BY YEAR(de.primerVencimiento), MONTH(de.primerVencimiento)
    ),
    Top5Ingresos AS (
        SELECT TOP 5
            Anio,
            Mes,
            DATENAME(MONTH, DATEFROMPARTS(Anio, Mes, 1)) AS NombreMes,
            TotalIngresos AS Monto,
            'Ingreso' AS Tipo
        FROM IngresosPorMes
        ORDER BY TotalIngresos DESC
    )
    
    -- Resultados combinados
    SELECT 
        Tipo,
        Anio,
        Mes,
        NombreMes,
        TotalGastos AS Monto
    FROM Top5Gastos
    
    UNION ALL
    
    SELECT 
        Tipo,
        Anio,
        Mes,
        NombreMes,
        Monto
    FROM Top5Ingresos
    
    ORDER BY Tipo DESC, Monto DESC;
    
END
GO

--EXEC Negocio.SP_ObtenerTop5MesesGastosIngresos;
--GO
-- =============================================

/*
    REPORTE 5:
    Obtenga los 3 (tres) propietarios con mayor morosidad. 
    Presente información de contacto y DNI de los propietarios para que la administración los pueda 
    contactar o remitir el trámite al estudio jurídico.
*/

CREATE OR ALTER PROCEDURE Reportes.sp_Reporte5_MayoresMorosos
    @idConsorcio INT = NULL,
    @fechaHasta DATE = NULL,
    @fechaDesde DATE = NULL 
AS
BEGIN
    SET NOCOUNT ON;
    -- relleno el filtro de fecha limite si vino vacio
    IF @fechaHasta IS NULL
        SET @fechaHasta = GETDATE(); 
        -- Fecha actual
    SELECT TOP(3)
        -- info a mostrar (nombre, ape, dni y datos de contacto)
        Negocio.Persona.CUIL AS DNI,
        Negocio.Persona.nombre,
        Negocio.Persona.Apellido,
        Negocio.Persona.emailPersonal,
        Negocio.Persona.telefonoContacto,
        -- calculo morosidad sumando todas sus expensas y restando todos sus pagos
        SUM(Negocio.DetalleExpensa.total - ISNULL(PagosAplicados.TotalPagado, 0)) AS MorosidadTotal
    FROM
        Negocio.DetalleExpensa
    JOIN
        Negocio.Expensa ON Negocio.DetalleExpensa.idExpensa = Negocio.Expensa.id
    JOIN
        Negocio.TipoRel ON Negocio.DetalleExpensa.idUnidadFuncional = Negocio.TipoRel.idUnidadFuncional
    JOIN
        Negocio.Persona ON Negocio.TipoRel.idPersona = Negocio.Persona.id
    LEFT JOIN
        (
            SELECT
                Operaciones.PagoAplicado.idDetalleExpensa,
                SUM(Operaciones.PagoAplicado.importeAplicado) AS TotalPagado
            FROM
                Operaciones.PagoAplicado
            GROUP BY
                Operaciones.PagoAplicado.idDetalleExpensa
        ) AS PagosAplicados ON Negocio.DetalleExpensa.id = PagosAplicados.idDetalleExpensa

    WHERE
        -- condicion para ver si es el prop actual
        Negocio.TipoRel.descripcion = 'Propietario'
        AND Negocio.TipoRel.fechaFin IS NULL
        -- aplico filtros
        --q sea del mismo consorcio q se indico
        AND (Negocio.Expensa.consorcioId = @idConsorcio OR @idConsorcio IS NULL)
        --q sea menor a la fecha limite
        AND Negocio.Expensa.fechaEmision <= @fechaHasta
        -- q sea mayor a la fecha inicio
        AND (Negocio.Expensa.fechaEmision >= @fechaDesde OR @fechaDesde IS NULL) 

    GROUP BY
        -- agrupo por persona
        Negocio.Persona.id,
        Negocio.Persona.CUIL,
        Negocio.Persona.nombre,
        Negocio.Persona.Apellido,
        Negocio.Persona.emailPersonal,
        Negocio.Persona.telefonoContacto

    HAVING
        -- solo muestro si la deuda existe mayor a cero
        SUM(Negocio.DetalleExpensa.total - ISNULL(PagosAplicados.TotalPagado, 0)) > 0.01

    ORDER BY
        -- ordenamos de mayor a menor para que sea un top 3
        MorosidadTotal DESC;

END;
GO