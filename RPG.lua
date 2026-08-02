-- =======================================================
-- ⚙️ SETUP E PERIFÉRICOS
-- =======================================================
local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not mon then 
    print("❌ Erro: Monitor não encontrado!") 
    return 
end

-- =======================================================
-- 🎮 ESTADO GLOBAL DO JOGO
-- =======================================================
local ESTADO = "MENU" -- MENU, CONFIG, BATALHA, EVENTO, PAUSE, GAMEOVER
local dificuldade = 1.0 -- 0.5 (Fácil), 1.0 (Normal), 1.5 (Difícil)
local difNome = "NORMAL"
local volume = 1.0
local mensagemLog = ""
local rodando = true

local jogador = { hp = 50, maxHp = 50, level = 1, xp = 0, ouro = 0, pocoes = 3 }
local inimigoAtual = nil
local eventoAtual = nil

-- =======================================================
-- 🎵 SISTEMA DE ÁUDIO
-- =======================================================
local function tocar(som, pitch)
    if speaker then 
        -- Usa sons nativos do Minecraft
        speaker.playSound(som, volume, pitch or 1.0) 
    end
end

-- =======================================================
-- 👾 BESTIÁRIO E EVENTOS
-- =======================================================
local bestiario = {
    {nome = "Slime de Musgo", hp = 15, dano = 4, xp = 5, ouro = 2, cor = colors.lime,
     arte = {"       ", "  ___  ", " (o.o) ", " (___) "}},
    {nome = "Morcego Gigante", hp = 20, dano = 5, xp = 8, ouro = 3, cor = colors.brown,
     arte = {" ^   ^ ", " \\o_o/ ", " / | \\ ", "       "}},
    {nome = "Goblin Furioso", hp = 30, dano = 8, xp = 12, ouro = 5, cor = colors.green,
     arte = {"  ^ ^  ", " (O.O) ", " / | \\ ", "  / \\  "}},
    {nome = "Esqueleto Negro", hp = 45, dano = 12, xp = 20, ouro = 10, cor = colors.lightGray,
     arte = {"  .-.  ", " (o o) ", "  |O|  ", " /| |\\ "}},
    {nome = "Mago Corrompido", hp = 60, dano = 15, xp = 30, ouro = 20, cor = colors.purple,
     arte = {"  / \\  ", " (O_O) ", " /| |~ ", "  | |  "}},
    {nome = "Dragao Menor", hp = 120, dano = 25, xp = 60, ouro = 50, cor = colors.red,
     arte = {" \\\\ // ", " (o o) ", " /| |\\ ", "  |_|  "}}
}

local eventos = {
    {nome = "Fonte Sagrada", desc = "Voce bebe a agua e se sente revigorado!", acao = function()
        jogador.hp = jogador.maxHp; tocar("entity.player.levelup", 0.5)
    end, cor = colors.lightBlue},
    {nome = "Bau Escondido", desc = "Voce encontrou ouro e uma pocao!", acao = function()
        jogador.ouro = jogador.ouro + 15; jogador.pocoes = jogador.pocoes + 1; tocar("entity.experience_orb.pickup", 1)
    end, cor = colors.yellow},
    {nome = "Armadilha de Espinhos", desc = "Voce pisou em falso e tomou dano!", acao = function()
        jogador.hp = jogador.hp - 10; tocar("entity.player.hurt", 1)
    end, cor = colors.red}
}

-- =======================================================
-- 🎨 UTILITÁRIOS VISUAIS
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
-- 🖥️ TELAS DO JOGO
-- =======================================================
local function desenharMenu()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    centralizar(3, " ⚔️ DUNGEON CC DELUXE ⚔️ ", colors.yellow, colors.gray)
    centralizar(5, "Prepare-se para a aventura", colors.lightGray, colors.black)
    
    desenharBotao(math.floor(larg/2) - 10, 8, 20, "INICIAR JOGO", colors.lime, colors.black)
    desenharBotao(math.floor(larg/2) - 10, 12, 20, "CONFIGURACOES", colors.blue, colors.white)
    desenharBotao(math.floor(larg/2) - 10, 16, 20, "SAIR", colors.red, colors.white)
end

