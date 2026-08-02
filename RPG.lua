-- =======================================================
-- SETUP E PERIFERICOS
-- =======================================================
local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not mon then print("[ERRO] Monitor nao encontrado!") return end

-- =======================================================
-- ESTADO GLOBAL E SAVE
-- =======================================================
local ESTADO = "MENU" -- MENU, MAPA, LOJA, BATALHA, SUBMENU_MAGIA, SUBMENU_ITEM
local volume = 1.0
local mensagemLog = "Prepare-se para a batalha!"
local rodando = true

local jogador = { 
    hp = 50, maxHp = 50, tp = 0, level = 1, xp = 0, 
    ouro = 0, pocoes = 3, pocoesMax = 0, 
    danoExtra = 0, defesa = 0, magiaExtra = 0,
    zona = 1, nodo = 1 -- NOVO: Progresso do Mapa
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
            jogador.zona = jogador.zona or 1
            jogador.nodo = jogador.nodo or 1
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
        if speaker and (ESTADO == "MENU" or ESTADO == "BATALHA" or ESTADO == "MAPA") then
            pcall(function() speaker.playSound("music_disc.stal", 3.0, 1.0) end)
        end
        os.sleep(150)
    end
end
tocar("entity.player.levelup", 2.0)

-- =======================================================
-- BESTIARIO
-- =======================================================
local bestiario = {
    {nome = "Slime de Musgo", maxHp = 20, dano = 5, xp = 5, ouro = 6, cor = colors.lime, arte = {"       ", "  ___  ", " (o.o) ", " (___) "}},
    {nome = "Lobo Selvagem", maxHp = 35, dano = 8, xp = 10, ouro = 10, cor = colors.lightGray, arte = {"       ", " / \\__ ", " (o.o )", "  / /  "}},
    {nome = "Goblin Ladrao", maxHp = 50, dano = 12, xp = 15, ouro = 18, cor = colors.green, arte = {"  ^ ^  ", " (O.O) ", " / | \\ ", "  / \\  "}},
    {nome = "Esqueleto Negro", maxHp = 80, dano = 16, xp = 25, ouro = 25, cor = colors.white, arte = {"  .-.  ", " (o o) ", "  |O|  ", " /| |\\ "}},
    {nome = "Cavaleiro Caido", maxHp = 120, dano = 22, xp = 40, ouro = 40, cor = colors.gray, arte = {"  _|_  ", " [o o] ", " /[|]\\ ", "  / \\  "}}
}

local chefes = {
    [1] = {nome = "REI SLIME", maxHp = 250, dano = 25, xp = 100, ouro = 100, cor = colors.lime, arte = {"   _^_   ", "  /   \\  ", " | O_O | ", "  \\___/  "}},
    [2] = {nome = "LORDE VAMPIRO", maxHp = 500, dano = 40, xp = 300, ouro = 250, cor = colors.red, arte = {" \\_v_v_/ ", "  (o o)  ", "  /| |\\  ", "  /   \\  "}},
    [3] = {nome = "DRAGAO DO FIM", maxHp = 1000, dano = 60, xp = 1000, ouro = 800, cor = colors.purple, arte = {" \\ ||| / ", "  (O_O)  ", " /|   |\\ ", "  |___|  "}}
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
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, _ = mon.getSize()
    
    centralizar(3, "--- P I L G R A M O ---", colors.yellow, colors.black)
    centralizar(5, "A Campanha Infinita", colors.lightGray, colors.black)
    
    if fs.exists(ARQUIVO_SAVE) then
        desenharBotao(math.floor(larg/2) - 10, 8, 20, "CONTINUAR CAMPANHA", colors.cyan, colors.black)
        desenharBotao(math.floor(larg/2) - 10, 12, 20, "NOVO JOGO", colors.red, colors.white)
    else
        desenharBotao(math.floor(larg/2) - 10, 10, 20, "NOVO JOGO", colors.lime, colors.black)
    end
end

local function desenharMapa()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, _ = mon.getSize()
    
    centralizar(2, "--- MAPA DO MUNDO ---", colors.yellow, colors.black)
    centralizar(4, "ZONA ATUAL: " .. jogador.zona, colors.cyan, colors.black)
    
    -- Desenha os Nodos (Progresso da Zona)
    local linhaMapa = " "
    for i = 1, 5 do
        if i < jogador.nodo then linhaMapa = linhaMapa .. "(OK) "
        elseif i == jogador.nodo then linhaMapa = linhaMapa .. "[VOCE] "
        elseif i == 5 then linhaMapa = linhaMapa .. "[CHEFE] "
        else linhaMapa = linhaMapa .. "( ? ) "
        end
        if i < 5 then linhaMapa = linhaMapa .. "--- " end
    end
    
    centralizar(7, linhaMapa, colors.white, colors.black)
    centralizar(9, "Status: HP " .. jogador.hp .. "/" .. jogador.maxHp .. " | Ouro: " .. jogador.ouro, colors.lime, colors.black)
    
    desenharBotao(math.floor(larg/2) - 18, 14, 16, "AVANCAR", colors.red, colors.white)
    desenharBotao(math.floor(larg/2) + 2, 14, 16, "MERCADOR", colors.yellow, colors.black)
end

local function desenharLoja()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, _ = mon.getSize()
    
    centralizar(1, "--- MERCADOR DA ZONA " .. jogador.zona .. " ---", colors.yellow, colors.black)
    centralizar(3, "Ouro: " .. jogador.ouro .. " | Def: " .. jogador.defesa .. " | Dano Extra: +" .. jogador.danoExtra, colors.lime, colors.black)
    
    desenharBotao(2, 5, 26, "POCAO (+25HP) - 15G", colors.gray, colors.white)
    desenharBotao(30, 5, 26, "SUPER POCAO (+50HP) - 30G", colors.gray, colors.white)
    desenharBotao(2, 9, 26, "ESPADA (+5 Dano) - 40G", colors.gray, colors.white)
    desenharBotao(30, 9, 26, "ESCUDO (+2 Def) - 40G", colors.gray, colors.white)
    desenharBotao(2, 13, 26, "ARMADURA (+20 HP) - 50G", colors.gray, colors.white)
    desenharBotao(30, 13, 26, "ANEL MAGIA (+10 Mag) - 60G", colors.gray, colors.white)
    
    desenharBotao(math.floor(larg/2) - 10, 17, 20, "VOLTAR AO MAPA", colors.blue, colors.white)
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, _ = mon.getSize()
    
    -- Status Bar
    mon.setCursorPos(1, 1); mon.setBackgroundColor(colors.blue); mon.write(string.rep(" ", larg))
    mon.setCursorPos(2, 1); mon.setTextColor(colors.white)
    mon.write(string.format(" ZONA:%d | NODO:%d | LVL:%d | XP:%d | OURO:%d ", jogador.zona, jogador.nodo, jogador.level, jogador.xp, jogador.ouro))

    -- Inimigo
    if inimigoAtual then
        mon.setCursorPos(3, 3); mon.setTextColor(inimigoAtual.cor)
        mon.write(inimigoAtual.nome)
        desenharBarra(3, 4, 15, inimigoAtual.hp, inimigoAtual.maxHp, colors.red)
        for i, linha in ipairs(inimigoAtual.arte) do
            mon.setCursorPos(5, 5 + i)
            mon.setTextColor(inimigoAtual.cor)
            mon.write(linha)
        end
    end

    -- Jogador Status
    mon.setCursorPos(30, 3); mon.setTextColor(colors.cyan); mon.write("PILGRAMO")
    mon.setCursorPos(30, 5); mon.setTextColor(colors.white); mon.write(string.format("HP: %3d / %3d", jogador.hp, jogador.maxHp))
    desenharBarra(30, 6, 20, jogador.hp, jogador.maxHp, colors.lime)
    mon.setCursorPos(30, 8); mon.write(string.format("TP: %3d %%", jogador.tp))
    desenharBarra(30, 9, 20, jogador.tp, 100, colors.orange)

    -- Log de Batalha
    desenharCaixa(2, 12, larg - 3, 3, colors.gray)
    mon.setCursorPos(4, 13); mon.setTextColor(colors.white); mon.setBackgroundColor(colors.gray)
    mon.write("* " .. mensagemLog)

    mon.setBackgroundColor(colors.black)
    
    if ESTADO == "BATALHA" then
        desenharBotao(2, 16, 12, "[ ATACAR ]", colors.red, colors.white)
        desenharBotao(16, 16, 12, "[ MAGIA ]", colors.purple, colors.white)
        desenharBotao(30, 16, 12, "[ ITENS ]", colors.lime, colors.black)
        desenharBotao(44, 16, 12, "[ FUGIR ]", colors.yellow, colors.black)
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
    elseif ESTADO == "MAPA" then desenharMapa()
    elseif ESTADO == "LOJA" then desenharLoja()
    elseif ESTADO == "BATALHA" or ESTADO == "SUBMENU_MAGIA" or ESTADO == "SUBMENU_ITEM" then desenharBatalha()
    end
end

-- =======================================================
-- LOGICA DE COMBATE E DIFICULDADE
-- =======================================================
local function ganharTP(valor) jogador.tp = math.min(100, jogador.tp + valor) end

local function gerarEncontro()
    salvarJogo()
    local multiplicadorZ = 1.0 + ((jogador.zona - 1) * 0.4) -- Inimigos ficam 40% mais fortes por Zona!
    
    if jogador.nodo == 5 then
        -- BOSS BATTLE
        local bossTemplate = chefes[jogador.zona] or chefes[3] -- Repete o dragão se passar da zona 3
        local hpCalc = math.floor(bossTemplate.maxHp * multiplicadorZ)
        inimigoAtual = {
            nome = bossTemplate.nome .. " (Chefe)", maxHp = hpCalc, hp = hpCalc,
            dano = math.floor(bossTemplate.dano * multiplicadorZ), xp = math.floor(bossTemplate.xp * multiplicadorZ), 
            ouro = math.floor(bossTemplate.ouro * multiplicadorZ), cor = bossTemplate.cor, arte = bossTemplate.arte, isBoss = true
        }
        mensagemLog = "CUIDADO! " .. inimigoAtual.nome .. " APARECEU!"
        tocar("entity.ender_dragon.growl", 1.0)
    else
        local maxIndex = math.min(jogador.level + jogador.zona, #bestiario)
        local template = bestiario[math.random(1, maxIndex)]
        local hpCalc = math.floor(template.maxHp * multiplicadorZ)
        inimigoAtual = {
            nome = template.nome, maxHp = hpCalc, hp = hpCalc,
            dano = math.floor(template.dano * multiplicadorZ), xp = math.floor(template.xp * multiplicadorZ), 
            ouro = math.floor(template.ouro * multiplicadorZ), cor = template.cor, arte = template.arte, isBoss = false
        }
        mensagemLog = inimigoAtual.nome .. " ataca!"
    end
    
    ESTADO = "BATALHA"
    atualizarTela()
end

local function turnoInimigo()
    if inimigoAtual and inimigoAtual.hp > 0 then
        -- 10% de chance do inimigo errar (Esquiva do jogador)
        if math.random(1, 100) <= 10 then
            mensagemLog = inimigoAtual.nome .. " ERROU o ataque!"
            tocar("entity.player.attack.nodamage", 1)
            return
        end

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
    tocar("entity.experience_orb.pickup", 1.5)
    
    if inimigoAtual.isBoss then
        jogador.zona = jogador.zona + 1
        jogador.nodo = 1
        mensagemLog = "CHEFE DERROTADO! Avancando para a Zona " .. jogador.zona
        tocar("ui.toast.challenge_complete", 1)
    else
        jogador.nodo = jogador.nodo + 1
        mensagemLog = "Vitoria! +" .. inimigoAtual.xp .. "XP e " .. inimigoAtual.ouro .. " Ouro."
    end
    
    jogador.xp = jogador.xp + inimigoAtual.xp
    jogador.ouro = jogador.ouro + inimigoAtual.ouro
    atualizarTela(); os.sleep(2.0)
    
    local xpMax = jogador.level * 20
    if jogador.xp >= xpMax then
        jogador.xp = jogador.xp - xpMax
        jogador.level = jogador.level + 1
        jogador.maxHp = jogador.maxHp + 10; jogador.hp = jogador.maxHp
        mensagemLog = "LEVEL UP! HP Restaurado."
        tocar("entity.player.levelup", 1)
        atualizarTela(); os.sleep(1.5)
    end
    
    ESTADO = "MAPA"
    salvarJogo()
    atualizarTela()
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
                carregarJogo(); ESTADO = "MAPA"; atualizarTela()
            elseif (not temSave and y >= 10 and y <= 12) or (temSave and y >= 12 and y <= 14) then
                jogador = {hp=50, maxHp=50, tp=0, level=1, xp=0, ouro=0, pocoes=3, pocoesMax=0, danoExtra=0, defesa=0, magiaExtra=0, zona=1, nodo=1}
                ESTADO = "MAPA"; salvarJogo(); atualizarTela()
            end

        elseif ESTADO == "MAPA" then
            if y >= 14 and y <= 16 then
                if x >= math.floor(larg/2)-18 and x <= math.floor(larg/2)-2 then -- AVANCAR
                    gerarEncontro()
                elseif x >= math.floor(larg/2)+2 and x <= math.floor(larg/2)+18 then -- LOJA
                    ESTADO = "LOJA"; atualizarTela()
                end
            end

        elseif ESTADO == "LOJA" then
            if y >= 5 and y <= 7 then
                if x >= 2 and x <= 28 and jogador.ouro >= 15 then
                    jogador.ouro = jogador.ouro - 15; jogador.pocoes = jogador.pocoes + 1; tocar("entity.experience_orb.pickup", 1)
                elseif x >= 30 and jogador.ouro >= 30 then
                    jogador.ouro = jogador.ouro - 30; jogador.pocoesMax = jogador.pocoesMax + 1; tocar("entity.experience_orb.pickup", 1)
                end
            elseif y >= 9 and y <= 11 then
                if x >= 2 and x <= 28 and jogador.ouro >= 40 then
                    jogador.ouro = jogador.ouro - 40; jogador.danoExtra = jogador.danoExtra + 5; tocar("item.armor.equip_iron", 1)
                elseif x >= 30 and jogador.ouro >= 40 then
                    jogador.ouro = jogador.ouro - 40; jogador.defesa = jogador.defesa + 2; tocar("item.shield.equip", 1)
                end
            elseif y >= 13 and y <= 15 then
                if x >= 2 and x <= 28 and jogador.ouro >= 50 then
                    jogador.ouro = jogador.ouro - 50; jogador.maxHp = jogador.maxHp + 20; jogador.hp = jogador.hp + 20; tocar("item.armor.equip_diamond", 1)
                elseif x >= 30 and jogador.ouro >= 60 then
                    jogador.ouro = jogador.ouro - 60; jogador.magiaExtra = jogador.magiaExtra + 10; tocar("block.amethyst_block.chime", 1)
                end
            elseif y >= 17 and y <= 19 then
                salvarJogo(); ESTADO = "MAPA"; atualizarTela()
            end
            if ESTADO == "LOJA" then atualizarTela() end

        elseif ESTADO == "BATALHA" or ESTADO == "SUBMENU_MAGIA" or ESTADO == "SUBMENU_ITEM" then
            if y >= 16 and y <= 18 then
                if ESTADO == "BATALHA" then
                    if x >= 2 and x <= 14 then
                        tocar("entity.player.attack.sweep", 1.2)
                        ganharTP(15)
                        
                        -- SISTEMA DE CRÍTICO (15% de chance)
                        local multiplicador = 1
                        if math.random(1, 100) <= 15 then 
                            multiplicador = 2
                            tocar("entity.player.attack.crit", 1)
                            mensagemLog = "CRITICO! "
                        else
                            mensagemLog = ""
                        end
                        
                        local dano = (math.random(5 + (jogador.level*2), 10 + (jogador.level*3)) + jogador.danoExtra) * multiplicador
                        inimigoAtual.hp = inimigoAtual.hp - dano
                        mensagemLog = mensagemLog .. "Causou " .. dano .. " de dano!"
                        
                        atualizarTela(); os.sleep(1)
                        if inimigoAtual.hp <= 0 then vitoria() else turnoInimigo(); atualizarTela() end
                    
                    elseif x >= 16 and x <= 28 then
                        ESTADO = "SUBMENU_MAGIA"; atualizarTela()
                    elseif x >= 30 and x <= 42 then
                        ESTADO = "SUBMENU_ITEM"; atualizarTela()
                    elseif x >= 44 and x <= 56 then
                        if inimigoAtual.isBoss then
                            mensagemLog = "Voce nao pode fugir de um CHEFE!"
                            tocar("entity.villager.no", 1); atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                        else
                            if math.random(1, 100) <= 40 then -- 40% chance de fuga
                                mensagemLog = "Fugiu com sucesso! Voltando ao mapa..."
                                atualizarTela(); os.sleep(1); ESTADO = "MAPA"; atualizarTela()
                            else
                                mensagemLog = "O inimigo bloqueou a fuga!"
                                atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                            end
                        end
                    end
                
                elseif ESTADO == "SUBMENU_MAGIA" then
                    if x >= 2 and x <= 22 then
                        if jogador.tp >= 40 then
                            jogador.tp = jogador.tp - 40; jogador.hp = math.min(jogador.maxHp, jogador.hp + 40)
                            mensagemLog = "Magia de Cura! (+40 HP)"; tocar("entity.generic.drink", 1)
                            ESTADO = "BATALHA"; atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                        else mensagemLog = "TP Insuficiente para Cura!"; atualizarTela() end
                    elseif x >= 24 and x <= 44 then
                        if jogador.tp >= 50 then
                            jogador.tp = jogador.tp - 50
                            local dano = 30 + (jogador.level * 5) + jogador.magiaExtra
                            inimigoAtual.hp = inimigoAtual.hp - dano
                            mensagemLog = "Magia de Raio! (" .. dano .. " Dano)"; tocar("entity.lightning_bolt.thunder", 1)
                            ESTADO = "BATALHA"; atualizarTela(); os.sleep(1)
                            if inimigoAtual.hp <= 0 then vitoria() else turnoInimigo(); atualizarTela() end
                        else mensagemLog = "TP Insuficiente para Raio!"; atualizarTela() end
                    elseif x >= 46 then ESTADO = "BATALHA"; atualizarTela() end
                
                elseif ESTADO == "SUBMENU_ITEM" then
                    if x >= 2 and x <= 26 then
                        if jogador.pocoes > 0 or jogador.pocoesMax > 0 then
                            if jogador.pocoesMax > 0 then
                                jogador.pocoesMax = jogador.pocoesMax - 1; jogador.hp = math.min(jogador.maxHp, jogador.hp + 50)
                            else
                                jogador.pocoes = jogador.pocoes - 1; jogador.hp = math.min(jogador.maxHp, jogador.hp + 25)
                            end
                            mensagemLog = "Usou pocao e recuperou HP!"; tocar("entity.generic.drink", 1)
                            ESTADO = "BATALHA"; atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                        else mensagemLog = "Voce nao tem pocoes!"; atualizarTela() end
                    elseif x >= 28 then ESTADO = "BATALHA"; atualizarTela() end
                end
            end
        end
    end
end

print("Jogo rodando! Aperte Q aqui para desligar.")
local function escutarSaida()
    while rodando do
        local _, p1 = os.pullEvent("key")
        if p1 == keys.q then rodando = false; mon.setBackgroundColor(colors.black); mon.clear() end
    end
end

local sucesso, erro = pcall(function() parallel.waitForAny(escutarSaida, loopJogo, loopMusica) end)

if not sucesso then
    term.clear(); term.setCursorPos(1,1)
    print("Ocorreu um erro fatal na execucao:")
    print(erro)
end
