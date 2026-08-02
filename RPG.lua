-- =======================================================
-- SETUP E PERIFERICOS
-- =======================================================
local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not mon then 
    print("Erro: Monitor nao encontrado!") 
    return 
end

-- =======================================================
-- ESTADO GLOBAL DO JOGO
-- =======================================================
local ESTADO = "MENU" -- MENU, CONFIG, BATALHA, LOJA, EVENTO, PAUSE, GAMEOVER
local estadoAnterior = "MENU"
local dificuldade = 1.0
local difNome = "NORMAL"
local volume = 1.0
local mensagemLog = ""
local mensagemLoja = ""
local rodando = true

local jogador = { 
    hp = 50, 
    maxHp = 50, 
    level = 1, 
    xp = 0, 
    ouro = 0, 
    pocoes = 3,
    danoExtra = 0
}

local inimigoAtual = nil
local eventoAtual = nil

-- =======================================================
-- SISTEMA DE AUDIO SEGURO (ANTI-CRASH)
-- =======================================================
local function tocar(som, pitch)
    if speaker then 
        pcall(function()
            speaker.playSound(som, volume, pitch or 1.0)
        end)
    end
end

-- =======================================================
-- BESTIARIO E EVENTOS (TEXTO LIMPO / ASCII)
-- =======================================================
local bestiario = {
    {nome = "Slime de Musgo", hp = 15, dano = 4, xp = 5, ouro = 5, cor = colors.lime,
     arte = {"       ", "  ___  ", " (o.o) ", " (___) "}},
    {nome = "Morcego Gigante", hp = 20, dano = 5, xp = 8, ouro = 8, cor = colors.brown,
     arte = {" ^   ^ ", " \\o_o/ ", " / | \\ ", "       "}},
    {nome = "Goblin Furioso", hp = 30, dano = 8, xp = 12, ouro = 12, cor = colors.green,
     arte = {"  ^ ^  ", " (O.O) ", " / | \\ ", "  / \\  "}},
    {nome = "Esqueleto Negro", hp = 45, dano = 12, xp = 20, ouro = 20, cor = colors.lightGray,
     arte = {"  .-.  ", " (o o) ", "  |O|  ", " /| |\\ "}},
    {nome = "Mago Corrompido", hp = 60, dano = 15, xp = 30, ouro = 35, cor = colors.purple,
     arte = {"  / \\  ", " (O_O) ", " /| |~ ", "  | |  "}},
    {nome = "Dragao Menor", hp = 120, dano = 25, xp = 60, ouro = 75, cor = colors.red,
     arte = {" \\\\ // ", " (o o) ", " /| |\\ ", "  |_|  "}}
}

local eventos = {
    {nome = "Fonte Sagrada", desc = "Voce bebeu a agua e recuperou a vida!", acao = function()
        jogador.hp = jogador.maxHp
        tocar("entity.player.levelup", 0.5)
    end, cor = colors.lightBlue},
    {nome = "Bau Escondido", desc = "Voce encontrou um bau cheio de moedas!", acao = function()
        jogador.ouro = jogador.ouro + 25
        tocar("entity.experience_orb.pickup", 1)
    end, cor = colors.yellow},
    {nome = "Armadilha de Espinhos", desc = "Voce pisou em falso e tomou dano!", acao = function()
        jogador.hp = math.max(1, jogador.hp - 10)
        tocar("entity.player.hurt", 1)
    end, cor = colors.red}
}

-- =======================================================
-- UTILITARIOS VISUAIS
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

