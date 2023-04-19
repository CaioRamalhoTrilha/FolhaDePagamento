/****

		EXECUÇÃO DA FOLHA DA PMVV + IPVV

	APENAS ALTERE AS VARIÁVEIS ABAIXO E EXECUTE

***/

/****
--VER QUESTÂO DOS QUADROS PENSIONISTAS/APOSENTADOS:
update trVencimentoServidor set CargaHoraria = null
 from trVencimentoServidor 
inner join  trQuadroServidor on trVencimentoServidor .cd_QuadroServidor = trQuadroServidor.cd_QuadroServidor
where RTRIM(trQuadroServidor.Nome) in ('Pensao', 'Aposentadoria', 'Pensao Vitalícia', 'Inat/Pens Moléstia Grave')
***/

SET XACT_ABORT, NOCOUNT ON
GO
begin TRANSACTION	
	declare @mes int set @mes = 3;
	declare @ano int set @ano = 2022;
	declare @executarPMVV int 
	set @executarPMVV = 1

	if(exists(
		select 1 from trVencimentoServidor 
	inner join trLotacaoServidor on trLotacaoServidor.cd_LotacaoServidor = trVencimentoServidor.cd_LotacaoServidor and trLotacaoServidor.Ativo = 1
	where 
		trVencimentoServidor.Ativo = 1 and 
		mes = @mes and 
		ano = @ano and
		((@executarPMVV = 1 and trLotacaoServidor.Nome not like '%ipvv%'))))
	begin
		raiserror ('Já existem vencimentos inseridos nesse período.', 16, 1);
		return;
	end

	if(@executarPMVV = 1 and exists(select 1 from RHV12100 where mes = @mes and @ano = ano and cpf like '%*%'))
	begin
		raiserror ('O campo CPF está ofuscado (VIEW RHV12100). Deve-se contactar a SMAR para fazer a correção do campo antes de prosseguir com a importação da folha.', 16, 1);
		return;
	end
	
	print 'Salvar os prints abaixo no chamado em caso de necessidade futura: ';

	print '----------MAX IDS-----------';
	declare @max int set @max = (select max(cd_VencimentoServidor) from trVencimentoServidor);
	print 'cd_VencimentoServidor       ' + convert(varchar(15), @max);

	set @max = (select max(cd_VerbaVencimento) from trVerbaVencimento);
	print 'cd_VerbaVencimento:         ' + convert(varchar(15), @max);

	set @max = (select max(cd_VencimentoServidor) from trVencimentoServidorBKP);
	print 'cd_VencimentoServidorBKP:   ' + convert(varchar(15), @max);

	set @max = (select max(cd_VerbaVencimento) from trVerbaVencimentoBKP);
	print 'cd_VerbaVencimentoBKP:      ' + convert(varchar(15), @max);

	print '----------------------------';
	print '------------BCKP------------';
	insert into trvencimentoservidorbkp 
	select * from trvencimentoservidor 
	where cd_vencimentoservidor not in ( select cd_vencimentoservidor from trvencimentoservidorbkp)
	print 'Salvo ' + convert(varchar(15), @@rowcount) + ' Vencimentos.';
	
	insert into trVerbaVencimentoBKP 
	select * from trVerbaVencimento 
	where cd_VerbaVencimento not in ( select cd_VerbaVencimento from trVerbaVencimentoBKP)
	print 'Salvo ' + convert(varchar(15), @@rowcount) + ' Verbas.';

	print '----INÍCIO DA IMPORTAÇÂO----';

	if(@executarPMVV = 1)
	begin
		exec ImportaTransparenciaPMVV @ano, @mes
		print 'Folha Prefeitura: ' + convert(varchar(15), @@rowcount) + ' registros.';
	end

	
	if(@executarPMVV = 1)
	begin
		insert into trVerbaVencimento(Ativo, Descricao, Tipo, Valor, Quantidade, cd_VencimentoServidor)
		select 
			1 Ativo,	
			rtrim(ltrim(vVerbas.desnorverba)),
			case nomesaida
				when 'Vencimento' then 'V'
				when 'Desconto' then 'D'
				when 'Liquido' then 'L'
			end,
			vVerbas.valorverba,
			vVerbas.qtdeverba,
			vs.cd_VencimentoServidor
		from 
			RHV12110 vVerbas
		inner join RHV12100 vVenc on vVenc.idfunselec = vVerbas.idfunselec 
		inner join trServidor s on s.Matricula = vVenc.MatriCon and s.Ativo = 1
		inner join trVencimentoServidor vs on vs.cd_Servidor = s.cd_servidor and vs.ano = vVenc.ano and vs.mes = vVenc.mes and vs.Ativo = 1
		where
			vVenc.ano = @ano and
			vVenc.mes = @mes and
			vVerbas.nomesaida != 'Outras Remunerações' and
			vVerbas.nomesaida != 'Outros Descontos' and 
			not exists (
				select 1 from trVerbaVencimento vv 
				where  
					vv.Descricao = vVerbas.desnorverba and 
					vv.cd_VencimentoServidor = vs.cd_VencimentoServidor and 
					vv.Ativo = 1
				)
		print 'Verbas Prefeitura: ' + convert(varchar(15), @@rowcount) + ' registros.';
	end

	if(@executarPMVV = 1)
	begin
		insert into trVerbaVencimento(Ativo, Descricao, Tipo, Valor, Quantidade, cd_VencimentoServidor)
		select 
			1 Ativo,	
			'Outras Remunerações',
			'V',
			SUM(vVerbas.valorverba),
			COUNT(vVerbas.qtdeverba),
			vs.cd_VencimentoServidor
		from 
			RHV12110 vVerbas
		inner join RHV12100 vVenc on vVenc.idfunselec = vVerbas.idfunselec 
		inner join trServidor s on s.Matricula = vVenc.MatriCon and s.Ativo = 1
		inner join trVencimentoServidor vs on vs.cd_Servidor = s.cd_servidor and vs.ano = vVenc.ano and vs.mes = vVenc.mes and vs.Ativo = 1
		where
			vVenc.ano = @ano and
			vVenc.mes = @mes and
			vVerbas.nomesaida = 'Outras Remunerações' and
			not exists (
				select 1 from trVerbaVencimento vv 
				where  
					vv.Descricao = vVerbas.desnorverba and 
					vv.cd_VencimentoServidor = vs.cd_VencimentoServidor and 
					vv.Ativo = 1
				)
		group by vs.cd_VencimentoServidor
		
		print 'Verbas Prefeitura "Outras Remunerações": ' + convert(varchar(15), @@rowcount) + ' registros.';
	end

	if(@executarPMVV = 1)
	begin
		insert into trVerbaVencimento(Ativo, Descricao, Tipo, Valor, Quantidade, cd_VencimentoServidor)
		select 
			1 Ativo,	
			'Outros Descontos',
			'D',
			SUM(vVerbas.valorverba),
			COUNT(vVerbas.qtdeverba),
			vs.cd_VencimentoServidor
		from 
			RHV12110 vVerbas
		inner join RHV12100 vVenc on vVenc.idfunselec = vVerbas.idfunselec 
		inner join trServidor s on s.Matricula = vVenc.MatriCon and s.Ativo = 1
		inner join trVencimentoServidor vs on vs.cd_Servidor = s.cd_servidor and vs.ano = vVenc.ano and vs.mes = vVenc.mes and vs.Ativo = 1
		where
			vVenc.ano = @ano and
			vVenc.mes = @mes and
			vVerbas.nomesaida = 'Outros Descontos' and
			not exists (
				select 1 from trVerbaVencimento vv 
				where  
					vv.Descricao = vVerbas.desnorverba and 
					vv.cd_VencimentoServidor = vs.cd_VencimentoServidor and 
					vv.Ativo = 1
				)
		group by vs.cd_VencimentoServidor
			   		
		print 'Verbas Prefeitura "Outros Descontos": ' + convert(varchar(15), @@rowcount) + ' registros.';
	end


	
	update trVencimentoServidor set VencimentoPadrao = null where Ativo = 1 and mes = @mes and ano = @ano -- O vencimento se encontra junto às demais verbas inseridas
	update trVencimentoServidor
	set  
		RemuneracaoBruta = isnull(vencimentos.valor, 0),
		DescontosTotal = isnull(descontos.valor, 0),
		RemuneracaoLiquida = isnull((isnull(vencimentos.valor, 0) - isnull(descontos.valor, 0)), RemuneracaoLiquida)
	from 
		trVencimentoServidor
	cross apply(
		select sum(Valor) valor from trVerbaVencimento where trVerbaVencimento.cd_VencimentoServidor = trVencimentoServidor.cd_VencimentoServidor and Ativo = 1 and Tipo = 'D'
	) descontos
	cross apply(
		select sum(Valor) valor from trVerbaVencimento where trVerbaVencimento.cd_VencimentoServidor = trVencimentoServidor.cd_VencimentoServidor and Ativo = 1 and Tipo = 'V'
	) vencimentos
	where
		Ativo = 1 and
		Mes = @mes and ano = @ano

	--ADICIONAIS

	if(@executarPMVV = 1)
	begin
		INSERT INTO trEstruturaSalario (PlanoCargos,  ativo) 
		SELECT DISTINCT Isnull(v.Enquadramento_Salarial, ''),  
		                1 
		FROM   (select distinct Enquadramento_Salarial from smarapd.dbo.RHV12100 with (nolock)) v
		WHERE  NOT EXISTS (SELECT 1 
		                   FROM   trEstruturaSalario es 
		                   WHERE  es.PlanoCargos = Isnull(v.Enquadramento_Salarial, '') and es.Ativo = 1) 

		update vs
			set 
				cd_EstruturaSalario = trEstruturaSalario.cd_EstruturaSalario,
				CargaHoraria = vVenc.horaMencont,
				SituacaoFuncional = vVenc.Situacao_Funcional 
		from  RHV12100 vVenc 
		inner join trServidor s on s.Matricula = vVenc.MatriCon and s.Ativo = 1
		inner join trVencimentoServidor vs on vs.cd_Servidor = s.cd_servidor and vs.ano = vVenc.ano and vs.mes = vVenc.mes and vs.Ativo = 1
		left join trEstruturaSalario on vVenc.Enquadramento_Salarial = trEstruturaSalario.PlanoCargos and trEstruturaSalario.Ativo = 1
		where
			vVenc.ano = @ano and vVenc.mes = @mes
									
	end



	update ConfiguracaoMunicipio set DataAtualizacaoPessoal = GETDATE()
	
commit TRANSACTION;
GO  
SET XACT_ABORT, NOCOUNT OFF

-- Prints dos resultados da importação estão sendo salvos no sistema de Chamados