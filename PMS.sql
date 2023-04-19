/****

		EXECUÇÃO DA FOLHA DA PMS

	APENAS ALTERE AS VARIÁVEIS ABAIXO E EXECUTE

***/

SET XACT_ABORT, NOCOUNT ON
GO
begin TRANSACTION
print 'Início:' + convert(varchar(max), getdate())

declare @mes int set @mes = 6
declare @ano int set @ano = 2021

if(exists(
		select 1 from trVencimentoServidor 
	inner join trLotacaoServidor on trLotacaoServidor.cd_LotacaoServidor = trVencimentoServidor.cd_LotacaoServidor and trLotacaoServidor.Ativo = 1
	where 
		trVencimentoServidor.Ativo = 1 and 
		mes = @mes and 
		ano = @ano))
	begin
		raiserror ('Já existem vencimentos inseridos nesse período.', 16, 1);
		return;
	end

	print 'Salvar os prints abaixo no chamado em caso de necessidade futura: ';
	
	declare @max int set @max = (select max(cd_VencimentoServidor) from trVencimentoServidor);
	print 'Max cd_VencimentoServidor: ' + convert(varchar(15), @max);


	delete from VIEWRH where mes = @mes and ano = @ano
	print 'Deletado ' + convert(varchar(15), @@rowcount) + ' registros na VIEWRH.';

	insert into VIEWRH select * from vmsrv53.[prd_vetorh].[dbo].[usu_vportal2021] where mes = @mes and ano = @ano 	
	print 'Adicionado ' + convert(varchar(15), @@rowcount) + ' registros na VIEWRH.';

	exec ImportaTransparenciaPMS @ano, @mes

	print 'Adicionado ' + convert(varchar(15), @@rowcount) + ' registros na trVencimentoServidor.';
	
	exec dbo.VerbasAdicionaisPMS @mes, @ano;  

	print 'Adicionado ' + convert(varchar(15), @@rowcount) + ' registros na trVerbaVencimento.';
	
	print 'Fim: ' + convert(varchar(max), getdate())

	commit TRANSACTION;
GO  
SET XACT_ABORT, NOCOUNT OFF

/*
Início:Jul  1 2021 11:45AM
Salvar os prints abaixo no chamado em caso de necessidade futura: 
Max cd_VencimentoServidor: 1680932
Deletado 0 registros na VIEWRH.
Adicionado 9870 registros na VIEWRH.
Warning: Null value is eliminated by an aggregate or other SET operation.
Warning: Null value is eliminated by an aggregate or other SET operation.
Adicionado 9870 registros na trVencimentoServidor.
Adicionado 9870 registros na trVerbaVencimento.
Fim: Jul  1 2021 11:46AM

Horário de conclusão: 2021-07-01T11:46:34.5135145-03:00

*/