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
    raio = 8,        -- Raio inicial
    maxRaio = 16,     -- 🚀 LIMITE MÁXIMO DO RAIO (Pode mudar para 64)
    escala = 0.5,
    pagina = 1,
    autoRefresh = false
}

local minerios = {}
local rodando = true

-- =======================================================
-- 🎨 UTILITÁRIOS DE TELA E CORES
-- =======================================================
local function calcularDistancia(x, y, z)
    return math.floor(math.sqrt(x^2 + y^2 + z^2))
end

local function formatarNomeMinerio(fullName)
    local mod = "MC"
    local nome = fullName
    
    if string.find(fullName, ":") then
        local partes = {}
        for part in string.gmatch(fullName, "[^:]+") do table.insert(partes, part) end
        if #partes >= 2 then mod = string.upper(partes[1]); nome = partes[2] end
    end
    
    nome = string.gsub(nome, "_ore", "")
    nome = string.gsub(nome, "ore_", "")
    nome = string.gsub(nome, "deepslate_", "")
    nome = string.upper(nome)
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

local function desenharBotao(x, y, texto, corFundo, corTexto)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(corFundo)
    mon.setTextColor(corTexto)
    mon.write(" " .. texto .. " ")
    mon.setBackgroundColor(colors.black)
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
                    nome=nome, mod=mod, x=b.x, y=b.y, z=b.z, dist=dist, cor=obterCor(nome)
                })
            end
        end
        table.sort(minerios, function(a, b) return a.dist < b.dist end)
    end
    cfg.pagina = 1
end

