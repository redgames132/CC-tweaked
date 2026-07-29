-- =======================================================
-- ⚙️ SETUP E PERIFÉRICOS
-- =======================================================
local mon = peripheral.find("monitor")
local geo = peripheral.find("geoScanner") or peripheral.wrap("top")

if not mon then print("❌ Erro: Monitor não encontrado!") return end
if not geo then print("❌ Erro: Geo Scanner não encontrado!") return end

-- =======================================================
-- 📊 ESTADO DO SISTEMA
-- =======================================================
local cfg = { raio = 8, escala = 1.0, pagina = 1 }
local minerios = {}
local rodando = true

-- =======================================================
-- 🎨 UTILITÁRIOS DE TELA E DADOS
-- =======================================================
local function calcularDistancia(x, y, z)
    return math.floor(math.sqrt(x^2 + y^2 + z^2))
end

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

local function centralizar(y, texto, corTexto, corFundo)
    local larg, _ = mon.getSize()
    local x = math.floor((larg - #texto) / 2) + 1
    if x < 1 then x = 1 end
    mon.setCursorPos(x, y)
    mon.setTextColor(corTexto or colors.white)
    if corFundo then mon.setBackgroundColor(corFundo) end
    mon.write(texto)
end

-- =======================================================
-- 📡 LÓGICA DO SCANNER
-- =======================================================
local function telaCarregamento()
    local larg, alt = mon.getSize()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- Borda decorativa
    mon.setCursorPos(1,1)
    mon.setBackgroundColor(colors.blue)
    mon.write(string.rep(" ", larg))
    mon.setCursorPos(1, alt)
    mon.write(string.rep(" ", larg))
    
    centralizar(math.floor(alt/2), " ⏳ ESCANEANDO TERRENO... ", colors.yellow, colors.gray)
end

local function escanear()
    telaCarregamento()
    minerios = {}
    local blocos = geo.scan(cfg.raio)
    
    if blocos then
        for _, b in ipairs(blocos) do
            if string.find(b.name, "ore") then
                local nome = string.gsub(b.name, "minecraft:", "")
                nome = string.gsub(nome, "forge:", "")
                nome = string.gsub(nome, "_ore", "")
                nome = string.upper(nome)
                -- Corta o nome para caber na tabela perfeitamente (max 9 letras)
                nome = string.sub(nome, 1, 9) 
                
                local dist = calcularDistancia(b.x, b.y, b.z)
                table.insert(minerios, {nome=nome, x=b.x, y=b.y, z=b.z, dist=dist, cor=obterCor(nome)})
            end
        end
        table.sort(minerios, function(a, b) return a.dist < b.dist end)
    end
    cfg.pagina = 1
end

-- =======================================================
-- 🖥️ RENDERIZAÇÃO DA UI PRINCIPAL
-- =======================================================
local function desenharUI()
    mon.setTextScale(cfg.escala)
    local larg, alt = mon.getSize()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- 1. BARRA SUPERIOR (PAINEL DE CONTROLE)
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.blue)
    mon.write(string.rep(" ", larg))
    mon.setCursorPos(2, 1)
    mon.setTextColor(colors.white)
    
    -- Botões de atalho da barra superior
    mon.write("[SCAN]")
    local str_raio = string.format("R:%02d", cfg.raio)
    local str_zoom = string.format("Z:%.1f", cfg.escala)
    
    mon.setCursorPos(larg - 24, 1)
    mon.write("[-] " .. str_raio .. " [+]   [-] " .. str_zoom .. " [+]")

    -- 2. CABEÇALHO DA TABELA
    mon.setCursorPos(1, 2)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", larg))
    mon.setCursorPos(2, 2)
    mon.setTextColor(colors.cyan)
    -- Layout da Tabela: NOME (10), DIST (4), X (4), Y (4), Z (4)
    mon.write(string.format("%-10s %-4s %-4s %-4s %-4s", "MINERIO", "DIST", "X", "Y", "Z"))
    
    -- 3. LINHAS DE DADOS
    local max_linhas = alt - 3
    local max_paginas = math.ceil(#minerios / max_linhas)
    if max_paginas == 0 then max_paginas = 1 end
    
    if #minerios == 0 then
        centralizar(4, "Nenhum minério no raio atual", colors.red, colors.black)
    else
        local inicio = (cfg.pagina - 1) * max_linhas + 1
        local fim = math.min(inicio + max_linhas - 1, #minerios)
        local linha_atual = 3
        
        for i = inicio, fim do
            local m = minerios[i]
            mon.setBackgroundColor(colors.black)
            mon.setCursorPos(2, linha_atual)
            
            -- Pinta só o nome da cor do minério
            mon.setTextColor(m.cor)
            mon.write(string.format("%-10s", m.nome))
            
            -- O resto dos dados em branco para ficar limpo
            mon.setTextColor(colors.white)
            mon.write(string.format(" %-4d %-4d %-4d %-4d", m.dist, m.x, m.y, m.z))
            
            linha_atual = linha_atual + 1
        end
    end
    
    -- 4. BARRA INFERIOR (PAGINAÇÃO)
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(1, alt)
    mon.write(string.rep(" ", larg))
    centralizar(alt, "[<] PÁGINA " .. cfg.pagina .. " / " .. max_paginas .. " [>]", colors.white, colors.gray)
end

-- =======================================================
-- 🖱️ SISTEMA DE TOQUE (HITBOXES)
-- =======================================================
local function loopToque()
    escanear()
    desenharUI()
    
    while rodando do
        local _, _, x, y = os.pullEvent("monitor_touch")
        local larg, alt = mon.getSize()
        local max_linhas = alt - 3
        local max_paginas = math.ceil(#minerios / max_linhas)
        if max_paginas == 0 then max_paginas = 1 end
        
        -- Hitboxes da Linha 1 (Controles)
        if y == 1 then
            if x >= 2 and x <= 7 then escanear() -- [SCAN]
            elseif x >= (larg - 24) and x <= (larg - 21) then if cfg.raio > 1 then cfg.raio = cfg.raio - 1 end -- Raio [-]
            elseif x >= (larg - 14) and x <= (larg - 11) then if cfg.raio < 16 then cfg.raio = cfg.raio + 1 end -- Raio [+]
            elseif x >= (larg - 9) and x <= (larg - 6) then if cfg.escala > 0.5 then cfg.escala = cfg.escala - 0.5 end -- Zoom [-]
            elseif x >= (larg - 0) or x >= (larg - 3) then if cfg.escala < 3.0 then cfg.escala = cfg.escala + 0.5 end -- Zoom [+]
            end
        end
        
        -- Hitboxes da Última Linha (Paginação)
        if y == alt then
            if x < (larg / 2) then if cfg.pagina > 1 then cfg.pagina = cfg.pagina - 1 end
            else if cfg.pagina < max_paginas then cfg.pagina = cfg.pagina + 1 end
            end
        end
        desenharUI()
    end
end

-- =======================================================
-- 🚀 INICIALIZAÇÃO SEGURA
-- =======================================================
local function loopSaida()
    while rodando do
        local _, tecla = os.pullEvent("key")
        if tecla == keys.q then
            rodando = false
            mon.setBackgroundColor(colors.black)
            mon.clear()
            print("Radar desligado com sucesso.")
        end
    end
end

print("🚀 Sistema Inicializado!")
print("Painel sendo exibido no monitor.")
print("Pressione 'Q' neste terminal para sair.")
parallel.waitForAny(loopSaida, loopToque)
