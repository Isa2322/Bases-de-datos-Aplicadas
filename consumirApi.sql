USE Com5600G11;
GO

-- HABILITAR OLE AUTOMATION (solo si no está activado)
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Ole Automation Procedures', 1;
RECONFIGURE;
GO


IF OBJECT_ID('Operaciones.sp_EnviarCorreoSendGrid', 'P') IS NOT NULL
    DROP PROCEDURE Operaciones.sp_EnviarCorreoSendGrid;
GO

CREATE PROCEDURE Operaciones.sp_EnviarCorreoSendGrid
    @DESTINATARIO_EMAIL NVARCHAR(200)     
AS
BEGIN
    
    DECLARE 
        @url NVARCHAR(256) = N'https://api.sendgrid.com/v3/mail/send',
        @API_KEY NVARCHAR(400) = N'API_KEY',
        @AuthorizationHeader NVARCHAR(512),
        @REMITENTE_EMAIL NVARCHAR(100) = N'msquispeuni@gmail.com',
        @REMITENTE_NOMBRE NVARCHAR(100) = N'Sistema de Expensas',
        @ASUNTO NVARCHAR(200) = N'Factura de Expensas Lista',
        @CUERPO_HTML NVARCHAR(MAX) = 
            N'<h1>Estimado Propietario,</h1><p>Soy miliiiiiiiiii. Haga clic <a href="http://link.a.su.factura">aquí</a>.</p>';

    -- CONSTRUCCIÓN DEL JSON
    DECLARE @SAFE_CUERPO_HTML NVARCHAR(MAX) = REPLACE(@CUERPO_HTML, '"', '\"');

    DECLARE @PAYLOAD NVARCHAR(MAX) = 
    N'{
      "personalizations": [{
        "to": [{"email": "' + @DESTINATARIO_EMAIL + N'"}],
        "subject": "' + @ASUNTO + N'"
      }],
      "from": {
        "email": "' + @REMITENTE_EMAIL + N'",
        "name": "' + @REMITENTE_NOMBRE + N'"
      },
      "content": [{
        "type": "text/html",
        "value": "' + @SAFE_CUERPO_HTML + N'"
      }]
    }';

    PRINT N'===== JSON A ENVIAR =====';
    PRINT @PAYLOAD;


    -- LLAMADA A LA API SENDGRID
    DECLARE 
        @Object INT,
        @Status INT,
        @StatusText NVARCHAR(200),
        @ResponseText NVARCHAR(MAX);

    SET @AuthorizationHeader = N'Bearer ' + @API_KEY;

    EXEC sp_OACreate 'MSXML2.XMLHTTP', @Object OUT;

    EXEC sp_OAMethod @Object, 'open', NULL, 'POST', @url, 'false';
    EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'Authorization', @AuthorizationHeader;
    EXEC sp_OAMethod @Object, 'setRequestHeader', NULL, 'Content-Type', 'application/json';

    -- Enviar el cuerpo JSON
    EXEC sp_OAMethod @Object, 'send', NULL, @PAYLOAD;

    -- Obtener código de estado y texto
    EXEC sp_OAGetProperty @Object, 'status', @Status OUT;
    EXEC sp_OAGetProperty @Object, 'statusText', @StatusText OUT;
    EXEC sp_OAGetProperty @Object, 'responseText', @ResponseText OUT;

    -- Destruir objeto
    EXEC sp_OADestroy @Object;

    -- RESULTADOS
    PRINT N'===== RESPUESTA DE LA API =====';
    PRINT N'Código HTTP: ' + CAST(@Status AS NVARCHAR(10));
    PRINT N'StatusText: ' + ISNULL(@StatusText, N'(sin texto)');
    PRINT N'ResponseText: ' + ISNULL(@ResponseText, N'(vacío)');

    -- Mostrar resultado legible
    SELECT 
        Codigo_HTTP = @Status,
        Estado = @StatusText,
        Respuesta = @ResponseText;


    -- INTERPRETACIÓN DEL RESULTADO

    IF @Status = 202
        PRINT N'ÉXITO: El correo fue aceptado por SendGrid.';
    ELSE
        PRINT N'ERROR: La API devolvió un código distinto de 202. Revisá la respuesta.';
end
GO


DECLARE @correo NVARCHAR(200)= N'DES@gmail.com';

EXEC Operaciones.sp_EnviarCorreoSendGrid @DESTINATARIO_EMAIL = @correo;

