-- =============================================

-- 1
IF OBJECT_ID('sp_analizar_flujo_egresos_semanal', 'P') IS NOT NULL
    DROP PROCEDURE sp_analizar_flujo_egresos_semanal;
GO

CREATE PROCEDURE sp_analizar_flujo_egresos_semanal
AS
BEGIN
    SET NOCOUNT ON;-- no cuentas las filas afectadas

    -- estos son CTE concatenados
    WITH EgresosCombinados AS ( -- primer CTE
        --  Ordinarios
        SELECT
            fechaEmision,
            importeTotal AS Gasto_Ordinario,
            0.00 AS Gasto_Extraordinario,
            importeTotal AS Gasto_Total
        FROM Negocio.GastoOrdinario
        
        UNION ALL
        
        --  extraordinarios
        SELECT
            fechaEmision,
            0.00 AS Gasto_Ordinario,
            importeTotal AS Gasto_Extraordinario,
            importeTotal AS Gasto_Total
        FROM Negocio.GastoExtraordinario
    ),
    EgresosSemanal AS ( -- otro CTE
        -- Agrupar los egresos por semana
        SELECT
            YEAR(fechaEmision) AS Año,-- agregue estos campos para que sea mas descriptivo
            Month(fechaEmision) AS mes, -- agregue estos campos para que sea mas descriptivo
            DATEPART(wk, fechaEmision) AS Semana,
            SUM(Gasto_Ordinario) AS Gasto_Ordinario_Semanal,
            SUM(Gasto_Extraordinario) AS Gasto_Extraordinario_Semanal,
            SUM(Gasto_Total) AS Gasto_Semanal_Total
        FROM EgresosCombinados
        GROUP BY YEAR(fechaEmision), Month(fechaEmision), DATEPART(wk, fechaEmision)
    )
    SELECT
        ES.Año,
        ES.mes,
        ES.Semana,

        -- segun buesque se puede mostrar como N(numero) 2 (digitos decimales)
        FORMAT(ES.Gasto_Ordinario_Semanal, 'N2') AS Egreso_Ordinario,
        FORMAT(ES.Gasto_Extraordinario_Semanal, 'N2') AS Egreso_Extraordinario,
        FORMAT(ES.Gasto_Semanal_Total, 'N2') AS Egreso_Semanal_Total,
        
        -- Acumulado Progresivo (Total de egresos hasta la semana actual)
        FORMAT(SUM(ES.Gasto_Semanal_Total) OVER (
            ORDER BY ES.Año, ES.Semana
            -- toma el valor de la fila actual y le suma todos los valores de las filas anteriores
            ROWS UNBOUNDED PRECEDING

        ), 'N2') AS Acumulado_Progresivo,
        
        -- Promedio en el Periodo (El promedio simple de todos los egresos semanales)
        FORMAT(AVG(ES.Gasto_Semanal_Total) OVER (), 'N2') AS Promedio_Periodo
        
    FROM EgresosSemanal AS ES
    ORDER BY ES.Año, ES.Semana;
END
GO

-- 4
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

EXEC Negocio.SP_ObtenerTop5MesesGastosIngresos;
GO
-- =============================================

