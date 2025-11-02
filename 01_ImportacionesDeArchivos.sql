/*Base de datos aplicadas
Com:3641
Fecha de entrega: 7/11
Grupo 11

Miembros:
Hidalgo, Eduardo - 41173099
Quispe, Milagros Soledad - 45064110
Puma, Florencia - 42945609
Fontanet Caniza, Camila - 44892126
Altamiranda, Isaias Taiel - 43094671
Pastori, Ximena - 42300128*/


-- servicios.servicios.json

 INSERT INTO multas (ID_Multa, Patente, Velocidad)
 SELECT ID_Multa, Patente, Velocidad
 FROM OPENROWSET (BULK 'C:\Importar\infomultas.json', SINGLE_CLOB) as j
 CROSS APPLY OPENJSON(BulkColumn)
 WITH (
 ID_Multa INT '$.ID_Multa',
 Patente NVARCHAR(50) '$.Patente',
 Velocidad INT '$.Velocidad'
 );
 GO


