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
-- ======================================================================================================================

/*
    REPORTE 5:
    Obtenga los 3 (tres) propietarios con mayor morosidad. 
    Presente información de contacto y DNI de los propietarios para que la administración los pueda 
    contactar o remitir el trámite al estudio jurídico.
    CON XML
*/

CREATE OR ALTER PROCEDURE Operaciones.sp_Reporte5_MayoresMorosos_XML
    @idConsorcio INT,
    @fechaDesde  DATE,
    @fechaHasta  DATE = NULL
    --solo admito q la fecha limite venga vacia
AS
BEGIN
    SET NOCOUNT ON;
    IF @fechaHasta IS NULL SET @fechaHasta = CAST(GETDATE() AS DATE);

    WITH DeudaPorDetalle AS 
    (
        SELECT 
            de.expensaId,
            de.idUnidadFuncional,
            de.primerVencimiento,
            CASE 
                WHEN de.totalaPagar - ISNULL(de.pagosRecibidos,0) > 0 
                THEN de.totalaPagar - ISNULL(de.pagosRecibidos,0)
                ELSE 0 
            END AS Deuda
        FROM Negocio.DetalleExpensa AS de
        WHERE (@fechaDesde IS NULL OR de.primerVencimiento >= @fechaDesde)
          AND (@fechaHasta IS NULL OR de.primerVencimiento <= @fechaHasta)
    ),
    DeudaPorPersona AS 
    (
        SELECT
            p.dni,
            p.nombre,
            p.apellido,
            p.email,
            p.telefono,
            SUM(d.Deuda) AS MorosidadTotal
        FROM DeudaPorDetalle d
        INNER JOIN Consorcio.UnidadFuncional uf ON uf.id = d.idUnidadFuncional
        INNER JOIN Negocio.Expensa e            ON e.id = d.expensaId
        INNER JOIN Consorcio.Consorcio c        ON c.id = uf.consorcioId
        -- titular por CBU/CVU registrado en la UF
        INNER JOIN Consorcio.Persona p
            ON (p.cbu = uf.CVU_CBU OR p.cvu = uf.CVU_CBU)
        WHERE (@idConsorcio IS NULL OR c.id = @idConsorcio)
        GROUP BY p.dni, p.nombre, p.apellido, p.email, p.telefono
        HAVING SUM(d.Deuda) > 0.01
    )
    SELECT
        (
            SELECT TOP (3)
                p.dni              AS [@dni],
                p.nombre           AS [nombre],
                p.apellido         AS [apellido],
                p.email            AS [email],
                p.telefono         AS [telefono],
                p.MorosidadTotal   AS [morosidad]
            FROM DeudaPorPersona p
            ORDER BY p.MorosidadTotal DESC
            FOR XML PATH('propietario'), ROOT('mayoresMorosos'), TYPE
        ) AS XML_Reporte5;
END
GO

-- ======================================================================================================================