-- =======================================================
-- ⚙️ SETUP E PERIFÉRICOS
-- =======================================================
local mon = peripheral.find("monitor")
if not mon then 
    print("❌ Erro: Monitor não encontrado!") 
    return 
end

-- =======================================================
-- 🛡️ DADOS DO JOGO (STATUS E INIMIGOS)
-- =======================================================
local jogador = {
    hp = 50,
    maxHp = 50,
    level = 1,
    xp = 0,
    ouro = 0,
    pocoes = 3
}

-- Arte ASCII para os inimigos
local bestiario = {
    {nome = "Slime de Musgo", maxHp = 15, dano = 3, xp = 5, ouro = 2, cor = colors.lime,
     arte = {"       ", "  ___  ", " (o.o) ", " (___) ", "       "}},
     
    {nome = "Goblin Furioso", maxHp = 30, dano = 6, xp = 12, ouro = 5, cor = colors.green,
     arte = {"  ^ ^  ", " (O.O) ", " / | \\ ", "  / \\  ", "       "}},
     
    {nome = "Esqueleto", maxHp = 45, dano = 10, xp = 20, ouro = 10, cor = colors.lightGray,
     arte = {"  .-.  ", " (o o) ", "  |O|  ", " /| |\\ ", "  / \\  "}},
     
    {nome = "Dragao Menor", maxHp = 100, dano = 20, xp = 50, ouro = 50, cor = colors.red,
     arte = {" \\\\  // ", " (o  o) ", " /|  |\\ ", "  |__|  ", "  ^  ^  "}}
}

local inimigoAtual = nil
local mensagemLog = "Um monstro apareceu! O que voce faz?"
local rodando = true

-- =======================================================
-- 🎨 FUNÇÕES DE DESENHO E UI
-- =======================================================
local function centralizar(y, texto, corTexto, corFundo)
    local larg, _ = mon.getSize()
    local x = math.floor((larg - #texto) / 2) + 1
    if x < 1 then x = 1 end
    mon.setCursorPos(x, y)
    mon.setTextColor(corTexto or colors.white)
    if corFundo then mon.setBackgroundColor(corFundo) end
    mon.write(texto)
end

local function desenharCaixa(x, y, larg, alt, corFundo)
    mon.setBackgroundColor(corFundo)
    for i = 0, alt - 1 do
        mon.setCursorPos(x, y + i)
        mon.write(string.rep(" ", larg))
    end
end

local function gerarInimigo()
    -- Escolhe um inimigo baseado no level do jogador
    local maxIndex = math.min(jogador.level, #bestiario)
    local template = bestiario[math.random(1, maxIndex)]
    
    inimigoAtual = {
        nome = template.nome,
        hp = template.maxHp,
        maxHp = template.maxHp,
        dano = template.dano,
        xp = template.xp,
        ouro = template.ouro,
        cor = template.cor,
        arte = template.arte
    }
end

local function desenharTela()
    mon.setTextScale(1) -- Tamanho perfeito para 6x3 blocos
    local larg, alt = mon.getSize()
    
    mon.setBackgroundColor(colors.black)
    mon.clear()
    
    -- 1. CABEÇALHO (Status do Jogador)
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.blue)
    mon.write(string.rep(" ", larg))
    
    local txtStatus = string.format(" ❤️ HP: %d/%d   ⭐ LVL: %d   ✨ XP: %d   🪙 OURO: %d ", 
        jogador.hp, jogador.maxHp, jogador.level, jogador.xp, jogador.ouro)
    mon.setCursorPos(2, 1)
    mon.setTextColor(colors.white)
    mon.write(txtStatus)

    -- 2. PAINEL DO INIMIGO (Esquerda)
    desenharCaixa(2, 3, 20, 8, colors.gray)
    
    if inimigoAtual then
        -- Nome e HP do Inimigo
        mon.setCursorPos(3, 4)
        mon.setTextColor(inimigoAtual.cor)
        mon.setBackgroundColor(colors.gray)
        mon.write(inimigoAtual.nome)
        
        mon.setCursorPos(3, 5)
        mon.setTextColor(colors.red)
        mon.write("HP: " .. inimigoAtual.hp .. "/" .. inimigoAtual.maxHp)
        
        -- Arte ASCII do Inimigo
        for i, linha in ipairs(inimigoAtual.arte) do
            mon.setCursorPos(8, 5 + i)
            mon.setTextColor(inimigoAtual.cor)
            mon.write(linha)
        end
    end

    -- 3. PAINEL DE LOG (Direita)
    desenharCaixa(24, 3, larg - 25, 8, colors.black)
    mon.setCursorPos(24, 3)
    mon.setTextColor(colors.yellow)
    mon.setBackgroundColor(colors.black)
    mon.write(">> DIARIO DE BATALHA:")
    
    mon.setCursorPos(24, 5)
    mon.setTextColor(colors.white)
    mon.write(mensagemLog)

    -- 4. BOTÕES DE AÇÃO (Rodapé)
    -- Botão ATACAR
    desenharCaixa(4, 13, 14, 3, colors.red)
    mon.setCursorPos(7, 14)
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.red)
    mon.write("ATACAR")
    
    -- Botão CURAR
    desenharCaixa(22, 13, 14, 3, colors.lime)
    mon.setCursorPos(23, 14)
    mon.setTextColor(colors.black)
    mon.setBackgroundColor(colors.lime)
    mon.write("CURA (" .. jogador.pocoes .. "x)")
    
    -- Botão FUGIR
    desenharCaixa(40, 13, 14, 3, colors.orange)
    mon.setCursorPos(44, 14)
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.orange)
    mon.write("FUGIR")
