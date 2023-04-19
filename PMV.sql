

--PASSO A PASSO FOLHA VITÓRIA
--use PPAWeb

select max(cd_vencimentoservidor) from trvencimentoservidor -- 1539388
 select max(cd_vencimentoservidor) from trvencimentoservidorbkp -- 1515365
 
   -- Atualiza a tabela de backup com os dados do mês anterior.   
  insert into trvencimentoservidorbkp 
  select * from trvencimentoservidor 
  where cd_vencimentoservidor not in ( select cd_vencimentoservidor from trvencimentoservidorbkp) -- (12066 rows affected)

---- IMPORTAÇÃO DEMAIS MESES -----

/* EXECUTAR A LINHA ABAIXO PARA VERIFICAR AS COLUNAS COM A TABELA TEMPORARIA ANTES DE RODAR A PROCEDURE

---------------------- HOMOLOGAÇÃO ---------------------
-- DADOS FOLHA MENSAL-------
-- NÃO TEM MAIS O [sururu] NA FRENTE EM HOMOLOGAÇÃO
-- exec [rh_prd].RH.P_Tectrilha_portaltransparencia 0 

-- DADOS FOLHA COMPLEMENTAR-------
-- exec [rh_prd].RH.P_Tectrilha_portaltransparencia 2 

----------------------- PRODUÇÃO ---------------------
-- DADOS FOLHA MENSAL-------
-- exec [sururu].[rh_prd].RH.P_Tectrilha_portaltransparencia 0 

-- DADOS FOLHA COMPLEMENTAR-------
-- exec [sururu].[rh_prd].RH.P_Tectrilha_portaltransparencia 2 

--Logo após executar os comandos acima, verificar na ImportaTransparenciaPMV as colunas

*/

/* EXECUTAR APÓS CONFERÊNCIA */
--ImportaTransparenciaPMV --(11945 rows affected)
--ImportaTransparenciaPMVComplementar --(22 rows affected)

------------ 13 IMPORTAÇÃO -----

-- EXECUTAR A LINHA ABAIXO PARA VERIFICAR AS COLUNAS COM A TABELA TEMPORARIA ANTES DE RODAR A PROCEDURE
--exec [sururu].[rh_prd].RH.P_Tectrilha_portaltransparencia 1

/* EXECUTAR APÓS CONFERÊNCIA */
--[ImportaTransparenciaPMV13Salario] --(10492 rows affected)


-- RODAR APÓS A IMPORTAÇÃO PARA DESLIGAMENTO DOS SERVIDORES

--update trServidor set DataDemissao = DtDesligamento
--from sururu.rh_prd.rh.V_Tectrilha_PortalTransparencia_SituacaoFuncional vw
--inner join trServidor on trServidor.Ativo = 1 and trServidor.Matricula =  vw.Matricula

--(35755 linhas afetadas)
