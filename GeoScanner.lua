-- =======================================================
-- BUSCA DE PERIFÉRICOS
-- =======================================================
local mon = peripheral.find("monitor")
local geo = peripheral.find("geoScanner") or peripheral.wrap("top")

if not mon then
    print("Erro: Monitor não encontrado!")
    return
end
if not geo then
    print("Erro: Geo Scanner não encontrado! Coloque-o no topo ou ao lado.")
    return
end

-- =======================================================
-- VARIÁVEIS DE ESTADO (CONFIGURAÇÕES DO JOGO)
-- =======================================================
local cfg = {
    raio = 8,
    escala = 1.0,
    pagina = 1
}

local minerios = {}
local rodando = true

-- =======================================================
-- FUNÇÕES AUXILIARES
-- =======================================================
-- Calcula a distância para ordenar do mais perto ao mais longe
local function calcularDistancia(x, y, z)
    return math.sqrt(x^2 + y^2 + z^2)
end

-- Associa cores aos minérios
local function obterCor(nome)
    if string.find(nome, "DIAMOND") then return colors.cyan end
    if string.find(nome, "GOLD") then return colors.yellow end
    if string.find(nome, "IRON") then return colors.lightGray end
    if string.find(nome, "REDSTONE") then return colors.red end
    if string.find(nome, "EMERALD") then return colors.lime end
    if string.find(nome, "LAPIS") then return colors.blue end
    if string.find(nome, "COAL") then return colors.gray end
    if string.find(nome, "COPPER") then return colors.orange end
    return colors.white
end

-- Realiza o escaneamento
local function escanear()
    minerios = {}
    local blocos = geo.scan(cfg.raio)
    
    if blocos then
        for _, b in ipairs(blocos) do
            if string.find(b.name, "ore") then
                local nome = string.gsub(b.name, "minecraft:", "")
                nome = string.gsub(nome, "forge:", "")
                nome = string.gsub(nome, "_ore", "")
                nome = string.upper(nome)
                
                local dist = calcularDistancia(b.x, b.y, b.z)
                table.insert(minerios, {nome=nome, x=b.x, y=b.y, z=b.z, dist=dist, cor=obterCor(nome)})
            end
        end
        -- Ordena a tabela pela distância (mais próximos primeiro)
        table.sort(minerios, function(a, b) return a.dist < b.dist end)
    end
    cfg.pagina = 1 -- Reseta para a primeira página após escanear
end

-- =======================================================
-- RENDERIZAÇÃO DA UI (INTERFACE GRÁFICA)
-- =======================================================
local function desenharTela()
    mon.setTextScale(cfg.escala)
    local larg, alt = mon.getSize()
    
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- 1. BARRA SUPERIOR (BOTÕES DE CONFIGURAÇÃO)
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.blue)
    mon.setTextColor(colors.white)
    mon.write(string.rep(" ", larg)) -- Preenche o fundo
    
    mon.setCursorPos(1, 1)
    -- Os botões estão em posições fixas para podermos clicar neles depois
    local texto_raio = string.format("%02d", cfg.raio)
    local texto_zoom = string.format("%.1f", cfg.escala)
    mon.write("[SCAN]  Raio:[-] " .. texto_raio .. " [+]  Zoom:[-] " .. texto_zoom .. " [+]")
    
    -- 2. LISTA DE MINÉRIOS (PÁGINAS)
    local max_linhas = alt - 3 -- Espaço tirando cabeçalho e rodapé
    local max_paginas = math.ceil(#minerios / max_linhas)
    if max_paginas == 0 then max_paginas = 1 end
    
    if #minerios == 0 then
        mon.setBackgroundColor(colors.black)
        mon.setTextColor(colors.red)
        mon.setCursorPos(2, 3)
        mon.write("Nenhum minério encontrado ou scanner em recarga.")
    else
        local inicio = (cfg.pagina - 1) * max_linhas + 1
        local fim = math.min(inicio + max_linhas - 1, #minerios)
        
        local linha_atual = 3
        for i = inicio, fim do
            local m = minerios[i]
            mon.setBackgroundColor(colors.black)
            
            -- Pinta o nome do minério
            mon.setCursorPos(1, linha_atual)
            mon.setTextColor(m.cor)
            mon.write("• " .. m.nome)
            
            -- Pinta as coordenadas
            mon.setTextColor(colors.lightGray)
            mon.write(string.format(" (X:%d Y:%d Z:%d)", m.x, m.y, m.z))
            
            linha_atual = linha_atual + 1
        end
    end
    
    -- 3. BARRA INFERIOR (PAGINAÇÃO)
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.white)
    mon.setCursorPos(1, alt)
    mon.write(string.rep(" ", larg))
    
    local txt_pag = "[<] PÁGINA " .. cfg.pagina .. " DE " .. max_paginas .. " [>]"
    local meio = math.floor((larg - string.len(txt_pag)) / 2)
    if meio < 1 then meio = 1 end
    mon.setCursorPos(meio, alt)
    mon.write(txt_pag)
end

-- =======================================================
-- GERENCIADOR DE CLIQUES (TOUCH)
-- =======================================================
local function loopInterface()
    escanear()
    desenharTela()
    
    while rodando do
        -- Espera alguém clicar no monitor
        local evento, lado, x, y = os.pullEvent("monitor_touch")
        local larg, alt = mon.getSize()
        local max_linhas = alt - 3
        local max_paginas = math.ceil(#minerios / max_linhas)
        if max_paginas == 0 then max_paginas = 1 end
        
        -- Clicou na Barra Superior (Linha 1)
        if y == 1 then
            if x >= 1 and x <= 6 then
                -- Clicou em [SCAN]
                escanear()
            elseif x >= 15 and x <= 17 then
                -- Clicou em Raio [-]
                if cfg.raio > 1 then cfg.raio = cfg.raio - 1 end
            elseif x >= 22 and x <= 24 then
                -- Clicou em Raio [+]
                if cfg.raio < 16 then cfg.raio = cfg.raio + 1 end
            elseif x >= 33 and x <= 35 then
                -- Clicou em Zoom [-]
                if cfg.escala > 0.5 then cfg.escala = cfg.escala - 0.5 end
            elseif x >= 40 and x <= 42 then
                -- Clicou em Zoom [+]
                if cfg.escala < 3.0 then cfg.escala = cfg.escala + 0.5 end
            end
        end
        
        -- Clicou na Barra Inferior (Última Linha)
        if y == alt then
            if x < (larg / 2) then
                -- Metade esquerda (Página Anterior)
                if cfg.pagina > 1 then cfg.pagina = cfg.pagina - 1 end
            else
                -- Metade direita (Próxima Página)
                if cfg.pagina < max_paginas then cfg.pagina = cfg.pagina + 1 end
            end
        end
        
        desenharTela()
    end
end

-- =======================================================
-- FINALIZAÇÃO SEGURA
-- =======================================================
-- Permite fechar o programa apertando Q no computador (para não travar)
local function loopSaida()
    while rodando do
        local evento, tecla = os.pullEvent("key")
        if tecla == keys.q then
            rodando = false
            print("Radar desligado com sucesso.")
            mon.clear()
        end
    end
end

print("📡 Radar Iniciado no Monitor!")
print("Pressione 'Q' neste terminal para desligar.")
-- Roda a interface e o botão de saída ao mesmo tempo
parallel.waitForAny(loopSaida, loopInterface)
