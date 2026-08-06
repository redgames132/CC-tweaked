-- Substitua "left" e "right" pelos lados corretos onde seus blocos estão!
-- Lados válidos: "left", "right", "top", "bottom", "front", "back"

local monitor = peripheral.wrap("left")
local detector = peripheral.wrap("right")

-- Verifica se os periféricos estão realmente conectados
if not monitor then
    print("Erro: Monitor nao encontrado no lado especificado.")
    return
end

if not detector then
    print("Erro: Player Detector nao encontrado no lado especificado.")
    return
end

-- (O restante do código continua exatamente igual ao anterior a partir daqui)

-- Configurações visuais do Monitor
monitor.setTextScale(1) -- Altere para 0.5 se quiser letras menores
local largura, altura = monitor.getSize()

-- Função principal do radar
local function atualizarRadar()
    while true do
        -- Limpa a tela do monitor
        monitor.setBackgroundColor(colors.black)
        monitor.clear()
        monitor.setCursorPos(1, 1)
        
        -- Título
        monitor.setTextColor(colors.yellow)
        monitor.write("--- RADAR DE JOGADORES ---")
        
        -- Obtém a lista de todos os jogadores online no servidor
        local jogadores = detector.getOnlinePlayers()
        
        local linhaAtual = 3
        
        if #jogadores == 0 then
            monitor.setCursorPos(1, linhaAtual)
            monitor.setTextColor(colors.red)
            monitor.write("Nenhum jogador encontrado.")
        else
            -- Percorre a lista de jogadores
            for i, nick in ipairs(jogadores) do
                -- Para de escrever se o monitor encher
                if linhaAtual > altura then break end 
                
                monitor.setCursorPos(1, linhaAtual)
                monitor.setTextColor(colors.lightBlue)
                monitor.write(nick)
                
                -- Tenta pegar as coordenadas do jogador
                -- Usamos pcall para evitar que o programa crashe se o servidor bloquear essa função
                local sucesso, dados = pcall(function() return detector.getPlayerPos(nick) end)
                
                if sucesso and type(dados) == "table" then
                    -- Arredonda as coordenadas para não ficar com decimais feios
                    local x = math.floor(dados.x)
                    local y = math.floor(dados.y)
                    local z = math.floor(dados.z)
                    
                    monitor.setTextColor(colors.white)
                    monitor.write(" [X:" .. x .. " Y:" .. y .. " Z:" .. z .. "]")
                end
                
                linhaAtual = linhaAtual + 1
            end
        end
        
        -- Pausa de 3 segundos antes de atualizar de novo (evita lag no servidor)
        sleep(3)
    end
end

-- Inicia o programa
print("Radar iniciado com sucesso! Olhe para o monitor.")
print("Para parar o programa, segure Ctrl + T.")
atualizarRadar()
