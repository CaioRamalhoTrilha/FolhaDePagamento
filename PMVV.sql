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

08/03/2023 - Caio - Alterei o insert das verbas de servidores do IPVV para forma antiga porque a função de lotação do IPVV estava fazendo uma trativa nas descrições 
originais das lotações, então na hora de fazer a ligação da view com a trLotacaoServidor pela descrição estava ignorando uma parte dos servidores.
***/

SET XACT_ABORT, NOCOUNT ON
GO
begin TRANSACTION	
	declare @mes int set @mes = 1;
	declare @ano int set @ano = 2023;
	declare @executarIPVV int, @executarPMVV int 
	set @executarIPVV = 1
	set @executarPMVV = 1

	if(exists(
		select 1 from trVencimentoServidor 
	inner join trLotacaoServidor on trLotacaoServidor.cd_LotacaoServidor = trVencimentoServidor.cd_LotacaoServidor and trLotacaoServidor.Ativo = 1
	where 
		trVencimentoServidor.Ativo = 1 and 
		mes = @mes and 
		ano = @ano and
		((@executarIPVV = 1 and trLotacaoServidor.Nome like '%ipvv%') or
		(@executarPMVV = 1 and trLotacaoServidor.Nome not like '%ipvv%'))))
	begin
		raiserror ('Já existem vencimentos inseridos nesse período.', 16, 1);
		return;
	end

	if(@executarPMVV = 1 and exists(select 1 from RHV12100 where mes = @mes and @ano = ano and cpf like '%*%'))
	begin
		raiserror ('O campo CPF está ofuscado (VIEW RHV12100). Deve-se contactar a SMAR para fazer a correção do campo antes de prosseguir com a importação da folha.', 16, 1);
		return;
	end
	
	if(@executarIPVV = 1 and exists(select 1 from RHV12100_IPVV where mes = @mes and @ano = ano and cpf like '%*%'))
	begin
		raiserror ('O campo CPF está ofuscado (VIEW RHV12100_IPVV). Deve-se contactar a SMAR para fazer a correção do campo antes de prosseguir com a importação da folha.', 16, 1);
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

	
	if(@executarIPVV = 1)
	begin
		exec ImportaTransparenciaPMVV_IPVV @ano, @mes
		print 'Folha IPVV: ' + convert(varchar(15), @@rowcount) + ' registros.';
	end

	if(@executarPMVV = 1)
	begin
	
		select * into #tempRHV12110 FROM RHV12110 where ano = @ano and mes = @mes
		select * into #tempRHV12100 from RHV12100 where ano = @ano and mes = @mes
		
		update L set L.Descricao_Original = fls.Descr_lotacao
		from trLotacaoServidor L
		inner join funcLotacaoFolha(@ano, @mes) fls on L.cd_LotacaoServidor = fls.cd_LotacaoServidor
		where L.Ativo = 1
				
		insert into trVerbaVencimento(Ativo, Descricao, Tipo, Valor, Quantidade, cd_VencimentoServidor)
		select 
			1 Ativo,	
			case 
				-- RH de PMVV pediu pra quando for uma verba complementar e entrar como vencimento, deve ser marcada como complementar na descrição
				when vVerbas.TipoFolha = rtrim(ltrim('Complementar')) and vVerbas.nomesaida = rtrim(ltrim('Vencimento')) then rtrim(ltrim(vVerbas.desnorverba)) + ' (COMPLEM)'
				else rtrim(ltrim(vVerbas.desnorverba))
			end,
			case nomesaida
				when 'Vencimento' then 'V'
				when 'Desconto' then 'D'
				when 'Liquido' then 'L'
			end,
			vVerbas.valorverba,
			vVerbas.qtdeverba,
			vs.cd_VencimentoServidor
		from 
			#tempRHV12110 vVerbas
		inner join #tempRHV12100 vVenc on vVenc.idfunselec = vVerbas.idfunselec 
		inner join trServidor s on s.Matricula = vVenc.MatriCon and s.Ativo = 1
		inner join trLotacaoServidor L on vVenc.Descr_Lotacao = L.Descricao_Original and L.Ativo = 1
		inner join trCargoServidor c on c.Nome = vVenc.Descr_Cargo and c.Ativo = 1
		inner join trVencimentoServidor vs on 
			vs.cd_Servidor = s.cd_servidor and 
			vs.ano = vVenc.ano and 
			vs.mes = vVenc.mes and 
			vs.cd_CargoServidor = c.cd_CargoServidor and 
			vs.cd_LotacaoServidor = l.cd_LotacaoServidor and 
			vs.Ativo = 1
		where
			vVenc.ano = @ano and
			vVenc.mes = @mes and
			not exists (
				select 1 from trVerbaVencimento vv 
				where  
					vv.Descricao = vVerbas.desnorverba and 
					vv.cd_VencimentoServidor = vs.cd_VencimentoServidor and 
					vv.Ativo = 1
				)
		print 'Verbas Prefeitura: ' + convert(varchar(15), @@rowcount) + ' registros.';
		
		drop table #tempRHV12110
		drop table #tempRHV12100
	end

	if(@executarIPVV = 1)
	begin
	insert into RHV12110_IPVVtemp
			select *			
			from RHV12110_IPVV
			where mes = @mes
				and ano = @ano
				
		select * into #tempRHV12100_IPVV from RHV12100_IPVV where ano = @ano and mes = @mes
		
		-- update L set L.Descricao_Original = fls.Descr_lotacao
		-- from trLotacaoServidor L
		-- inner join funcLotacaoFolha_IPVV(@ano, @mes) fls on L.cd_LotacaoServidor = fls.cd_LotacaoServidor
		-- where L.Ativo = 1

		insert into trVerbaVencimento(Ativo, Descricao, Tipo, Valor, Quantidade, cd_VencimentoServidor)
		select distinct
			1 Ativo,	
			case 
				-- RH de PMVV pediu pra quando for uma verba complementar e entrar como vencimento, deve ser marcada como complementar na descrição
				when vVerbas.TipoFolha = rtrim(ltrim('Complementar')) and vVerbas.nomesaida = rtrim(ltrim('Vencimento')) then rtrim(ltrim(vVerbas.desnorverba)) + ' (COMPLEM)'
				else rtrim(ltrim(vVerbas.desnorverba))
			end,
			case nomesaida
				when 'Vencimentos' then 'V'
				when 'Descontos' then 'D'
				when 'Liquido' then 'L'			
			end,
			vVerbas.valorverba,
			vVerbas.qtdeverba,
			vs.cd_VencimentoServidor
		from 
			RHV12110_IPVVtemp vVerbas
		inner join #tempRHV12100_IPVV vVenc on vVenc.idfunselec = vVerbas.idfunselec 
		inner join trServidor s on s.Matricula = vVenc.MatriCon and s.Ativo = 1
		inner join trVencimentoServidor vs on vs.cd_Servidor = s.cd_servidor and vs.ano = vVenc.ano and vs.mes = vVenc.mes and vs.Ativo = 1
		inner join trLotacaoServidor ls on ls.cd_LotacaoServidor = vs.cd_LotacaoServidor and ls.Ativo = 1 -- and ls.Nome = (vVenc.Descr_Secretaria + '.' + LTRIM(RTRIM(SUBSTRING(vVenc.Descr_Lotacao, CHARINDEX('-', vVenc.Descr_lotacao) + 1, LEN(vVenc.Descr_Lotacao)))))
		where
			vVenc.ano = @ano and
			vVenc.mes = @mes and
			not exists (
				select 1 from trVerbaVencimento vv 
				where  
					vv.Descricao = vVerbas.desnorverba and 
					vv.cd_VencimentoServidor = vs.cd_VencimentoServidor and 
					vv.Ativo = 1
				)
		print 'Verbas IPVV: ' + convert(varchar(15), @@rowcount) + ' registros.';
		drop table #tempRHV12100_IPVV
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
		SELECT DISTINCT Isnull(v.Enquadramento_Salarial_Desc, ''),  
		                1 
		FROM   (select distinct Enquadramento_Salarial_Desc from smarapd.dbo.RHV12100 with (nolock)) v
		WHERE  NOT EXISTS (SELECT 1 
		                   FROM   trEstruturaSalario es 
		                   WHERE  es.PlanoCargos = Isnull(v.Enquadramento_Salarial_Desc, '') and es.Ativo = 1) 

		update vs
			set 
				cd_EstruturaSalario = trEstruturaSalario.cd_EstruturaSalario,
				CargaHoraria = vVenc.horaMencont,
				SituacaoFuncional = vVenc.Situacao_Funcional 
		from  RHV12100 vVenc 
		inner join trServidor s on s.Matricula = vVenc.MatriCon and s.Ativo = 1
		inner join trVencimentoServidor vs on vs.cd_Servidor = s.cd_servidor and vs.ano = vVenc.ano and vs.mes = vVenc.mes and vs.Ativo = 1
		left join trEstruturaSalario on vVenc.Enquadramento_Salarial_Desc = trEstruturaSalario.PlanoCargos and trEstruturaSalario.Ativo = 1
		where
			vVenc.ano = @ano and vVenc.mes = @mes
									
	end

	if(@executarIPVV = 1)
	begin
		INSERT INTO trEstruturaSalario (PlanoCargos,  ativo) 
		SELECT DISTINCT 
			isnull(v.Enquadramento_Salarial_Desc, ''),  
			1 as Ativo
		FROM (select distinct Enquadramento_Salarial_Desc from [RHV12100_IPVV] with (nolock)) v
		WHERE  NOT EXISTS (SELECT 1 
		                   FROM   trEstruturaSalario es 
		                   WHERE  es.PlanoCargos = Isnull(v.Enquadramento_Salarial_Desc, '') and es.Ativo = 1) 
		
		update vs
			set 
				cd_EstruturaSalario = trEstruturaSalario.cd_EstruturaSalario,
				SituacaoFuncional = vVenc.Situacao_Funcional, 
				CargaHoraria = vVenc.horaMencont
		from  RHV12100_IPVV vVenc 
		inner join trServidor s on s.Matricula = vVenc.MatriCon and s.Ativo = 1
		inner join trVencimentoServidor vs on vs.cd_Servidor = s.cd_servidor and vs.ano = vVenc.ano and vs.mes = vVenc.mes and vs.Ativo = 1
		left join trEstruturaSalario on vVenc.Enquadramento_Salarial_Desc = trEstruturaSalario.PlanoCargos and trEstruturaSalario.Ativo = 1
		where
			vVenc.ano = @ano and vVenc.mes = @mes
	end


	update ConfiguracaoMunicipio set DataAtualizacaoPessoal = GETDATE()
	
commit TRANSACTION;
GO  
SET XACT_ABORT, NOCOUNT OFF