local function desenharConfig()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    centralizar(2, " ⚙️ CONFIGURACOES ⚙️ ", colors.cyan, colors.gray)
    
    -- Dificuldade
    centralizar(6, "DIFICULDADE ATUAL: " .. difNome, colors.white, colors.black)
    desenharBotao(math.floor(larg/2) - 20, 8, 12, "FACIL", colors.lime, colors.black)
    desenharBotao(math.floor(larg/2) - 6, 8, 12, "NORMAL", colors.yellow, colors.black)
    desenharBotao(math.floor(larg/2) + 8, 8, 12, "DIFICIL", colors.red, colors.white)
    
    -- Voltar
    desenharBotao(math.floor(larg/2) - 10, 15, 20, "VOLTAR AO MENU", colors.gray, colors.white)
end

local function desenharPause()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    centralizar(5, " ⏸️ JOGO PAUSADO ⏸️ ", colors.yellow, colors.gray)
    
    desenharBotao(math.floor(larg/2) - 10, 9, 20, "CONTINUAR", colors.lime, colors.black)
    desenharBotao(math.floor(larg/2) - 10, 14, 20, "ABANDONAR RUN", colors.red, colors.white)
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    -- Cabeçalho do Jogador
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.blue)
    mon.write(string.rep(" ", larg))
    local txtStatus = string.format(" ❤️ HP:%d/%d | ⭐ LVL:%d | ✨ XP:%d | 🪙 Ouro:%d ", jogador.hp, jogador.maxHp, jogador.level, jogador.xp, jogador.ouro)
    mon.setCursorPos(2, 1)
    mon.setTextColor(colors.white)
    mon.write(txtStatus)
    
    -- Botão PAUSE Superior Direito
    mon.setCursorPos(larg - 5, 1)
    mon.setBackgroundColor(colors.red)
    mon.write(" || ")

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

    -- Log
    desenharCaixa(24, 3, larg - 25, 7, colors.black)
    mon.setCursorPos(24, 3)
    mon.setTextColor(colors.yellow)
    mon.setBackgroundColor(colors.black)
    mon.write(">> DIARIO DE BATALHA:")
    mon.setCursorPos(24, 5)
    mon.setTextColor(colors.white)
    mon.write(mensagemLog)

    -- Botões
    desenharBotao(4, 13, 14, "ATACAR", colors.red, colors.white)
    desenharBotao(22, 13, 14, "CURA (" .. jogador.pocoes .. ")", colors.lime, colors.black)
    desenharBotao(40, 13, 14, "FUGIR", colors.orange, colors.white)
end

local function desenharEvento()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    desenharCaixa(math.floor(larg/2) - 20, 4, 40, 8, colors.gray)
    centralizar(5, " ❓ EVENTO ALEATORIO ❓ ", colors.yellow, colors.gray)
    centralizar(7, eventoAtual.nome, eventoAtual.cor, colors.gray)
    centralizar(9, eventoAtual.desc, colors.white, colors.gray)
    
    desenharBotao(math.floor(larg/2) - 10, 14, 20, "CONTINUAR", colors.lime, colors.black)
end

local function desenharGameOver()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    centralizar(6, " ☠️ VOCE MORREU ☠️ ", colors.red, colors.black)
    centralizar(8, "Seu ouro: " .. jogador.ouro .. " | Level: " .. jogador.level, colors.gray, colors.black)
    desenharBotao(math.floor(larg/2) - 10, 12, 20, "VOLTAR AO MENU", colors.blue, colors.white)
end

local function atualizarTela()
    mon.setTextScale(1)
    if ESTADO == "MENU" then desenharMenu()
    elseif ESTADO == "CONFIG" then desenharConfig()
    elseif ESTADO == "BATALHA" then desenharBatalha()
    elseif ESTADO == "EVENTO" then desenharEvento()
    elseif ESTADO == "PAUSE" then desenharPause()
    elseif ESTADO == "GAMEOVER" then desenharGameOver()
    end
end

-- =======================================================
-- ⚔️ REGRAS DE NEGÓCIO E MECÂNICAS
-- =======================================================
local function resetarJogador()
    jogador = { hp = 50, maxHp = 50, level = 1, xp = 0, ouro = 0, pocoes = 3 }
