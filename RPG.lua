-- =======================================================
-- SETUP E PERIFERICOS
-- =======================================================
local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not mon then 
    print("[ERRO] Monitor nao encontrado!") 
    return 
end

-- =======================================================
-- ESTADO GLOBAL E SAVE
-- =======================================================
local ESTADO = "MENU"
local estadoAnterior = "MENU"
local volume = 1.0
local mensagemLog = "Bem-vindo a Pilgramo!"
local rodando = true

local jogador = { 
    hp = 50, maxHp = 50, tp = 0, level = 1, xp = 0, 
    ouro = 0, pocoes = 3, pocoesMax = 0, 
    danoExtra = 0, defesa = 0, magiaExtra = 0,
    bossesMortos = {}
}

local inimigoAtual = nil

math.randomseed(os.time())
local ARQUIVO_SAVE = "pilgramo_save.json"

local function salvarJogo()
    local f = fs.open(ARQUIVO_SAVE, "w")
    f.write(textutils.serialize(jogador))
    f.close()
end

local function carregarJogo()
    if fs.exists(ARQUIVO_SAVE) then
        local f = fs.open(ARQUIVO_SAVE, "r")
        local dados = f.readAll()
        f.close()
        if dados then
            jogador = textutils.unserialize(dados)
            jogador.tp = 0 
            jogador.defesa = jogador.defesa or 0
            jogador.magiaExtra = jogador.magiaExtra or 0
            jogador.pocoesMax = jogador.pocoesMax or 0
            jogador.bossesMortos = jogador.bossesMortos or {}
            return true
        end
    end
    return false
end

-- =======================================================
-- AUDIO E BGM
-- =======================================================
local function tocar(som, pitch)
    if speaker then pcall(function() speaker.playSound(som, volume, pitch or 1.0) end) end
end

local function loopMusica()
    while rodando do
        if speaker and (ESTADO == "MENU" or ESTADO == "BATALHA") then
            -- Tenta tocar o disco de forma forçada com volume alto
            pcall(function() speaker.playSound("music_disc.stal", 3.0, 1.0) end)
        end
        os.sleep(150) -- Stal tem cerca de 2:30 de duração
    end
end

-- Toca um BEEP de teste ao iniciar
tocar("entity.player.levelup", 2.0)

-- =======================================================
-- BESTIARIO E BOSSES
-- =======================================================
local bestiario = {
    {nome = "Slime de Musgo", maxHp = 20, dano = 4, xp = 5, ouro = 5, cor = colors.lime, arte = {"       ", "  ___  ", " (o.o) ", " (___) "}},
    {nome = "Lobo Selvagem", maxHp = 35, dano = 6, xp = 10, ouro = 8, cor = colors.lightGray, arte = {"       ", " / \\__ ", " (o.o )", "  / /  "}},
    {nome = "Goblin Ladrao", maxHp = 50, dano = 8, xp = 15, ouro = 15, cor = colors.green, arte = {"  ^ ^  ", " (O.O) ", " / | \\ ", "  / \\  "}},
    {nome = "Esqueleto Negro", maxHp = 80, dano = 12, xp = 25, ouro = 20, cor = colors.white, arte = {"  .-.  ", " (o o) ", "  |O|  ", " /| |\\ "}},
    {nome = "Cavaleiro Caido", maxHp = 120, dano = 18, xp = 40, ouro = 35, cor = colors.gray, arte = {"  _|_  ", " [o o] ", " /[|]\\ ", "  / \\  "}}
}

local chefes = {
    [5] = {nome = "REI SLIME", maxHp = 250, dano = 20, xp = 100, ouro = 100, cor = colors.lime, arte = {"   _^_   ", "  /   \\  ", " | O_O | ", "  \\___/  "}},
    [10] = {nome = "LORDE VAMPIRO", maxHp = 500, dano = 35, xp = 300, ouro = 250, cor = colors.red, arte = {" \\_v_v_/ ", "  (o o)  ", "  /| |\\  ", "  /   \\  "}},
    [15] = {nome = "DRAGAO DO FIM", maxHp = 1000, dano = 50, xp = 1000, ouro = 800, cor = colors.purple, arte = {" \\ ||| / ", "  (O_O)  ", " /|   |\\ ", "  |___|  "}}
}

