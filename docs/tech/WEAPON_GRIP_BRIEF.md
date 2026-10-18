# Pedido ao Codex: pega de cada arma (2026-10-18)

Para colar na janela do Codex. Os números são os do código e foram medidos; o
trabalho é desenhar a pega de cada arma para os braços de primeira pessoa.

## Contrato (não mudar)

- Origem de cada arma = ponto de pega da mão direita (no punho; na espingarda,
  no punho da coronha). Espaço da arma: +Y para cima, frente -Z, em metros
  reais.
- A arma é desenhada a meia escala (`ViewModel.GUN_SCALE` = 0,5). Os braços são
  à escala real. O ponto de apoio da mão esquerda vê-se a `support * 0,5`.
- O repouso da arma no ecrã é `ViewModel.REST` = (0,16; -0,16; -0,40) m.
- Braço esquerdo: dois ossos de 0,30 m. Ombro esquerdo no repouso do braço:
  (-0,22; -0,10; 0,30) m, na mesma origem da arma. Alcance máximo do punho:
  0,6 m (menos 0,5 mm de folga).

## Pontos de apoio da mão esquerda (WeaponModel.SUPPORT_POINTS)

| Arma | Ponto (m, espaço da arma) | Alcance medido |
|---|---|---|
| AR (`rifle`) | (0, 0,077, -0,26) | exato |
| SMG | (0, 0,065, -0,23) | exato |
| Machine Gun | (0, 0,078, -0,31) | exato |
| Marksman | (0, 0,094, -0,31) | 1,5 mm curta |
| Espingarda | (0, 0,012, -0,335) | 1,07 cm curta: fora de alcance |

## O que pedir

1. **Pega da mão direita** para cada arma: onde o punho e a palma fecham no
   ponto de pega (posição e orientação do pulso), sem atravessar o corpo.
2. **Ponto de apoio** da mão esquerda para cada arma, medido na geometria da
   arma (o centro da palma no guarda-mãos, não a ponta).
3. **Espingarda:** o alcance atual não chega ao guarda-mãos. Propor uma de duas
   coisas: (a) um ponto de apoio mais perto que fique no alcance, por exemplo
   no tubo do carregador, com a justificação; ou (b) um braço mais comprido só
   para esta arma. Indicar o que mudaria no modelo dos braços.
4. Para cada arma, indicar o número de triângulos e as malhas alteradas, se
   alguma.

## Não fazer

- Não alterar `ViewModel.REST`, `GUN_SCALE` nem o modelo dos braços sem pedido
  explícito: o Claude integra essas mudanças e testa.
- Não usar texturas de terceiros sem licença registada em `assets/LICENSES.md`.

## Entregar

- Uma tabela com: arma, ponto de pega da mão direita (m), ponto de apoio da
  mão esquerda (m), alcance medido (mm), decisão (ou proposta para a espingarda).
- Os números exatos, para o teste de alcance poder comparar.