end

local function gerarEncontro()
    -- 20% de chance de evento, 80% de monstro
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
    if inimigoAtual.hp > 0 then
        local dano = math.random(math.floor(inimigoAtual.dano / 2), inimigoAtual.dano)
        jogador.hp = jogador.hp - dano
        mensagemLog = inimigoAtual.nome .. " causou " .. dano .. " dano!"
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
    local dano = math.random(5 + (jogador.level * 2), 10 + (jogador.level * 3))
    inimigoAtual.hp = inimigoAtual.hp - dano
    
    if inimigoAtual.hp <= 0 then
        inimigoAtual.hp = 0
        mensagemLog = "Derrotou " .. inimigoAtual.nome .. "! (+" .. inimigoAtual.xp .. "XP)"
        jogador.xp = jogador.xp + inimigoAtual.xp
        jogador.ouro = jogador.ouro + inimigoAtual.ouro
        tocar("entity.experience_orb.pickup", 1.5)
        
        if math.random(1, 4) == 1 then
            jogador.pocoes = jogador.pocoes + 1
            mensagemLog = mensagemLog .. " Drop: Pocao!"
        end
        
        atualizarTela()
        os.sleep(1.5)
        
        -- Level UP
        local xpNecessario = jogador.level * 20
        if jogador.xp >= xpNecessario then
            jogador.level = jogador.level + 1
            jogador.xp = jogador.xp - xpNecessario
            jogador.maxHp = jogador.maxHp + 10
            jogador.hp = jogador.maxHp
            mensagemLog = "LEVEL UP! HP Restaurado."
            tocar("ui.toast.challenge_complete", 1)
            atualizarTela()
            os.sleep(2)
        end
        gerarEncontro()
    else
        mensagemLog = "Voce causou " .. dano .. " de dano!"
        atualizarTela()
        os.sleep(0.8)
        turnoInimigo()
        atualizarTela()
    end
end

-- =======================================================
-- 🖱️ LOOP PRINCIPAL DE EVENTOS E TOUCH
-- =======================================================
atualizarTela()

while rodando do
    local ev, side, x, y = os.pullEvent("monitor_touch")
    local larg, alt = mon.getSize()
    
    if ESTADO == "MENU" then
        if y >= 8 and y <= 10 then resetarJogador(); gerarEncontro() -- INICIAR
        elseif y >= 12 and y <= 14 then ESTADO = "CONFIG"; atualizarTela() -- CONFIG
        elseif y >= 16 and y <= 18 then rodando = false; mon.clear() -- SAIR
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

    elseif ESTADO == "BATALHA" then
        -- Botão PAUSE
        if y == 1 and x >= larg - 5 then
            ESTADO = "PAUSE"; tocar("ui.button.click", 1); atualizarTela()
        -- Botão ATACAR
        elseif y >= 13 and y <= 15 and x >= 4 and x <= 17 then
            processarCombate()
        -- Botão CURAR
        elseif y >= 13 and y <= 15 and x >= 22 and x <= 35 then
            if jogador.pocoes > 0 and jogador.hp < jogador.maxHp then
                jogador.pocoes = jogador.pocoes - 1
                local cura = 20 + (jogador.level * 5)
                jogador.hp = math.min(jogador.maxHp, jogador.hp + cura)
                mensagemLog = "Curou " .. cura .. " HP!"
                tocar("entity.generic.drink", 1)
                atualizarTela()
                os.sleep(1)
                turnoInimigo()
                atualizarTela()
            end
        -- Botão FUGIR
        elseif y >= 13 and y <= 15 and x >= 40 and x <= 53 then
            if math.random(1, 2) == 1 then
                mensagemLog = "Fugiu com sucesso!"
                tocar("entity.player.breath", 1)
                atualizarTela(); os.sleep(1)
                gerarEncontro()
            else
                mensagemLog = "Falha ao fugir!"
                tocar("entity.villager.no", 1)
                atualizarTela(); os.sleep(1)
                turnoInimigo(); atualizarTela()
            end
        end

    elseif ESTADO == "EVENTO" then
        if y >= 14 and y <= 16 and x >= math.floor(larg/2)-10 and x <= math.floor(larg/2)+10 then
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
