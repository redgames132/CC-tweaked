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
local cfg = {
    raio = 16,
    escala = 0.5, -- Escala atual da sua foto
    pagina = 1,
    autoRefresh = false
}

local minerios = {}
local rodando = true

-- =======================================================
-- 🎨 UTILITÁRIOS DE CORES E TRATAMENTO DE TEXTO
-- =======================================================
local function calcularDistancia(x, y, z)
    return math.floor(math.sqrt(x^2 + y^2 + z^2))
end

-- Limpa e formatada nomes do Minecraft e de Mods (ex: Create, Tech mods)
local function formatarNomeMinerio(fullName)
    local mod = "MC"
    local nome = fullName
    
    if string.find(fullName, ":") then
        local partes = {}
        for part in string.gmatch(fullName, "[^:]+") do
            table.insert(partes, part)
        end
        if #partes >= 2 then
            mod = string.upper(partes[1])
            nome = partes[2]
        end
    end
    
    nome = string.gsub(nome, "_ore", "")
    nome = string.gsub(nome, "ore_", "")
    nome = string.gsub(nome, "deepslate_", "")
    nome = string.upper(nome)
    
    -- Corta nomes gigantes para caber na tabela
    if #nome > 8 then nome = string.sub(nome, 1, 8) end
    
    return nome, mod
end

local function obterCor(nome)
    if string.find(nome, "DIAMOND") then return colors.cyan end
    if string.find(nome, "GOLD") then return colors.yellow end
    if string.find(nome, "IRON") then return colors.lightGray end
    if string.find(nome, "REDSTONE") then return colors.red end
    if string.find(nome, "EMERALD") then return colors.lime end
    if string.find(nome, "LAPIS") then return colors.blue end
    if string.find(nome, "COAL") then return colors.gray end
    if string.find(nome, "COPPER") or string.find(nome, "ZINC") then return colors.orange end
    if string.find(nome, "QUARTZ") then return colors.white end
    return colors.lightBlue
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
local function escanear()
    minerios = {}
    local blocos = geo.scan(cfg.raio)
    
    if blocos then
        for _, b in ipairs(blocos) do
            if string.find(b.name, "ore") then
                local nome, mod = formatarNomeMinerio(b.name)
                local dist = calcularDistancia(b.x, b.y, b.z)
                table.insert(minerios, {
                    nome = nome,
                    mod = mod,
                    x = b.x, y = b.y, z = b.z,
                    dist = dist,
                    cor = obterCor(nome)
                })
            end
        end
        table.sort(minerios, function(a, b) return a.dist < b.dist end)
    end
    cfg.pagina = 1
end