-- =======================================================
-- UTILITARIOS VISUAIS
-- =======================================================
local function centralizar(y, texto, corTexto, corFundo)
    local larg, _ = mon.getSize()
    local x = math.floor((larg - #texto) / 2) + 1
    mon.setCursorPos(math.max(1, x), y)
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

local function desenharBarra(x, y, larg, valor, maxValor, corBarra)
    mon.setCursorPos(x, y)
    mon.setBackgroundColor(colors.gray)
    mon.write(string.rep(" ", larg))
    local preenchido = math.floor((valor / maxValor) * larg)
    if preenchido > 0 then
        mon.setCursorPos(x, y)
        mon.setBackgroundColor(corBarra)
        mon.write(string.rep(" ", preenchido))
    end
    mon.setBackgroundColor(colors.black)
end

-- =======================================================
-- TELAS DO JOGO
-- =======================================================
local function desenharMenu()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, _ = mon.getSize()
    
    centralizar(3, "--- P I L G R A M O ---", colors.yellow, colors.black)
    centralizar(5, "A Lenda dos Chefes", colors.lightGray, colors.black)
    
    if fs.exists(ARQUIVO_SAVE) then
        desenharBotao(math.floor(larg/2) - 10, 8, 20, "CONTINUAR JOGO", colors.cyan, colors.black)
        desenharBotao(math.floor(larg/2) - 10, 12, 20, "NOVO JOGO", colors.lime, colors.black)
    else
        desenharBotao(math.floor(larg/2) - 10, 10, 20, "NOVO JOGO", colors.lime, colors.black)
    end
end

local function desenharLoja()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, _ = mon.getSize()
    
    centralizar(1, "--- MERCADOR SECRETO ---", colors.yellow, colors.black)
    centralizar(3, "Ouro: " .. jogador.ouro .. " | Def: " .. jogador.defesa .. " | Dano Extra: +" .. jogador.danoExtra .. " | Magia: +" .. jogador.magiaExtra, colors.lime, colors.black)
    
    -- 6 Itens na Loja (Grid 2x3)
    desenharBotao(2, 5, 26, "POCAO (+25HP) - 15G", colors.gray, colors.white)
    desenharBotao(30, 5, 26, "SUPER POCAO (+50HP) - 30G", colors.gray, colors.white)
    
    desenharBotao(2, 9, 26, "ESPADA (+5 Dano) - 40G", colors.gray, colors.white)
    desenharBotao(30, 9, 26, "ESCUDO (+2 Def) - 40G", colors.gray, colors.white)
    
    desenharBotao(2, 13, 26, "ARMADURA (+20 HP) - 50G", colors.gray, colors.white)
    desenharBotao(30, 13, 26, "ANEL MAGIA (+10 Mag) - 60G", colors.gray, colors.white)
    
    desenharBotao(math.floor(larg/2) - 10, 17, 20, "VOLTAR AO JOGO", colors.blue, colors.white)
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    mon.setCursorPos(1, 1)
    mon.setBackgroundColor(colors.blue)
    mon.write(string.rep(" ", larg))
    local txtStatus = string.format(" LVL:%d | XP:%d | OURO:%d ", jogador.level, jogador.xp, jogador.ouro)
    mon.setCursorPos(2, 1)
    mon.setTextColor(colors.white)
    mon.write(txtStatus)

    mon.setCursorPos(larg - 7, 1)
    mon.setBackgroundColor(colors.red)
    mon.write(" [LOJA] ")

    if inimigoAtual then
        mon.setCursorPos(3, 3)
        mon.setTextColor(inimigoAtual.cor)
        mon.write(inimigoAtual.nome)
        
        desenharBarra(3, 4, 15, inimigoAtual.hp, inimigoAtual.maxHp, colors.red)
        
        for i, linha in ipairs(inimigoAtual.arte) do
            mon.setCursorPos(5, 5 + i)
            mon.setTextColor(inimigoAtual.cor)
            mon.write(linha)
        end
    end

    mon.setCursorPos(30, 3)
    mon.setTextColor(colors.cyan)
    mon.write("PILGRAMO")
    
    mon.setCursorPos(30, 5)
    mon.setTextColor(colors.white)
    mon.write(string.format("HP: %3d / %3d", jogador.hp, jogador.maxHp))
    desenharBarra(30, 6, 20, jogador.hp, jogador.maxHp, colors.lime)
    
    mon.setCursorPos(30, 8)
    mon.write(string.format("TP: %3d %%", jogador.tp))
    desenharBarra(30, 9, 20, jogador.tp, 100, colors.orange)

    desenharCaixa(2, 12, larg - 3, 3, colors.gray)
    mon.setCursorPos(4, 13)
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.gray)
    mon.write("* " .. mensagemLog)

    mon.setBackgroundColor(colors.black)
    
    if ESTADO == "BATALHA" then
        desenharBotao(2, 16, 12, "[ ATACAR ]", colors.red, colors.white)
        desenharBotao(16, 16, 12, "[ MAGIA ]", colors.purple, colors.white)
        desenharBotao(30, 16, 12, "[ ITENS ]", colors.lime, colors.black)
        desenharBotao(44, 16, 12, "[ POUPAR ]", colors.yellow, colors.black)
    elseif ESTADO == "SUBMENU_MAGIA" then
        desenharBotao(2, 16, 20, "CURA (40 TP)", colors.lime, colors.black)
        desenharBotao(24, 16, 20, "RAIO (50 TP)", colors.cyan, colors.black)
        desenharBotao(46, 16, 10, "VOLTAR", colors.gray, colors.white)
    elseif ESTADO == "SUBMENU_ITEM" then
        desenharBotao(2, 16, 24, "POCAO (" .. (jogador.pocoes + jogador.pocoesMax) .. "x)", colors.lime, colors.black)
        desenharBotao(28, 16, 10, "VOLTAR", colors.gray, colors.white)
    end
end

local function atualizarTela()
    mon.setTextScale(1)
    if ESTADO == "MENU" then desenharMenu()
    elseif ESTADO == "LOJA" then desenharLoja()
    elseif ESTADO == "BATALHA" or ESTADO == "SUBMENU_MAGIA" or ESTADO == "SUBMENU_ITEM" then desenharBatalha()
    end
end

-- =======================================================
-- LOGICA DE COMBATE E CHEFES
-- =======================================================
local function ganharTP(valor)
    jogador.tp = math.min(100, jogador.tp + valor)
end

local function gerarEncontro()
    salvarJogo()
    
    -- Verifica se é hora do CHEFE
    if chefes[jogador.level] and not jogador.bossesMortos[jogador.level] then
        local boss = chefes[jogador.level]
        inimigoAtual = {
            nome = boss.nome, maxHp = boss.maxHp, hp = boss.maxHp,
            dano = boss.dano, xp = boss.xp, ouro = boss.ouro, 
            cor = boss.cor, arte = boss.arte, isBoss = true
        }
        mensagemLog = "CUIDADO! " .. boss.nome .. " APARECEU!"
        tocar("entity.ender_dragon.growl", 1.0)
    else
        local maxIndex = math.min(jogador.level, #bestiario)
        local template = bestiario[math.random(1, maxIndex)]
        inimigoAtual = {
            nome = template.nome, maxHp = template.maxHp, hp = template.maxHp,
            dano = template.dano, xp = template.xp, ouro = template.ouro, 
            cor = template.cor, arte = template.arte, isBoss = false
        }
        mensagemLog = inimigoAtual.nome .. " ataca!"
    end
    
    ESTADO = "BATALHA"
    atualizarTela()
end

local function turnoInimigo()
    if inimigoAtual and inimigoAtual.hp > 0 then
        local dano = math.random(math.floor(inimigoAtual.dano / 2), inimigoAtual.dano)
        local danoReal = math.max(1, dano - jogador.defesa)
        
        jogador.hp = math.max(0, jogador.hp - danoReal)
        ganharTP(15)
        mensagemLog = inimigoAtual.nome .. " causou " .. danoReal .. " de dano!"
        tocar("entity.player.hurt", 1)
        
        if jogador.hp <= 0 then
            jogador.hp = 0; ESTADO = "MENU"; fs.delete(ARQUIVO_SAVE)
            tocar("entity.wither.death", 0.5)
        end
    end
end

local function vitoria()
    if inimigoAtual.isBoss then
        jogador.bossesMortos[jogador.level] = true
        mensagemLog = "CHEFE DERROTADO! +" .. inimigoAtual.xp .. "XP e " .. inimigoAtual.ouro .. " Ouro."
        tocar("ui.toast.challenge_complete", 1)
    else
        mensagemLog = "Voce venceu! +" .. inimigoAtual.xp .. "XP e " .. inimigoAtual.ouro .. " Ouro."
        tocar("entity.experience_orb.pickup", 1.5)
    end
    
    jogador.xp = jogador.xp + inimigoAtual.xp
    jogador.ouro = jogador.ouro + inimigoAtual.ouro
    atualizarTela(); os.sleep(2.0)
    
    local xpMax = jogador.level * 20
    if jogador.xp >= xpMax then
        jogador.xp = jogador.xp - xpMax
        jogador.level = jogador.level + 1
        jogador.maxHp = jogador.maxHp + 10
        jogador.hp = jogador.maxHp
        mensagemLog = "LEVEL UP! Voce esta mais forte."
        tocar("entity.player.levelup", 1)
        atualizarTela(); os.sleep(1.5)
    end
    gerarEncontro()
end

-- =======================================================
-- LOOP DE TOQUE (TOUCH EVENTS)
-- =======================================================
local function loopJogo()
    atualizarTela()
    while rodando do
        local ev, _, x, y = os.pullEvent("monitor_touch")
        local larg, _ = mon.getSize()
        
        if ESTADO == "MENU" then
            local temSave = fs.exists(ARQUIVO_SAVE)
            if temSave and y >= 8 and y <= 10 then
                carregarJogo(); gerarEncontro()
            elseif (not temSave and y >= 10 and y <= 12) or (temSave and y >= 12 and y <= 14) then
                jogador = {hp=50, maxHp=50, tp=0, level=1, xp=0, ouro=0, pocoes=3, pocoesMax=0, danoExtra=0, defesa=0, magiaExtra=0, bossesMortos={}}
                gerarEncontro()
            end

        elseif ESTADO == "LOJA" then
            if y >= 5 and y <= 7 then
                if x >= 2 and x <= 28 and jogador.ouro >= 15 then
                    jogador.ouro = jogador.ouro - 15; jogador.pocoes = jogador.pocoes + 1
                    tocar("entity.experience_orb.pickup", 1)
                elseif x >= 30 and jogador.ouro >= 30 then
                    jogador.ouro = jogador.ouro - 30; jogador.pocoesMax = jogador.pocoesMax + 1
                    tocar("entity.experience_orb.pickup", 1)
                end
            elseif y >= 9 and y <= 11 then
                if x >= 2 and x <= 28 and jogador.ouro >= 40 then
                    jogador.ouro = jogador.ouro - 40; jogador.danoExtra = jogador.danoExtra + 5
                    tocar("item.armor.equip_iron", 1)
                elseif x >= 30 and jogador.ouro >= 40 then
                    jogador.ouro = jogador.ouro - 40; jogador.defesa = jogador.defesa + 2
                    tocar("item.shield.equip", 1)
                end
            elseif y >= 13 and y <= 15 then
                if x >= 2 and x <= 28 and jogador.ouro >= 50 then
                    jogador.ouro = jogador.ouro - 50; jogador.maxHp = jogador.maxHp + 20; jogador.hp = jogador.hp + 20
                    tocar("item.armor.equip_diamond", 1)
                elseif x >= 30 and jogador.ouro >= 60 then
                    jogador.ouro = jogador.ouro - 60; jogador.magiaExtra = jogador.magiaExtra + 10
                    tocar("block.amethyst_block.chime", 1)
                end
            elseif y >= 17 and y <= 19 then
                salvarJogo(); ESTADO = estadoAnterior
            end
            atualizarTela()

        elseif ESTADO == "BATALHA" or ESTADO == "SUBMENU_MAGIA" or ESTADO == "SUBMENU_ITEM" then
            if y == 1 and x >= larg - 7 then
                estadoAnterior = "BATALHA"; ESTADO = "LOJA"; atualizarTela()
            elseif y >= 16 and y <= 18 then
                
                if ESTADO == "BATALHA" then
                    if x >= 2 and x <= 14 then
                        tocar("entity.player.attack.sweep", 1.2)
                        ganharTP(15)
                        local dano = math.random(5 + (jogador.level*2), 10 + (jogador.level*3)) + jogador.danoExtra
                        inimigoAtual.hp = inimigoAtual.hp - dano
                        mensagemLog = "Atacou causando " .. dano .. " de dano!"
                        atualizarTela(); os.sleep(1)
                        if inimigoAtual.hp <= 0 then vitoria() else turnoInimigo(); atualizarTela() end
                    
                    elseif x >= 16 and x <= 28 then
                        ESTADO = "SUBMENU_MAGIA"; atualizarTela()
                    
                    elseif x >= 30 and x <= 42 then
                        ESTADO = "SUBMENU_ITEM"; atualizarTela()
                    
                    elseif x >= 44 and x <= 56 then
                        if inimigoAtual.isBoss then
                            mensagemLog = "Voce nao pode poupar um CHEFE!"
                            tocar("entity.villager.no", 1)
                            atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                        elseif inimigoAtual.hp <= (inimigoAtual.maxHp * 0.2) then
                            mensagemLog = "Voce poupou o inimigo!"
                            atualizarTela(); os.sleep(1); vitoria()
                        else
                            if math.random(1, 2) == 1 then
                                mensagemLog = "Fugiu com sucesso!"
                                atualizarTela(); os.sleep(1); gerarEncontro()
                            else
                                mensagemLog = "O inimigo bloqueou a fuga!"
                                atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                            end
                        end
                    end
                
                elseif ESTADO == "SUBMENU_MAGIA" then
                    if x >= 2 and x <= 22 then
                        if jogador.tp >= 40 then
                            jogador.tp = jogador.tp - 40
                            jogador.hp = math.min(jogador.maxHp, jogador.hp + 40)
                            mensagemLog = "Magia de Cura! (+40 HP)"
                            tocar("entity.generic.drink", 1)
                            ESTADO = "BATALHA"; atualizarTela(); os.sleep(1)
                            turnoInimigo(); atualizarTela()
                        else mensagemLog = "TP Insuficiente para Cura!"; atualizarTela() end
                    elseif x >= 24 and x <= 44 then
                        if jogador.tp >= 50 then
                            jogador.tp = jogador.tp - 50
                            local dano = 30 + (jogador.level * 5) + jogador.magiaExtra
                            inimigoAtual.hp = inimigoAtual.hp - dano
                            mensagemLog = "Magia de Raio! (" .. dano .. " Dano)"
                            tocar("entity.lightning_bolt.thunder", 1)
                            ESTADO = "BATALHA"; atualizarTela(); os.sleep(1)
                            if inimigoAtual.hp <= 0 then vitoria() else turnoInimigo(); atualizarTela() end
                        else mensagemLog = "TP Insuficiente para Raio!"; atualizarTela() end
                    elseif x >= 46 then
                        ESTADO = "BATALHA"; atualizarTela()
                    end
                
                elseif ESTADO == "SUBMENU_ITEM" then
                    if x >= 2 and x <= 26 then
                        if jogador.pocoes > 0 or jogador.pocoesMax > 0 then
                            if jogador.pocoesMax > 0 then
                                jogador.pocoesMax = jogador.pocoesMax - 1
                                jogador.hp = math.min(jogador.maxHp, jogador.hp + 50)
                            else
                                jogador.pocoes = jogador.pocoes - 1
                                jogador.hp = math.min(jogador.maxHp, jogador.hp + 25)
                            end
                            mensagemLog = "Usou pocao e recuperou HP!"
                            tocar("entity.generic.drink", 1)
                            ESTADO = "BATALHA"; atualizarTela(); os.sleep(1)
                            turnoInimigo(); atualizarTela()
                        else mensagemLog = "Voce nao tem pocoes!"; atualizarTela() end
                    elseif x >= 28 then
                        ESTADO = "BATALHA"; atualizarTela()
                    end
                end
            end
        end
    end
end

print("Jogo rodando! Aperte Q aqui para desligar.")
local function escutarSaida()
    while rodando do
        local _, p1 = os.pullEvent("key")
        if p1 == keys.q then
            rodando = false
            mon.setBackgroundColor(colors.black); mon.clear()
        end
    end
end

local sucesso, erro = pcall(function()
    parallel.waitForAny(escutarSaida, loopJogo, loopMusica)
end)

if not sucesso then
    term.clear()
    term.setCursorPos(1,1)
    print("Ocorreu um erro no codigo:")
    print(erro)
end
