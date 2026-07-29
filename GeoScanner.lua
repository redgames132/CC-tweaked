-- =======================================================
-- ⚙️ PAINEL DE CONFIGURAÇÕES (EDITE SEU RADAR AQUI)
-- =======================================================
local CONFIG = {
    -- Alcance do radar em blocos (Recomendado: entre 4 e 16)
    RAIO_RADAR = 32,

    -- Tamanho do texto no monitor (0.5 = Pequeno, 1.0 = Normal, 1.5 = Grande)
    ESCALA_UI = 0.5,

    -- Lado do monitor: "auto" para buscar sozinho ou "right", "left", "top", "bottom", "back", "front"
    LADO_MONITOR = "right",

    -- Lado do Geo Scanner: "top", "bottom", "left", "right", "back", "front" ou "auto"
    LADO_SCANNER = "top",

    -- Atualizar automaticamente a tela? (true = Sim, em tempo real | false = Escaneia 1 vez)
    MODO_CONTINUO = true,

    -- Tempo em segundos entre cada escaneamento (mínimo recomendado: 2 ou 3)
    INTERVALO_SEGUNDOS = 1
}

-- =======================================================
-- 🛠️ INICIALIZAÇÃO E PERIFÉRICOS
-- =======================================================
local function conectarMonitor()
    if CONFIG.LADO_MONITOR == "auto" then
        return peripheral.find("monitor")
    else
        return peripheral.wrap(CONFIG.LADO_MONITOR)
    end
end

local function conectarScanner()
    if CONFIG.LADO_SCANNER == "auto" then
        return peripheral.find("geoScanner")
    else
        return peripheral.wrap(CONFIG.LADO_SCANNER)
    end
end

local mon = conectarMonitor()
local geo = conectarScanner()

if not mon then
    print("❌ Erro: Monitor nao encontrado!")
    print("Defina o LADO_MONITOR no topo do codigo ou conecte um Advanced Monitor.")
    return
end

if not geo then
    print("❌ Erro: Geo Scanner nao encontrado!")
    print("Verifique se o bloco do scanner esta no lado definido (PADRAO: top).")
    return
end

-- Configura a escala do monitor
mon.setTextScale(CONFIG.ESCALA_UI)

-- =======================================================
-- 🎨 FUNÇÕES VISUAIS E DE CORES
-- =======================================================
-- Associa cores do Minecraft aos minérios correspondentes
local function obterCorMinerio(nome)
    local n = string.upper(nome)
    if string.find(n, "DIAMOND") or string.find(n, "DIAMANTE") then return colors.cyan end
    if string.find(n, "GOLD") or string.find(n, "OURO") then return colors.yellow end
    if string.find(n, "IRON") or string.find(n, "FERRO") then return colors.lightGray end
    if string.find(n, "REDSTONE") then return colors.red end
    if string.find(n, "EMERALD") or string.find(n, "ESMERALDA") then return colors.lime end
    if string.find(n, "LAPIS") then return colors.blue end
    if string.find(n, "COAL") or string.find(n, "CARVAO") then return colors.gray end
    if string.find(n, "COPPER") or string.find(n, "COBRE") then return colors.orange end
    if string.find(n, "DEBRIS") or string.find(n, "NETHERITE") then return colors.purple end
    if string.find(n, "QUARTZ") or string.find(n, "QUARTZO") then return colors.white end
    return colors.lightBlue
end

-- Centraliza um texto na linha desejada
local function escreverCentralizado(y, texto, corTexto, corFundo)
    local largura, _ = mon.getSize()
    local x = math.floor((largura - #texto) / 2) + 1
    if x < 1 then x = 1 end
    mon.setCursorPos(x, y)
    mon.setTextColor(corTexto or colors.white)
    mon.setBackgroundColor(corFundo or colors.black)
    mon.write(texto)
end

-- Desenha a moldura (borda) e o cabeçalho
local function desenharEstruturaUI(totalDetectado)
    local largura, altura = mon.getSize()
    mon.setBackgroundColor(colors.black)
    mon.clear()

    -- Borda Superior
    mon.setBackgroundColor(colors.gray)
    mon.setTextColor(colors.gray)
    mon.setCursorPos(1, 1)
    mon.write(string.rep(" ", largura))

    -- Título
    escreverCentralizado(1, " 📡 RADAR DE MINÉRIOS ", colors.yellow, colors.gray)

    -- Barra de Status (Linha 2)
    mon.setBackgroundColor(colors.blue)
    mon.setCursorPos(1, 2)
    mon.write(string.rep(" ", largura))
    
    local status = "Raio: " .. CONFIG.RAIO_RADAR .. "b | Total: " .. totalDetectado
    escreverCentralizado(2, status, colors.white, colors.blue)

    -- Linha Divisória (Linha 3)
    mon.setBackgroundColor(colors.black)
    mon.setTextColor(colors.cyan)
    mon.setCursorPos(1, 3)
    mon.write(string.rep("-", largura))

    -- Rodapé
    mon.setBackgroundColor(colors.gray)
    mon.setCursorPos(1, altura)
    mon.write(string.rep(" ", largura))
    escreverCentralizado(altura, "[ CTRL+T para fechar ]", colors.lightGray, colors.gray)

    mon.setBackgroundColor(colors.black)
end

-- =======================================================
-- 🔄 CICLO DE ESCANEAMENTO E RENDERIZAÇÃO
-- =======================================================
local function executarRadar()
    local blocos = geo.scan(CONFIG.RAIO_RADAR)

    if not blocos then
        desenharEstruturaUI(0)
        escreverCentralizado(5, "⚠️ Recarregando Scanner...", colors.red, colors.black)
        return
    end

    -- Contagem de minérios
    local contagem = {}
    local total = 0

    for _, bloco in ipairs(blocos) do
        if string.find(bloco.name, "ore") then
            total = total + 1
            local nome = string.gsub(bloco.name, "minecraft:", "")
            nome = string.gsub(nome, "forge:", "")
            nome = string.gsub(nome, "_ore", "")
            nome = string.upper(nome)

            contagem[nome] = (contagem[nome] or 0) + 1
        end
    end

    -- Desenha a estrutura da tela
    desenharEstruturaUI(total)

    local _, altura = mon.getSize()
    local linhaAtual = 5

    if total == 0 then
        escreverCentralizado(linhaAtual, "Nenhum minerio por perto", colors.lightGray, colors.black)
    else
        for nome, qtd in pairs(contagem) do
            -- Se estourar a altura da tela, interrompe a listagem
            if linhaAtual >= (altura - 1) then
                mon.setCursorPos(2, linhaAtual)
                mon.setTextColor(colors.gray)
                mon.write("+ Outros minérios...")
                break
            end

            local cor = obterCorMinerio(nome)

            -- Desenha Marcador Bullets (•)
            mon.setCursorPos(2, linhaAtual)
            mon.setTextColor(colors.white)
            mon.write("• ")

            -- Nome do Minério
            mon.setTextColor(cor)
            mon.write(nome .. ": ")

            -- Quantidade
            mon.setTextColor(colors.white)
            mon.write(qtd .. "x")

            linhaAtual = linhaAtual + 1
        end
    end
end

-- =======================================================
-- 🚀 EXECUÇÃO PRINCIPAL
-- =======================================================
print("🚀 Radar Iniciado!")
print("Verifique a tela do seu Monitor.")

if CONFIG.MODO_CONTINUO then
    while true do
        executarRadar()
        sleep(CONFIG.INTERVALO_SEGUNDOS)
    end
else
    executarRadar()
end