-- =======================================================
-- 🖥️ RENDERIZAÇÃO DA UI DUAL-COLUMN (WIDESCREEN)
-- =======================================================
local function desenharUI()
    mon.setTextScale(cfg.escala)
    local larg, alt = mon.getSize()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- Detecta se a tela é larga o suficiente para 2 Colunas
    local usarDuasColunas = larg >= 60
    local larguraColuna = usarDuasColunas and math.floor((larg - 3) / 2) or (larg - 2)
    
    -- 1. BARRA SUPERIOR (CONTROLES)
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.blue)
    mon.write(string.rep(" ", larg))
    mon.setCursorPos(2, 1)
    mon.setTextColor(colors.white)
    
    local txtAuto = cfg.autoRefresh and "[AUTO:ON]" or "[AUTO:OFF]"
    mon.write("[SCAN] " .. txtAuto)
    
    local str_raio = string.format("R:%02d", cfg.raio)
    local str_zoom = string.format("Z:%.1f", cfg.escala)
    mon.setCursorPos(math.max(20, larg - 28), 1)
    mon.write("[-] " .. str_raio .. " [+]   [-] " .. str_zoom .. " [+]")

    -- 2. CABEÇALHO DA TABELA
    mon.setCursorPos(1, 2)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", larg))
    
    local cabecalho = string.format("%-8s %-4s %-4s %-3s %-3s %-3s", "MINERIO", "MOD", "DIST", "X", "Y", "Z")
    
    mon.setCursorPos(2, 2)
    mon.setTextColor(colors.yellow)
    mon.write(cabecalho)
    
    if usarDuasColunas then
        mon.setCursorPos(larguraColuna + 3, 2)
        mon.setTextColor(colors.yellow)
        mon.write(cabecalho)
    end
    
    -- 3. LINHAS DE DADOS
    local maxLinhasPorColuna = alt - 3
    local itensPorPagina = usarDuasColunas and (maxLinhasPorColuna * 2) or maxLinhasPorColuna
    local maxPaginas = math.ceil(#minerios / itensPorPagina)
    if maxPaginas == 0 then maxPaginas = 1 end
    
    if #minerios == 0 then
        centralizar(4, "Nenhum minério encontrado no raio " .. cfg.raio, colors.red, colors.black)
    else
        local inicio = (cfg.pagina - 1) * itensPorPagina + 1
        local fim = math.min(inicio + itensPorPagina - 1, #minerios)
        
        for i = inicio, fim do
            local m = minerios[i]
            local idxRelativo = i - inicio
            
            local col = 1
            local linha = idxRelativo + 3
            
            if usarDuasColunas and idxRelativo >= maxLinhasPorColuna then
                col = 2
                linha = (idxRelativo - maxLinhasPorColuna) + 3
            end
            
            local posX = (col == 1) and 2 or (larguraColuna + 3)
            
            -- Efeito Zebra (fundo cinza escuro sutil em linhas pares)
            local corFundo = (linha % 2 == 0) and colors.black or colors.gray
            local bgEfetivo = (corFundo == colors.gray) and colors.black or colors.gray
            
            -- Preenche o fundo da célula
            mon.setCursorPos(posX, linha)
            mon.setBackgroundColor(bgEfetivo)
            mon.write(string.rep(" ", larguraColuna))
            
            -- Escreve os dados
            mon.setCursorPos(posX, linha)
            
            -- Ícone de proximidade
            local ico = m.dist <= 4 and "⚡" or "•"
            mon.setTextColor(m.dist <= 4 and colors.yellow or colors.white)
            mon.write(ico)
            
            -- Nome e detalhes
            mon.setTextColor(m.cor)
            mon.write(string.format("%-7s ", m.nome))
            
            mon.setTextColor(colors.lightGray)
            mon.write(string.format("%-4s ", string.sub(m.mod, 1, 4)))
            
            mon.setTextColor(colors.white)
            mon.write(string.format("%-4d %-3d %-3d %-3d", m.dist, m.x, m.y, m.z))
        end
    end
    
    -- 4. BARRA INFERIOR (PAGINAÇÃO)
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.yellow)
    mon.setCursorPos(1, alt)
    mon.write(string.rep(" ", larg))
    
    local txtPag = string.format("[<] PÁGINA %d DE %d (TOTAL: %d) [>]", cfg.pagina, maxPaginas, #minerios)
    centralizar(alt, txtPag, colors.white, colors.gray)
end

-- =======================================================
-- 🖱️ GERENCIADOR DE EVENTOS (TOQUE + REFRESH)
-- =======================================================
local function loopEventos()
    escanear()
    desenharUI()
    
    -- Timer para auto-refresh se ativado
    local timerID = os.startTimer(3)
    
    while rodando do
        local event, p1, x, y = os.pullEvent()
        local larg, alt = mon.getSize()
        
        local usarDuasColunas = larg >= 60
        local maxLinhasPorColuna = alt - 3
        local itensPorPagina = usarDuasColunas and (maxLinhasPorColuna * 2) or maxLinhasPorColuna
        local maxPaginas = math.ceil(#minerios / itensPorPagina)
        if maxPaginas == 0 then maxPaginas = 1 end
        
        if event == "monitor_touch" then
            -- Linha 1: Controles Superiores
            if y == 1 then
                if x >= 2 and x <= 7 then 
                    escanear() -- [SCAN]
                elseif x >= 8 and x <= 17 then
                    cfg.autoRefresh = not cfg.autoRefresh -- [AUTO]
                elseif x >= (larg - 28) and x <= (larg - 23) then
                    if cfg.raio > 1 then cfg.raio = cfg.raio - 1 end -- Raio -
                elseif x >= (larg - 18) and x <= (larg - 13) then
                    if cfg.raio < 16 then cfg.raio = cfg.raio + 1 end -- Raio +
                elseif x >= (larg - 10) and x <= (larg - 6) then
                    if cfg.escala > 0.5 then cfg.escala = cfg.escala - 0.5 end -- Zoom -
                elseif x >= (larg - 3) then
                    if cfg.escala < 3.0 then cfg.escala = cfg.escala + 0.5 end -- Zoom +
                end
                desenharUI()
                
            -- Última Linha: Paginação
            elseif y == alt then
                if x < (larg / 2) then
                    if cfg.pagina > 1 then cfg.pagina = cfg.pagina - 1 end
                else
                    if cfg.pagina < maxPaginas then cfg.pagina = cfg.pagina + 1 end
                end
                desenharUI()
            end
            
        elseif event == "timer" and p1 == timerID then
            if cfg.autoRefresh then
                escanear()
                desenharUI()
            end
            timerID = os.startTimer(3) -- Reinicia o timer de 3 segundos
        end
    end
end

-- =======================================================
-- 🚀 SAÍDA SEGURA
-- =======================================================
local function loopSaida()
    while rodando do
        local _, tecla = os.pullEvent("key")
        if tecla == keys.q then
            rodando = false
            mon.setBackgroundColor(colors.black)
            mon.clear()
            print("Radar desligado.")
        end
    end
end

print("🚀 Radar Widescreen Inicializado!")
print("Pressione 'Q' no terminal para desligar.")
parallel.waitForAny(loopSaida, loopEventos)
