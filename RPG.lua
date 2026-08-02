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
local volume = 0.5
local mensagemLog = "Um inimigo apareceu no seu caminho!"
local rodando = true

-- Sistema de TP (Tension Points) adicionado!
local jogador = { 
    hp = 50, maxHp = 50, tp = 0, level = 1, xp = 0, 
    ouro = 0, pocoes = 3, danoExtra = 0, defesa = 0 
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
            jogador.tp = 0 -- TP sempre reseta entre sessoes
            jogador.defesa = jogador.defesa or 0
            return true
        end
    end
    return false
end

-- =======================================================
-- AUDIO E BESTIARIO (TEXTO LIMPO)
-- =======================================================
local function tocar(som, pitch)
    if speaker then pcall(function() speaker.playSound(som, volume, pitch or 1.0) end) end
end

local bestiario = {
    {nome = "Slime de Musgo", maxHp = 20, dano = 4, xp = 5, ouro = 5, cor = colors.lime, arte = {"       ", "  ___  ", " (o.o) ", " (___) "}},
    {nome = "Lobo Selvagem", maxHp = 30, dano = 6, xp = 10, ouro = 8, cor = colors.lightGray, arte = {"       ", " / \\__ ", " (o.o )", "  / /  "}},
    {nome = "Goblin Ladrao", maxHp = 45, dano = 8, xp = 15, ouro = 15, cor = colors.green, arte = {"  ^ ^  ", " (O.O) ", " / | \\ ", "  / \\  "}},
    {nome = "Esqueleto Negro", maxHp = 70, dano = 12, xp = 25, ouro = 20, cor = colors.white, arte = {"  .-.  ", " (o o) ", "  |O|  ", " /| |\\ "}},
    {nome = "Cavaleiro Caido", maxHp = 100, dano = 18, xp = 40, ouro = 35, cor = colors.gray, arte = {"  _|_  ", " [o o] ", " /[|]\\ ", "  / \\  "}},
    {nome = "Rei Demonio", maxHp = 200, dano = 25, xp = 100, ouro = 100, cor = colors.purple, arte = {" \\\\ // ", " (O O) ", " /| |\\ ", "  |_|  "}}
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
    centralizar(5, "O Conto do Heroi de Dados", colors.lightGray, colors.black)
    
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
    
    centralizar(2, "--- MERCADOR ---", colors.yellow, colors.black)
    centralizar(4, "Ouro: " .. jogador.ouro .. " | Defesa: " .. jogador.defesa .. " | Dano Extra: +" .. jogador.danoExtra, colors.lime, colors.black)
    
    desenharBotao(2, 6, 26, "POCAO (+25HP) - 15 Ouro", colors.gray, colors.white)
    desenharBotao(30, 6, 26, "ESPADA (+5 Dano) - 40", colors.gray, colors.white)
    desenharBotao(2, 10, 26, "ESCUDO (+2 Def) - 40", colors.gray, colors.white)
    desenharBotao(30, 10, 26, "ARMADURA (+20 HP) - 50", colors.gray, colors.white)
    
    desenharBotao(math.floor(larg/2) - 10, 15, 20, "VOLTAR AO JOGO", colors.blue, colors.white)
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black)
    mon.clear()
    local larg, alt = mon.getSize()
    
    -- 1. Status do Jogador (Estilo Deltarune - Direito/Topo)
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

    -- 2. Área do Inimigo (Centro)
    if inimigoAtual then
        mon.setCursorPos(3, 4)
        mon.setTextColor(inimigoAtual.cor)
        mon.write(inimigoAtual.nome)
        
        -- Barra de Vida Inimigo
        desenharBarra(3, 5, 15, inimigoAtual.hp, inimigoAtual.maxHp, colors.red)
        
        for i, linha in ipairs(inimigoAtual.arte) do
            mon.setCursorPos(5, 6 + i)
            mon.setTextColor(inimigoAtual.cor)
            mon.write(linha)
        end
    end

    -- 3. Painel de Status do Jogador (Meio-Direita)
    mon.setCursorPos(30, 4)
    mon.setTextColor(colors.cyan)
    mon.write("PILGRAMO")
    
    mon.setCursorPos(30, 6)
    mon.setTextColor(colors.white)
    mon.write(string.format("HP: %3d / %3d", jogador.hp, jogador.maxHp))
    desenharBarra(30, 7, 20, jogador.hp, jogador.maxHp, colors.lime)
    
    mon.setCursorPos(30, 9)
    mon.write(string.format("TP: %3d %%", jogador.tp))
    desenharBarra(30, 10, 20, jogador.tp, 100, colors.orange)

    -- 4. Caixa de Dialogo
    desenharCaixa(2, 12, larg - 3, 3, colors.gray)
    mon.setCursorPos(4, 13)
    mon.setTextColor(colors.white)
    mon.setBackgroundColor(colors.gray)
    mon.write("* " .. mensagemLog)

    -- 5. Botoes de Acao (Estilo Deltarune)
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
        desenharBotao(2, 16, 24, "POCAO (" .. jogador.pocoes .. "x)", colors.lime, colors.black)
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
-- LOGICA DE COMBATE
-- =======================================================
local function ganharTP(valor)
    jogador.tp = math.min(100, jogador.tp + valor)
end

local function gerarEncontro()
    salvarJogo()
    local maxIndex = math.min(jogador.level, #bestiario)
    local template = bestiario[math.random(1, maxIndex)]
    inimigoAtual = {
        nome = template.nome, maxHp = template.maxHp, hp = template.maxHp,
        dano = template.dano, xp = template.xp, ouro = template.ouro, 
        cor = template.cor, arte = template.arte
    }
    mensagemLog = inimigoAtual.nome .. " bloqueia o caminho!"
    ESTADO = "BATALHA"
    atualizarTela()
end

local function turnoInimigo()
    if inimigoAtual and inimigoAtual.hp > 0 then
        local dano = math.random(math.floor(inimigoAtual.dano / 2), inimigoAtual.dano)
        local danoReal = math.max(1, dano - jogador.defesa)
        
        jogador.hp = math.max(0, jogador.hp - danoReal)
        ganharTP(10) -- Ganha TP ao apanhar
        mensagemLog = inimigoAtual.nome .. " atacou! (-" .. danoReal .. " HP)"
        tocar("entity.player.hurt", 1)
        
        if jogador.hp <= 0 then
            jogador.hp = 0; ESTADO = "MENU"; fs.delete(ARQUIVO_SAVE)
            tocar("entity.wither.death", 0.5)
        end
    end
end

local function vitoria()
    mensagemLog = "Voce venceu! Ganhou " .. inimigoAtual.xp .. "XP e " .. inimigoAtual.ouro .. " Ouro."
    jogador.xp = jogador.xp + inimigoAtual.xp
    jogador.ouro = jogador.ouro + inimigoAtual.ouro
    tocar("entity.experience_orb.pickup", 1.5)
    atualizarTela(); os.sleep(1.5)
    
    if jogador.xp >= (jogador.level * 20) then
        jogador.xp = jogador.xp - (jogador.level * 20)
        jogador.level = jogador.level + 1
        jogador.maxHp = jogador.maxHp + 10
        jogador.hp = jogador.maxHp
        mensagemLog = "LEVEL UP! Voce ficou mais forte."
        tocar("ui.toast.challenge_complete", 1)
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
                jogador = {hp=50, maxHp=50, tp=0, level=1, xp=0, ouro=0, pocoes=3, danoExtra=0, defesa=0}
                gerarEncontro()
            end

        elseif ESTADO == "LOJA" then
            if y >= 6 and y <= 8 then
                if x >= 2 and x <= 28 and jogador.ouro >= 15 then
                    jogador.ouro = jogador.ouro - 15; jogador.pocoes = jogador.pocoes + 1
                    tocar("entity.experience_orb.pickup", 1)
                elseif x >= 30 and jogador.ouro >= 40 then
                    jogador.ouro = jogador.ouro - 40; jogador.danoExtra = jogador.danoExtra + 5
                    tocar("item.armor.equip_iron", 1)
                end
            elseif y >= 10 and y <= 12 then
                if x >= 2 and x <= 28 and jogador.ouro >= 40 then
                    jogador.ouro = jogador.ouro - 40; jogador.defesa = jogador.defesa + 2
                    tocar("item.shield.equip", 1)
                elseif x >= 30 and jogador.ouro >= 50 then
                    jogador.ouro = jogador.ouro - 50; jogador.maxHp = jogador.maxHp + 20; jogador.hp = jogador.hp + 20
                    tocar("item.armor.equip_diamond", 1)
                end
            elseif y >= 15 and y <= 17 then
                salvarJogo(); ESTADO = estadoAnterior
            end
            atualizarTela()

        elseif ESTADO == "BATALHA" or ESTADO == "SUBMENU_MAGIA" or ESTADO == "SUBMENU_ITEM" then
            if y == 1 and x >= larg - 7 then
                estadoAnterior = "BATALHA"; ESTADO = "LOJA"; atualizarTela()
            elseif y >= 16 and y <= 18 then
                
                if ESTADO == "BATALHA" then
                    if x >= 2 and x <= 14 then -- ATACAR
                        tocar("entity.player.attack.sweep", 1.2)
                        ganharTP(15)
                        local dano = math.random(5 + (jogador.level*2), 10 + (jogador.level*3)) + jogador.danoExtra
                        inimigoAtual.hp = inimigoAtual.hp - dano
                        mensagemLog = "Voce atacou causando " .. dano .. " de dano!"
                        atualizarTela(); os.sleep(1)
                        if inimigoAtual.hp <= 0 then vitoria() else turnoInimigo(); atualizarTela() end
                    
                    elseif x >= 16 and x <= 28 then -- MAGIA
                        ESTADO = "SUBMENU_MAGIA"; atualizarTela()
                    
                    elseif x >= 30 and x <= 42 then -- ITENS
                        ESTADO = "SUBMENU_ITEM"; atualizarTela()
                    
                    elseif x >= 44 and x <= 56 then -- POUPAR / FUGIR
                        if inimigoAtual.hp <= (inimigoAtual.maxHp * 0.2) then
                            mensagemLog = "Voce poupou o inimigo!"
                            atualizarTela(); os.sleep(1); vitoria()
                        else
                            if math.random(1, 2) == 1 then
                                mensagemLog = "Fugiu com sucesso!"
                                atualizarTela(); os.sleep(1); gerarEncontro()
                            else
                                mensagemLog = "Falha ao fugir! O inimigo bloqueou."
                                atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                            end
                        end
                    end
                
                elseif ESTADO == "SUBMENU_MAGIA" then
                    if x >= 2 and x <= 22 then -- CURA
                        if jogador.tp >= 40 then
                            jogador.tp = jogador.tp - 40
                            jogador.hp = math.min(jogador.maxHp, jogador.hp + 40)
                            mensagemLog = "Magia de Cura! (+40 HP)"
                            tocar("entity.generic.drink", 1)
                            ESTADO = "BATALHA"; atualizarTela(); os.sleep(1)
                            turnoInimigo(); atualizarTela()
                        else mensagemLog = "TP Insuficiente para Cura!"; atualizarTela() end
                    elseif x >= 24 and x <= 44 then -- RAIO
                        if jogador.tp >= 50 then
                            jogador.tp = jogador.tp - 50
                            local dano = 30 + (jogador.level * 5)
                            inimigoAtual.hp = inimigoAtual.hp - dano
                            mensagemLog = "Magia de Raio! (" .. dano .. " Dano)"
                            tocar("entity.lightning_bolt.thunder", 1)
                            ESTADO = "BATALHA"; atualizarTela(); os.sleep(1)
                            if inimigoAtual.hp <= 0 then vitoria() else turnoInimigo(); atualizarTela() end
                        else mensagemLog = "TP Insuficiente para Raio!"; atualizarTela() end
                    elseif x >= 46 then -- VOLTAR
                        ESTADO = "BATALHA"; atualizarTela()
                    end
                
                elseif ESTADO == "SUBMENU_ITEM" then
                    if x >= 2 and x <= 26 then -- POCAO
                        if jogador.pocoes > 0 then
                            jogador.pocoes = jogador.pocoes - 1
                            jogador.hp = math.min(jogador.maxHp, jogador.hp + 25)
                            mensagemLog = "Voce bebeu uma pocao! (+25 HP)"
                            tocar("entity.generic.drink", 1)
                            ESTADO = "BATALHA"; atualizarTela(); os.sleep(1)
                            turnoInimigo(); atualizarTela()
                        else mensagemLog = "Voce nao tem pocoes!"; atualizarTela() end
                    elseif x >= 28 then -- VOLTAR
                        ESTADO = "BATALHA"; atualizarTela()
                    end
                end
            end
        end
    end
end

print("Jogo rodando! Aperte Q aqui para desligar em seguranca.")
local function escutarSaida()
    while rodando do
        local _, p1 = os.pullEvent("key")
        if p1 == keys.q then
            rodando = false
            mon.setBackgroundColor(colors.black); mon.clear()
        end
    end
end

parallel.waitForAny(escutarSaida, loopJogo)