-- =======================================================
-- 🖥️ RENDERIZAÇÃO DA UI DASHBOARD
-- =======================================================
local function desenharUI()
    mon.setTextScale(cfg.escala)
    local larg, alt = mon.getSize()
    local usarDuasColunas = larg >= 60
    local larguraColuna = usarDuasColunas and math.floor((larg - 3) / 2) or (larg - 2)
    
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- 1. CABEÇALHO PRINCIPAL
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", larg))
    centralizar(1, " ORE RADAR DASHBOARD v3.1 ", colors.cyan, colors.gray)

    -- 2. BARRA DE CONTROLES (Linha 3)
    desenharBotao(2, 3, "SCAN", colors.lime, colors.black)
    
    if cfg.autoRefresh then
        desenharBotao(10, 3, "AUTO: ON", colors.lightBlue, colors.black)
    else
        desenharBotao(10, 3, "AUTO: OFF", colors.red, colors.white)
    end

    -- Controles de Raio
    mon.setCursorPos(24, 3)
    mon.setTextColor(colors.lightGray)
    mon.write("RAIO:")
    desenharBotao(30, 3, "<", colors.gray, colors.white)
    mon.setTextColor(colors.yellow)
    mon.write(string.format(" %02d ", cfg.raio))
    desenharBotao(36, 3, ">", colors.gray, colors.white)

    -- Controles de Zoom
    mon.setCursorPos(42, 3)
    mon.setTextColor(colors.lightGray)
    mon.write("ZOOM:")
    desenharBotao(48, 3, "<", colors.gray, colors.white)
    mon.setTextColor(colors.yellow)
    mon.write(string.format(" %.1f ", cfg.escala))
    desenharBotao(55, 3, ">", colors.gray, colors.white)

    -- 3. CABEÇALHO DA TABELA (Linha 5)
    local linhaTabela = 5
    mon.setCursorPos(1, linhaTabela)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", larg))
    
    local txtCabecalho = string.format("%-8s %-4s %-4s %-3s %-3s %-3s", "MINERIO", "MOD", "DIST", "X", "Y", "Z")
    
    mon.setCursorPos(2, linhaTabela)
    mon.setTextColor(colors.white)
    mon.write(txtCabecalho)
    
    if usarDuasColunas then
        mon.setCursorPos(larguraColuna + 3, linhaTabela)
        mon.write(txtCabecalho)
    end
    
    -- 4. DADOS DOS MINÉRIOS
    local maxLinhasPorColuna = alt - 7
    local itensPorPagina = usarDuasColunas and (maxLinhasPorColuna * 2) or maxLinhasPorColuna
    local maxPaginas = math.ceil(#minerios / itensPorPagina)
    if maxPaginas == 0 then maxPaginas = 1 end
    
    if #minerios == 0 then
        centralizar(linhaTabela + 2, "NENHUM MINERIO ENCONTRADO NO RAIO " .. cfg.raio, colors.red, colors.black)
    else
        local inicio = (cfg.pagina - 1) * itensPorPagina + 1
        local fim = math.min(inicio + itensPorPagina - 1, #minerios)
        
        for i = inicio, fim do
            local m = minerios[i]
            local idxRelativo = i - inicio
            local col = 1
            local linhaAtual = idxRelativo + (linhaTabela + 1)
            
            if usarDuasColunas and idxRelativo >= maxLinhasPorColuna then
                col = 2
                linhaAtual = (idxRelativo - maxLinhasPorColuna) + (linhaTabela + 1)
            end
            
            local posX = (col == 1) and 2 or (larguraColuna + 3)
            
            local corFundo = (linhaAtual % 2 == 0) and colors.black or colors.gray
            mon.setCursorPos(posX, linhaAtual)
            mon.setBackgroundColor(corFundo == colors.gray and colors.black or colors.gray)
            mon.write(string.rep(" ", larguraColuna))
            
            mon.setCursorPos(posX, linhaAtual)
            mon.setTextColor(m.dist <= 4 and colors.yellow or colors.white)
            mon.write((m.dist <= 4 and "!" or ".") .. " ")
            
            mon.setTextColor(m.cor)
            mon.write(string.format("%-7s ", m.nome))
            
            mon.setTextColor(colors.lightGray)
            mon.write(string.format("%-4s ", string.sub(m.mod, 1, 4)))
            mon.setTextColor(colors.white)
            mon.write(string.format("%-4d %-3d %-3d %-3d", m.dist, m.x, m.y, m.z))
        end
    end
    
    -- 5. RODAPÉ DE PAGINAÇÃO
    mon.setBackgroundColor(colors.gray)
    mon.setCursorPos(1, alt)
    mon.write(string.rep(" ", larg))
    
    local txtPag = string.format(" <<   PAGINA %d / %d (%d MINERIOS)   >> ", cfg.pagina, maxPaginas, #minerios)
    centralizar(alt, txtPag, colors.white, colors.gray)
end

-- =======================================================
-- 🖱️ GERENCIADOR DE EVENTOS E TOUCH
-- =======================================================
local function loopEventos()
    escanear()
    desenharUI()
    local timerID = os.startTimer(3)
    
    while rodando do
        local event, p1, x, y = os.pullEvent()
        local larg, alt = mon.getSize()
        
        local usarDuasColunas = larg >= 60
        local maxLinhasPorColuna = alt - 7
        local itensPorPagina = usarDuasColunas and (maxLinhasPorColuna * 2) or maxLinhasPorColuna
        local maxPaginas = math.ceil(#minerios / itensPorPagina)
        if maxPaginas == 0 then maxPaginas = 1 end
        
        if event == "monitor_touch" then
            if y == 3 then
                if x >= 2 and x <= 7 then escanear()
                elseif x >= 10 and x <= 20 then cfg.autoRefresh = not cfg.autoRefresh
                elseif x >= 30 and x <= 32 then if cfg.raio > 1 then cfg.raio = cfg.raio - 1 end
                elseif x >= 36 and x <= 38 then if cfg.raio < cfg.maxRaio then cfg.raio = cfg.raio + 1 end -- 🚀 Usa maxRaio
                elseif x >= 48 and x <= 50 then if cfg.escala > 0.5 then cfg.escala = cfg.escala - 0.5 end
                elseif x >= 55 and x <= 57 then if cfg.escala < 3.0 then cfg.escala = cfg.escala + 0.5 end
                end
                desenharUI()
                
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
            timerID = os.startTimer(3)
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

print("🚀 Dashboard Inicializado (Max Raio: " .. cfg.maxRaio .. ")")
print("Pressione 'Q' no terminal para desligar.")
parallel.waitForAny(loopSaida, loopEventos)
