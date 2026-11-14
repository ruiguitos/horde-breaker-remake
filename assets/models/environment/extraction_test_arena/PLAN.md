# Plano de produção — arena de extração

Pedido de 25 de outubro de 2026. Pasta isolada; sem Godot, integração ou commit.

1. [x] Oito módulos: paredes alta/baixa, contentor, plataforma, rampa,
   pilar, beacon e cais. Aceitação: ≤3000 triângulos, PBR 1K original,
   metros, GLB Y-up, pivô documentado, sem luzes/câmaras.
2. [x] Layout: ilha 256×256, arena central ~80 m, quatro gargantas de
   4 m, três laços fechados com faixa livre de 8 m, coberturas e landmarks.
   Aceitação: coordenadas inteiras, rotações cardinais, sem sobreposição.
3. [x] Auditoria dos GLB e da planta; dois renders a partir das peças
   exportadas. Aceitação: relatórios por módulo, distâncias entre pares,
   larguras dos corredores e limites expressos. Sem testes do jogo.

Convenções: layout em metros desde sudoeste, X leste, Z norte. Rotação
cardinal pela fórmula x'=cos(a)x+sin(a)z, z'=-sin(a)x+cos(a)z. Dimensões
GLB X/Y/Z; plataforma e rampa separadas. O beacon tem um pedestal sólido
sob o tripé. Cais e plataforma têm base fechada em planta.