local function desenharBotao(x, y, larg, texto, corFundo, corTexto)
    desenharCaixa(x, y, larg, 3, corFundo)
    mon.setCursorPos(x + math.floor((larg - #texto)/2), y + 1)
    mon.setTextColor(corTexto)
    mon.write(texto)
end

-- =======================================================
-- TELAS DO JOGO
-- =======================================================
local function desenharMenu()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    centralizar(2, " === DUNGEON CC DELUXE === ", colors.yellow, colors.gray)
    centralizar(4, "RPG de Combate e Exploracao", colors.lightGray, colors.black)
    
    desenharBotao(math.floor(larg/2) - 10, 6, 20, "INICIAR JOGO", colors.lime, colors.black)
    desenharBotao(math.floor(larg/2) - 10, 10, 20, "LOJA DE ITENS", colors.yellow, colors.black)
    desenharBotao(math.floor(larg/2) - 10, 14, 20, "CONFIGURACOES", colors.blue, colors.white)
end

local function desenharConfig()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    centralizar(2, " === CONFIGURACOES === ", colors.cyan, colors.gray)
    centralizar(6, "DIFICULDADE ATUAL: " .. difNome, colors.white, colors.black)
    
    desenharBotao(math.floor(larg/2) - 20, 8, 12, "FACIL", colors.lime, colors.black)
    desenharBotao(math.floor(larg/2) - 6, 8, 12, "NORMAL", colors.yellow, colors.black)
    desenharBotao(math.floor(larg/2) + 8, 8, 12, "DIFICIL", colors.red, colors.white)
    
    desenharBotao(math.floor(larg/2) - 10, 15, 20, "VOLTAR", colors.gray, colors.white)
end

local function desenharLoja()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    centralizar(1, " === MERCADOR DA MHM === ", colors.yellow, colors.gray)
    centralizar(2, "Seu Ouro: " .. jogador.ouro .. " moedas", colors.lime, colors.black)
    
    if mensagemLoja ~= "" then
        centralizar(4, mensagemLoja, colors.cyan, colors.black)
    end
    
    -- Itens da Loja (Linhas de botões)
    desenharBotao(2, 6, 24, "POCAO (+1) - 15 Ouro", colors.gray, colors.white)
    desenharBotao(28, 6, 24, "ESPADA (+5 Dano) - 30", colors.gray, colors.white)
    
    desenharBotao(2, 10, 24, "ARMADURA (+15 HP) - 40", colors.gray, colors.white)
    desenharBotao(28, 10, 24, "ELIXIR (+25 XP) - 50", colors.gray, colors.white)
    
    desenharBotao(math.floor(larg/2) - 10, 15, 20, "VOLTAR AO JOGO", colors.blue, colors.white)
end

local function desenharPause()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    centralizar(5, " === JOGO PAUSADO === ", colors.yellow, colors.gray)
    
    desenharBotao(math.floor(larg/2) - 10, 9, 20, "CONTINUAR", colors.lime, colors.black)
    desenharBotao(math.floor(larg/2) - 10, 14, 20, "ABANDONAR RUN", colors.red, colors.white)
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    -- Status do Jogador
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.blue)
    mon.write(string.rep(" ", larg))
    local txtStatus = string.format(" HP:%d/%d | LVL:%d | XP:%d | OURO:%d ", jogador.hp, jogador.maxHp, jogador.level, jogador.xp, jogador.ouro)
    mon.setCursorPos(2, 1)
    mon.setTextColor(colors.white)
    mon.write(txtStatus)
    
    -- Botao PAUSE
    mon.setCursorPos(larg - 5, 1)
    mon.setBackgroundColor(colors.red)
    mon.write(" [||] ")

    -- Inimigo
    desenharCaixa(2, 3, 20, 7, colors.gray)
    if inimigoAtual then
        mon.setCursorPos(3, 4)
        mon.setTextColor(inimigoAtual.cor)
        mon.setBackgroundColor(colors.gray)
        mon.write(inimigoAtual.nome)
        
        mon.setCursorPos(3, 5)
        mon.setTextColor(colors.red)
        mon.write("HP: " .. inimigoAtual.hp .. "/" .. math.floor(inimigoAtual.maxHp * dificuldade))
        
        for i, linha in ipairs(inimigoAtual.arte) do
            mon.setCursorPos(8, 5 + i)
            mon.setTextColor(inimigoAtual.cor)
            mon.write(linha)
        end
    end

    -- Diario de Batalha
    desenharCaixa(24, 3, larg - 25, 7, colors.black)
    mon.setCursorPos(24, 3)
    mon.setTextColor(colors.yellow)
    mon.setBackgroundColor(colors.black)
    mon.write(">> LOG DE BATALHA:")
    mon.setCursorPos(24, 5)
    mon.setTextColor(colors.white)
    mon.write(mensagemLog)

    -- Botoes de Acao
    desenharBotao(2, 13, 11, "ATACAR", colors.red, colors.white)
    desenharBotao(14, 13, 13, "CURA (" .. jogador.pocoes .. ")", colors.lime, colors.black)
    desenharBotao(28, 13, 11, "LOJA", colors.yellow, colors.black)
    desenharBotao(40, 13, 11, "FUGIR", colors.orange, colors.white)
end

local function desenharEvento()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    desenharCaixa(math.floor(larg/2) - 20, 4, 40, 8, colors.gray)
    centralizar(5, " === EVENTO ENCONTRADO === ", colors.yellow, colors.gray)
    centralizar(7, eventoAtual.nome, eventoAtual.cor, colors.gray)
    centralizar(9, eventoAtual.desc, colors.white, colors.gray)
    
    desenharBotao(math.floor(larg/2) - 10, 14, 20, "CONTINUAR", colors.lime, colors.black)
end

local function desenharGameOver()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    centralizar(6, " === VOCE MORREU === ", colors.red, colors.black)
    centralizar(8, "Seu Ouro Final: " .. jogador.ouro .. " | Level: " .. jogador.level, colors.gray, colors.black)
    desenharBotao(math.floor(larg/2) - 10, 12, 20, "MENU PRINCIPAL", colors.blue, colors.white)
end

local function atualizarTela()
    mon.setTextScale(1)
    if ESTADO == "MENU" then desenharMenu()
    elseif ESTADO == "CONFIG" then desenharConfig()
    elseif ESTADO == "LOJA" then desenharLoja()
    elseif ESTADO == "BATALHA" then desenharBatalha()
    elseif ESTADO == "EVENTO" then desenharEvento()
    elseif ESTADO == "PAUSE" then desenharPause()
    elseif ESTADO == "GAMEOVER" then desenharGameOver()
    end
end

-- =======================================================
-- REGRAS E LOGICA DO JOGO
-- =======================================================
local function resetarJogador()
    jogador = { hp = 50, maxHp = 50, level = 1, xp = 0, ouro = 0, pocoes = 3, danoExtra = 0 }
end

local function gerarEncontro()
    if math.random(1, 5) == 1 then
        eventoAtual = eventos[math.random(1, #eventos)]
        eventoAtual.acao()
        ESTADO = "EVENTO"
    else
        local maxIndex = math.min(jogador.level, #bestiario)
        local template = bestiario[math.random(1, maxIndex)]
        inimigoAtual = {
            nome = template.nome,
            maxHp = template.maxHp,
            hp = math.floor(template.maxHp * dificuldade),
            dano = math.floor(template.dano * dificuldade),
            xp = template.xp,
            ouro = template.ouro,
            cor = template.cor,
            arte = template.arte
        }
        mensagemLog = "Um " .. inimigoAtual.nome .. " apareceu!"
        ESTADO = "BATALHA"
        tocar("entity.zombie.ambient", 0.8)
    end
    atualizarTela()
end

local function turnoInimigo()
    if inimigoAtual and inimigoAtual.hp > 0 then
        local dano = math.random(math.floor(inimigoAtual.dano / 2), inimigoAtual.dano)
        jogador.hp = jogador.hp - dano
        mensagemLog = inimigoAtual.nome .. " causou " .. dano .. " de dano!"
        tocar("entity.player.hurt", 1)
        
        if jogador.hp <= 0 then
            jogador.hp = 0
            ESTADO = "GAMEOVER"
            tocar("entity.wither.death", 0.5)
        end
    end
end

local function processarCombate()
    tocar("entity.player.attack.sweep", 1.2)
    local danoBase = math.random(5 + (jogador.level * 2), 10 + (jogador.level * 3))
    local danoTotal = danoBase + jogador.danoExtra
    
    inimigoAtual.hp = inimigoAtual.hp - danoTotal
    
    if inimigoAtual.hp <= 0 then
        inimigoAtual.hp = 0
        mensagemLog = "Derrotou " .. inimigoAtual.nome .. "! (+" .. inimigoAtual.xp .. "XP)"
        jogador.xp = jogador.xp + inimigoAtual.xp
        jogador.ouro = jogador.ouro + inimigoAtual.ouro
        tocar("entity.experience_orb.pickup", 1.5)
        
        if math.random(1, 4) == 1 then
            jogador.pocoes = jogador.pocoes + 1
            mensagemLog = mensagemLog .. " Dropou 1 Pocao!"
        end
        
        atualizarTela()
        os.sleep(1.2)
        
        local xpNecessario = jogador.level * 20
        if jogador.xp >= xpNecessario then
            jogador.level = jogador.level + 1
            jogador.xp = jogador.xp - xpNecessario
            jogador.maxHp = jogador.maxHp + 10
            jogador.hp = jogador.maxHp
            mensagemLog = "LEVEL UP! HP Restaurado."
            tocar("ui.toast.challenge_complete", 1)
            atualizarTela()
            os.sleep(1.5)
        end
        gerarEncontro()
    else
        mensagemLog = "Voce causou " .. danoTotal .. " de dano!"
        atualizarTela()
        os.sleep(0.8)
        turnoInimigo()
        atualizarTela()
    end
end

-- =======================================================
-- GERENCIADOR DE TOQUE E LOOP PRINCIPAL
-- =======================================================
atualizarTela()

while rodando do
    local ev, side, x, y = os.pullEvent("monitor_touch")
    local larg, alt = mon.getSize()
    
    if ESTADO == "MENU" then
        if y >= 6 and y <= 8 then resetarJogador(); gerarEncontro()
        elseif y >= 10 and y <= 12 then estadoAnterior = "MENU"; mensagemLoja = ""; ESTADO = "LOJA"; atualizarTela()
        elseif y >= 14 and y <= 16 then ESTADO = "CONFIG"; atualizarTela()
        end

    elseif ESTADO == "CONFIG" then
        if y >= 8 and y <= 10 then
            if x >= math.floor(larg/2)-20 and x <= math.floor(larg/2)-8 then dificuldade = 0.5; difNome = "FACIL"
            elseif x >= math.floor(larg/2)-6 and x <= math.floor(larg/2)+6 then dificuldade = 1.0; difNome = "NORMAL"
            elseif x >= math.floor(larg/2)+8 and x <= math.floor(larg/2)+20 then dificuldade = 1.5; difNome = "DIFICIL"
            end
            tocar("ui.button.click", 1)
            atualizarTela()
        elseif y >= 15 and y <= 17 then
            ESTADO = "MENU"; atualizarTela()
        end

    elseif ESTADO == "LOJA" then
        if y >= 6 and y <= 8 then
            if x >= 2 and x <= 26 then
                if jogador.ouro >= 15 then
                    jogador.ouro = jogador.ouro - 15
                    jogador.pocoes = jogador.pocoes + 1
                    mensagemLoja = "Comprou 1 Pocao de Cura!"
                    tocar("entity.experience_orb.pickup", 1)
                else mensagemLoja = "Ouro insuficiente!" end
            elseif x >= 28 and x <= 52 then
                if jogador.ouro >= 30 then
                    jogador.ouro = jogador.ouro - 30
                    jogador.danoExtra = jogador.danoExtra + 5
                    mensagemLoja = "Comprou Espada! (+5 Dano)"
                    tocar("entity.experience_orb.pickup", 1)
                else mensagemLoja = "Ouro insuficiente!" end
            end
            atualizarTela()
        elseif y >= 10 and y <= 12 then
            if x >= 2 and x <= 26 then
                if jogador.ouro >= 40 then
                    jogador.ouro = jogador.ouro - 40
                    jogador.maxHp = jogador.maxHp + 15
                    jogador.hp = jogador.hp + 15
                    mensagemLoja = "Comprou Armadura! (+15 HP)"
                    tocar("entity.experience_orb.pickup", 1)
                else mensagemLoja = "Ouro insuficiente!" end
            elseif x >= 28 and x <= 52 then
                if jogador.ouro >= 50 then
                    jogador.ouro = jogador.ouro - 50
                    jogador.xp = jogador.xp + 25
                    mensagemLoja = "Bebeu Elixir! (+25 XP)"
                    tocar("entity.experience_orb.pickup", 1)
                else mensagemLoja = "Ouro insuficiente!" end
            end
            atualizarTela()
        elseif y >= 15 and y <= 17 then
            ESTADO = estadoAnterior
            atualizarTela()
        end

    elseif ESTADO == "BATALHA" then
        if y == 1 and x >= larg - 6 then
            ESTADO = "PAUSE"; tocar("ui.button.click", 1); atualizarTela()
        elseif y >= 13 and y <= 15 then
            if x >= 2 and x <= 12 then
                processarCombate()
            elseif x >= 14 and x <= 26 then
                if jogador.pocoes > 0 and jogador.hp < jogador.maxHp then
                    jogador.pocoes = jogador.pocoes - 1
                    local cura = 20 + (jogador.level * 5)
                    jogador.hp = math.min(jogador.maxHp, jogador.hp + cura)
                    mensagemLog = "Curou " .. cura .. " HP!"
                    tocar("entity.generic.drink", 1)
                    atualizarTela()
                    os.sleep(0.8)
                    turnoInimigo()
                    atualizarTela()
                else
                    mensagemLog = "HP cheio ou sem pocoes!"
                    atualizarTela()
                end
            elseif x >= 28 and x <= 38 then
                estadoAnterior = "BATALHA"
                mensagemLoja = ""
                ESTADO = "LOJA"
                atualizarTela()
            elseif x >= 40 and x <= 51 then
                if math.random(1, 2) == 1 then
                    mensagemLog = "Fugiu com sucesso!"
                    tocar("entity.player.breath", 1)
                    atualizarTela(); os.sleep(1)
                    gerarEncontro()
                else
                    mensagemLog = "Falha ao fugir!"
                    tocar("entity.villager.no", 1)
                    atualizarTela(); os.sleep(0.8)
                    turnoInimigo(); atualizarTela()
                end
            end
        end

    elseif ESTADO == "EVENTO" then
        if y >= 14 and y <= 16 then
            gerarEncontro()
        end

    elseif ESTADO == "PAUSE" then
        if y >= 9 and y <= 11 then
            ESTADO = "BATALHA"; tocar("ui.button.click", 1); atualizarTela()
        elseif y >= 14 and y <= 16 then
            ESTADO = "MENU"; tocar("ui.button.click", 1); atualizarTela()
        end
        
    elseif ESTADO == "GAMEOVER" then
        if y >= 12 and y <= 14 then
            ESTADO = "MENU"; atualizarTela()
        end
    end
end
