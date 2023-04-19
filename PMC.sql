  SET XACT_ABORT ON
GO
begin TRANSACTION
print 'inicio:' + convert(varchar(max), getdate())
 
declare @mes int set @mes = 6
declare @ano int set @ano = 2021
 
if(exists(select 1 from RHV11300 where mes = @mes and @ano = ano and cpf like '%*%'))
begin
    raiserror ('O campo CPF está ofuscado (VIEW RHV12100). Deve-se contactar o TI para fazer a correção do campo antes de prosseguir com a importação da folha.', 16, 1);
    return;
end
 
exec ImportaTransparenciaPMC @ano, @mes
exec [ImportaVerbasPMC] @ano, @mes
print 'fim:' + convert(varchar(max), getdate())
commit TRANSACTION;
GO  
SET XACT_ABORT OFF