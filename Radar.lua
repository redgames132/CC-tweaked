-- =======================================================
-- ⚙️ CONFIGURAÇÃO INICIAL (MUDE PARA O SEU NOME!)
-- =======================================================
local MEU_NICK = "SEU_NOME_AQUI" -- Ex: "Steve", "Notch"
local RAIO_BUSCA = 100 -- Distância máxima para procurar (em blocos)

-- Busca o Player Detector conectado no computador de bolso
local radar = peripheral.wrap("back")

if not radar then
    term.clear()
    term.setCursorPos(1,1)
    print("Erro: Player Detector nao encontrado!")
    print("Verifique se ele esta equipado no Pocket Computer.")
    return
end

-- =======================================================
-- 🎨 UTILITÁRIOS
-- =======================================================
local function calcularDistancia(x1, y1, z1, x2, y2, z2)
    return math.floor(math.sqrt((x2 - x1)^2 + (y2 - y1)^2 + (z2 - z1)^2))
end

local function centralizar(y, texto, corTexto, corFundo)
    local larg, _ = term.getSize()
    local x = math.floor((larg - #texto) / 2) + 1
    if x < 1 then x = 1 end
    term.setCursorPos(x, y)
    term.setTextColor(corTexto or colors.white)
    if corFundo then term.setBackgroundColor(corFundo) end
    term.write(texto)
end

-- =======================================================
-- 🔄 LOOP PRINCIPAL DO RADAR
-- =======================================================
while true do
    term.setBackgroundColor(colors.black)
    term.clear()
    
    -- 1. Cabeçalho
    centralizar(1, " [ RADAR DE BOLSO ] ", colors.lime, colors.gray)
    
    -- 2. Descobre a posição do dono do radar
    local minhaPos = radar.getPlayerPos(MEU_NICK)
    
    if not minhaPos then
        term.setCursorPos(2, 4)
        term.setTextColor(colors.red)
        print("Erro ao achar voce.")
        print("Verifique se seu nick")
        print("esta escrito certo em")
        print("MEU_NICK no topo.")
        os.sleep(3)
    else
        -- 3. Pega todos os jogadores na área
        local jogadores = radar.getPlayersInRange(RAIO_BUSCA)
        local encontrouAlguem = false
        local linha = 3
        
        -- 4. Processa cada jogador
        for _, nome in ipairs(jogadores) do
            -- Ignora o próprio dono do radar para não aparecer na lista
            if nome ~= MEU_NICK then
                encontrouAlguem = true
                local posAlvo = radar.getPlayerPos(nome)
                local dist = calcularDistancia(minhaPos.x, minhaPos.y, minhaPos.z, posAlvo.x, posAlvo.y, posAlvo.z)
                
                -- Limita o tamanho do nome para caber na tela pequena
                local nomeCurto = string.sub(nome, 1, 10)
                
                -- Desenha na tela (Estilo: NOME ....... 15b)
                term.setCursorPos(2, linha)
                term.setTextColor(colors.yellow)
                term.write(nomeCurto)
                
                term.setTextColor(colors.gray)
                term.write(" ........ ")
                
                -- Se estiver muito perto, fica vermelho
                if dist < 10 then
                    term.setTextColor(colors.red)
                else
                    term.setTextColor(colors.lime)
                end
                
                -- Posiciona a distância sempre no canto direito
                local larg = term.getSize()
                local txtDist = dist .. "b"
                term.setCursorPos(larg - #txtDist, linha)
                term.write(txtDist)
                
                -- Mostra o X e Z na linha de baixo
                linha = linha + 1
                term.setCursorPos(4, linha)
                term.setTextColor(colors.lightGray)
                term.write(string.format("X:%d Z:%d", posAlvo.x, posAlvo.z))
                
                linha = linha + 2
            end
        end
        
        -- Mensagem se estiver sozinho
        if not encontrouAlguem then
            centralizar(6, "Nenhum sinal detectado", colors.gray, colors.black)
            centralizar(7, "no raio de " .. RAIO_BUSCA .. "b", colors.gray, colors.black)
        end
    end
    
    -- Rodapé
    local larg, alt = term.getSize()
    term.setCursorPos(1, alt)
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", larg))
    centralizar(alt, "Pressione CTRL+T p/ Sair", colors.lightGray, colors.gray)
    
    -- Atualiza a cada 2 segundos para não dar lag
    os.sleep(2)
end