end

-- =======================================================
-- ⚔️ SISTEMA DE COMBATE
-- =======================================================
local function turnoInimigo()
    if inimigoAtual.hp > 0 then
        local dano = math.random(math.floor(inimigoAtual.dano / 2), inimigoAtual.dano)
        jogador.hp = jogador.hp - dano
        mensagemLog = inimigoAtual.nome .. " atacou e causou " .. dano .. " de dano!"
        
        if jogador.hp <= 0 then
            jogador.hp = 0
            mensagemLog = "VOCE MORREU! Fim de Jogo."
            rodando = false
        end
    end
end

local function subirLevel()
    local xpNecessario = jogador.level * 20
    if jogador.xp >= xpNecessario then
        jogador.level = jogador.level + 1
        jogador.xp = jogador.xp - xpNecessario
        jogador.maxHp = jogador.maxHp + 10
        jogador.hp = jogador.maxHp
        mensagemLog = "LEVEL UP! Voce recuperou todo o HP."
        return true
    end
    return false
end

local function processarAtaque()
    -- Dano do jogador baseado no level
    local dano = math.random(5 + (jogador.level * 2), 10 + (jogador.level * 3))
    inimigoAtual.hp = inimigoAtual.hp - dano
    
    if inimigoAtual.hp <= 0 then
        inimigoAtual.hp = 0
        mensagemLog = "Voce derrotou o " .. inimigoAtual.nome .. "! (+" .. inimigoAtual.xp .. "XP)"
        jogador.xp = jogador.xp + inimigoAtual.xp
        jogador.ouro = jogador.ouro + inimigoAtual.ouro
        
        -- Chance de dropar poção
        if math.random(1, 4) == 1 then
            jogador.pocoes = jogador.pocoes + 1
            mensagemLog = mensagemLog .. " Dropou uma Pocao!"
        end
        
        desenharTela()
        os.sleep(1.5)
        
        if not subirLevel() then
            mensagemLog = "Um novo monstro se aproxima..."
        end
        gerarInimigo()
    else
        mensagemLog = "Voce causou " .. dano .. " de dano!"
        desenharTela()
        os.sleep(1)
        turnoInimigo()
    end
end

local function processarCura()
    if jogador.pocoes > 0 then
        if jogador.hp < jogador.maxHp then
            jogador.pocoes = jogador.pocoes - 1
            local cura = 20 + (jogador.level * 5)
            jogador.hp = math.min(jogador.maxHp, jogador.hp + cura)
            mensagemLog = "Voce curou " .. cura .. " HP!"
            desenharTela()
            os.sleep(1)
            turnoInimigo()
        else
            mensagemLog = "Seu HP ja esta cheio!"
        end
    else
        mensagemLog = "Voce nao tem mais pocoes!"
    end
end

local function processarFuga()
    if math.random(1, 2) == 1 then
        mensagemLog = "Voce fugiu com sucesso!"
        desenharTela()
        os.sleep(1.5)
        gerarInimigo()
        mensagemLog = "Voce encontrou outro inimigo."
    else
        mensagemLog = "Falha ao fugir! O monstro te alcancou."
        desenharTela()
        os.sleep(1)
        turnoInimigo()
    end
end

-- =======================================================
-- 🖱️ GERENCIADOR DE CLIQUES E LOOP PRINCIPAL
-- =======================================================
gerarInimigo()
desenharTela()

while rodando do
    local event, side, x, y = os.pullEvent("monitor_touch")
    
    -- Hitbox Botão ATACAR (x: 4 a 17, y: 13 a 15)
    if y >= 13 and y <= 15 then
        if x >= 4 and x <= 17 then
            processarAtaque()
        -- Hitbox Botão CURAR (x: 22 a 35, y: 13 a 15)
        elseif x >= 22 and x <= 35 then
            processarCura()
        -- Hitbox Botão FUGIR (x: 40 a 53, y: 13 a 15)
        elseif x >= 40 and x <= 53 then
            processarFuga()
        end
    end
    
    desenharTela()
    
    if not rodando then
        os.sleep(3)
        mon.clear()
        mon.setCursorPos(1,1)
        print("Game Over.")
        break
    end
end
