CREATE PROCEDURE Negocio.SP_ObtenerTop5MesesGastosIngresos
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