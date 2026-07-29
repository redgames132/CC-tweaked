-- Encontra os periféricos
local geo = peripheral.wrap("top")
local monitor = peripheral.wrap("right")

-- Checagens de erro no terminal do computador
if not geo then
    print("Erro: Geo Scanner nao encontrado no topo.")
    return
end

if not monitor then
    print("Erro: Monitor nao encontrado. Conecte um Advanced Monitor.")
    return
end

-- ==========================================
-- CONFIGURAÇÃO DO MONITOR (DECORAÇÃO)
-- ==========================================
monitor.setTextScale(1) -- Tamanho do texto (0.5 a 5). Mude se a tela for muito grande ou pequena.

-- Função para desenhar o cabeçalho bonitão
local function desenharCabecalho()
    monitor.setBackgroundColor(colors.blue)
    monitor.setTextColor(colors.yellow)
    monitor.clearLine()
    monitor.setCursorPos(1, 1)
    
    -- Centraliza o texto (aproximadamente) dependendo do tamanho da tela
    local largura, altura = monitor.getSize()
    local titulo = " RADAR DE MINERIOS "
    local espacos = math.floor((largura - string.len(titulo)) / 2)
    
    monitor.setCursorPos(espacos, 1)
    monitor.write(titulo)
    
    -- Reseta as cores para o restante da tela
    monitor.setBackgroundColor(colors.black)
    monitor.setTextColor(colors.white)
end

-- Tela de carregamento
monitor.setBackgroundColor(colors.black)
monitor.clear()
desenharCabecalho()
monitor.setCursorPos(2, 3)
monitor.setTextColor(colors.lightGray)
monitor.write("Escaneando terreno...")

-- ==========================================
-- LÓGICA DO ESCANEAMENTO
-- ==========================================
local raio = 8 
local blocos = geo.scan(raio)

if not blocos then
    monitor.setCursorPos(2, 4)
    monitor.setTextColor(colors.red)
    monitor.write("Erro: Scanner em tempo de recarga (Cooldown).")
    print("O scanner falhou. Tente novamente em alguns segundos.")
    return
end

-- Tabela para agrupar as quantidades de cada minério
local contagem_minerios = {}
local encontrou_algo = false

for i, bloco in ipairs(blocos) do
    if string.find(bloco.name, "ore") then
        encontrou_algo = true
        
        -- Limpa o nome para ficar bonito na tela
        local nome_limpo = string.gsub(bloco.name, "minecraft:", "")
        nome_limpo = string.gsub(nome_limpo, "forge:", "")
        nome_limpo = string.gsub(nome_limpo, "_ore", "")
        nome_limpo = string.upper(nome_limpo)
        
        -- Soma +1 na contagem desse minério específico
        if contagem_minerios[nome_limpo] then
            contagem_minerios[nome_limpo] = contagem_minerios[nome_limpo] + 1
        else
            contagem_minerios[nome_limpo] = 1
        end
    end
end

-- ==========================================
-- EXIBINDO OS RESULTADOS NO MONITOR
-- ==========================================
monitor.clear()
desenharCabecalho()

local linha_atual = 3

if not encontrou_algo then
    monitor.setCursorPos(2, linha_atual)
    monitor.setTextColor(colors.red)
    monitor.write("Nenhum minerio encontrado na regiao.")
else
    -- Lista cada minério encontrado com cores
    for nome, quantidade in pairs(contagem_minerios) do
        monitor.setCursorPos(2, linha_atual)
        
        -- Pinta o nome do minério de verde claro
        monitor.setTextColor(colors.lime)
        monitor.write("- " .. nome .. ": ")
        
        -- Pinta a quantidade de branco
        monitor.setTextColor(colors.white)
        monitor.write(tostring(quantidade) .. " blocos")
        
        linha_atual = linha_atual + 2 -- Pula uma linha para não ficar espremido
    end
end

-- Avisa no computador que deu tudo certo
print("Escaneamento concluido! Verifique o monitor.")
