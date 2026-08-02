-- =======================================================
-- AETHERIA 2.0 - RPG DE EXPLORAÇÃO COM BIOMAS
-- =======================================================
local mon = peripheral.find("monitor")
local listaSpeakers = {peripheral.find("speaker")}

local speakerSFX = listaSpeakers[1]
local speakerBGM = listaSpeakers[2] or listaSpeakers[1]

if not mon then print("[ERRO] Monitor nao encontrado!") return end

local ESTADO = "MENU" -- MENU, ESCOLHA, MAPA, BATALHA
local rodando = true
local volume = 0.8
local mensagemLog = "Bem-vindo a Aetheria!"

local jogador = { 
    x = 0, y = 0,
    nivel = 1, xp = 0, hp = 100, maxHp = 100,
    ouro = 0, pocoes = 5,
    monstro = "Nenhum", tipo = "Normal"
}

local inimigoAtual = nil

local bestiario = {
    {nome="Gota Selvagem", tipo="Agua", hp=40, dano=10, xp=15, ouro=5, cor=colors.lightBlue, arte={"  _  "," / \\ ","(o.o)"," --- "}},
    {nome="Espirito Folha", tipo="Planta", hp=45, dano=12, xp=15, ouro=8, cor=colors.lime, arte={" \\|/ ","-o.o-"," /|\\ ","     "}},
    {nome="Lobo de Chamas", tipo="Fogo", hp=60, dano=18, xp=25, ouro=15, cor=colors.orange, arte={" /\\/\\ ","( o.o)"," >^^< ","      "}},
    {nome="Tartaruga Rio", tipo="Agua", hp=80, dano=14, xp=30, ouro=20, cor=colors.blue, arte={"  ___  "," /o o\\ ","(_____)","       "}},
    {nome="Tronco Vivo", tipo="Planta", hp=90, dano=20, xp=40, ouro=25, cor=colors.brown, arte={" [~~~] "," [o.o] "," /[ ]\\ ","       "}}
}

local chefes = {
    {nome="TITAN DE GELO", tipo="Agua", hp=300, dano=30, xp=200, ouro=150, cor=colors.lightBlue, arte={" /\\/\\/\\ "," |O..O| "," |____| "," /\\/\\/\\ "}},
    {nome="DRAGAO CELESTE", tipo="Fogo", hp=600, dano=55, xp=500, ouro=500, cor=colors.red, arte={" \\||||/ "," (O__O) "," /|  |\\ ","  |__|  "}}
}

-- =======================================================
-- AUDIO E BGM
-- =======================================================
local function tocar(som, pitch)
    if speakerSFX then pcall(function() speakerSFX.playSound(som, volume, pitch or 1.0) end) end
end

local function loopMusica()
    while rodando do
        if speakerBGM and (ESTADO == "MAPA" or ESTADO == "BATALHA") then
            pcall(function() speakerBGM.playSound("music_disc.pigstep", 2.0, 1.0) end)
        end
        os.sleep(145)
    end
end
tocar("entity.player.levelup", 2.0)

-- =======================================================
-- GERADOR DE MAPA INFINITO (BIOMAS)
-- =======================================================
local function getTile(wx, wy)
    -- Area de Spawn segura
    if wx >= -1 and wx <= 1 and wy >= -1 and wy <= 1 then return {cor=colors.yellow, block="caminho"} end
    
    -- Pontos de Interesse (Hash aleatorio)
    local hash = math.abs((wx * 1337) + (wy * 99991)) % 1000
    if hash < 5 then return {cor=colors.magenta, block="chefe"} end
    if hash < 20 then return {cor=colors.cyan, block="cura"} end
    
    -- Formula de Ruido (Ondas) para gerar biomas orgânicos
    local ruido = math.sin(wx * 0.3) + math.cos(wy * 0.3) + math.sin((wx+wy) * 0.1)
    
    if ruido < -1.0 then return {cor=colors.blue, block="agua"} end
    if ruido > 1.2 then return {cor=colors.gray, block="montanha"} end
    if ruido > 0.5 then return {cor=colors.green, block="grama_alta"} end
    
    return {cor=colors.lime, block="grama"}
end

-- =======================================================
-- UTILITARIOS VISUAIS (CORRIGIDO PARA O MONITOR)
-- =======================================================
local function centralizar(x_start, largura, y, texto, corTexto, corFundo)
    local x = x_start + math.floor((largura - #texto) / 2)
    mon.setCursorPos(math.max(x_start, x), y)
    mon.setTextColor(corTexto or colors.white)
    if corFundo then mon.setBackgroundColor(corFundo) end
    mon.write(texto)
end

local function desenharBotao(x, y, larg, alt, texto, corFundo, corTexto)
    mon.setBackgroundColor(corFundo)
    for i=0, alt-1 do mon.setCursorPos(x, y+i); mon.write(string.rep(" ", larg)) end
    mon.setCursorPos(x + math.floor((larg - #texto)/2), y + math.floor(alt/2))
    mon.setTextColor(corTexto); mon.write(texto)
end

-- =======================================================
-- TELAS DO JOGO
-- =======================================================
local function desenharMenu()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    centralizar(1, larg, 4, "A E T H E R I A", colors.yellow, colors.black)
    centralizar(1, larg, 6, "Domadores de Monstros", colors.cyan, colors.black)
    desenharBotao(math.floor(larg/2)-10, 10, 20, 3, "INICIAR JORNADA", colors.lime, colors.black)
end

local function desenharEscolha()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    centralizar(1, larg, 3, "ESCOLHA SEU AETHER INICIAL", colors.white, colors.black)
    
    desenharBotao(math.floor(larg/2)-25, 8, 14, 3, "IGNIS (FOGO)", colors.red, colors.white)
    desenharBotao(math.floor(larg/2)-7, 8, 14, 3, "AQUA (AGUA)", colors.blue, colors.white)
    desenharBotao(math.floor(larg/2)+11, 8, 15, 3, "FLORA (PLANTA)", colors.lime, colors.black)
end

local function desenharMapa()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    local viewLarg = larg - 24 -- 24 blocos para a UI da direita
    
    local cx = math.floor(viewLarg / 2)
    local cy = math.floor(alt / 2)
    
    -- Desenha o mapa colorido no monitor (CORRIGIDO)
    for screenY = 1, alt do
        for screenX = 1, viewLarg do
            local worldX = jogador.x + (screenX - cx)
            local worldY = jogador.y + (screenY - cy)
            local tile = getTile(worldX, worldY)
            
            mon.setCursorPos(screenX, screenY)
            mon.setBackgroundColor(tile.cor)
            
            if screenX == cx and screenY == cy then
                mon.setTextColor(colors.white)
                mon.write("@")
            else
                mon.write(" ")
            end
        end
    end
    
    -- UI Lateral
    local painelX = viewLarg + 1
    mon.setBackgroundColor(colors.gray)
    for i=1, alt do mon.setCursorPos(painelX, i); mon.write(string.rep(" ", 24)) end
    
    centralizar(painelX, 24, 2, "A E T H E R I A", colors.yellow, colors.gray)
    centralizar(painelX, 24, 4, jogador.monstro .. " ("..jogador.tipo..")", colors.cyan, colors.gray)
    centralizar(painelX, 24, 5, string.format("Lvl:%d | XP:%d", jogador.nivel, jogador.xp), colors.white, colors.gray)
    
    mon.setCursorPos(painelX+2, 7); mon.setBackgroundColor(colors.black); mon.write(string.rep(" ", 20))
    local hpFill = math.floor((jogador.hp / jogador.maxHp) * 20)
    if hpFill > 0 then
        mon.setCursorPos(painelX+2, 7); mon.setBackgroundColor(colors.lime); mon.write(string.rep(" ", hpFill))
    end
    
    centralizar(painelX, 24, 9, mensagemLog, colors.orange, colors.gray)
    
    -- Controle Direcional (D-PAD)
    desenharBotao(painelX + 9, 12, 6, 2, "/\\", colors.lightGray, colors.black)
    desenharBotao(painelX + 2, 15, 6, 2, "<", colors.lightGray, colors.black)
    desenharBotao(painelX + 16, 15, 6, 2, ">", colors.lightGray, colors.black)
    desenharBotao(painelX + 9, 18, 6, 2, "\\/", colors.lightGray, colors.black)
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, alt = mon.getSize()
    
    mon.setCursorPos(1, 1); mon.setBackgroundColor(colors.blue); mon.write(string.rep(" ", larg))
    centralizar(1, larg, 1, "BATALHA: " .. jogador.monstro .. " VS " .. inimigoAtual.nome, colors.white, colors.blue)

    if inimigoAtual then
        centralizar(1, larg, 4, inimigoAtual.nome .. " (" .. inimigoAtual.tipo .. ")", inimigoAtual.cor, colors.black)
        centralizar(1, larg, 5, "HP: " .. inimigoAtual.hp .. " / " .. inimigoAtual.maxHp, colors.red, colors.black)
        for i, linha in ipairs(inimigoAtual.arte) do
            centralizar(1, larg, 6 + i, linha, inimigoAtual.cor, colors.black)
        end
    end

    mon.setCursorPos(4, alt - 6); mon.setTextColor(colors.cyan); mon.write(jogador.monstro .. " ("..jogador.tipo..")")
    mon.setCursorPos(4, alt - 5); mon.setTextColor(colors.white); mon.write(string.format("HP: %d / %d", jogador.hp, jogador.maxHp))
    
    mon.setBackgroundColor(colors.gray)
    for i=0, 2 do mon.setCursorPos(24, alt-6+i); mon.write(string.rep(" ", larg-25)) end
    mon.setCursorPos(26, alt-5); mon.setTextColor(colors.white); mon.write(mensagemLog)

    mon.setBackgroundColor(colors.black)
    desenharBotao(4, alt - 2, 14, 2, "ATACAR", colors.red, colors.white)
    desenharBotao(20, alt - 2, 16, 2, "CURAR ("..jogador.pocoes..")", colors.lime, colors.black)
    desenharBotao(38, alt - 2, 12, 2, "FUGIR", colors.yellow, colors.black)
end

local function atualizarTela()
    mon.setTextScale(1)
    if ESTADO == "MENU" then desenharMenu()
    elseif ESTADO == "ESCOLHA" then desenharEscolha()
    elseif ESTADO == "MAPA" then desenharMapa()
    elseif ESTADO == "BATALHA" then desenharBatalha()
    end
end

-- =======================================================
-- LOGICA DE MAPA E COMBATE
-- =======================================================
local function moverJogador(dx, dy)
    local nx = jogador.x + dx
    local ny = jogador.y + dy
    local tile = getTile(nx, ny)
    
    if tile.block == "agua" or tile.block == "montanha" then
        mensagemLog = "Caminho bloqueado!"; tocar("block.wood.hit", 1); atualizarTela(); return
    end
    
    jogador.x = nx; jogador.y = ny; tocar("block.grass.step", 1)
    
    if tile.block == "cura" then
        jogador.hp = jogador.maxHp; jogador.pocoes = jogador.pocoes + 1
        mensagemLog = "Curado pelo Cristal!"; tocar("entity.experience_orb.pickup", 1)
        
    elseif tile.block == "chefe" then
        local boss = chefes[math.random(1, #chefes)]
        local mult = 1.0 + (jogador.nivel * 0.2)
        inimigoAtual = {nome=boss.nome, tipo=boss.tipo, maxHp=math.floor(boss.hp*mult), hp=math.floor(boss.hp*mult), dano=math.floor(boss.dano*mult), xp=boss.xp, cor=boss.cor, arte=boss.arte, isBoss=true}
        mensagemLog = "O CHEFE APARECEU!"; tocar("entity.ender_dragon.growl", 1); ESTADO = "BATALHA"
        
    elseif tile.block == "grama_alta" then
        if math.random(1, 100) <= 20 then
            local maxId = math.min(jogador.nivel + 1, #bestiario)
            local monstro = bestiario[math.random(1, maxId)]
            local mult = 1.0 + ((jogador.nivel - 1) * 0.15)
            inimigoAtual = {nome=monstro.nome, tipo=monstro.tipo, maxHp=math.floor(monstro.hp*mult), hp=math.floor(monstro.hp*mult), dano=math.floor(monstro.dano*mult), xp=math.floor(monstro.xp*mult), cor=monstro.cor, arte=monstro.arte, isBoss=false}
            mensagemLog = "Um " .. inimigoAtual.nome .. " selvagem surgiu!"; tocar("entity.zombie.ambient", 1.5); ESTADO = "BATALHA"
        else
            mensagemLog = "Grama alta se mexe..."
        end
    else
        mensagemLog = "Explorando..."
    end
    atualizarTela()
end

local function turnoInimigo()
    if inimigoAtual and inimigoAtual.hp > 0 then
        local dano = math.random(math.floor(inimigoAtual.dano * 0.7), inimigoAtual.dano)
        
        -- Multiplicador Inverso
        local mult = 1
        if inimigoAtual.tipo == "Fogo" and jogador.tipo == "Planta" then mult = 1.5 end
        if inimigoAtual.tipo == "Planta" and jogador.tipo == "Agua" then mult = 1.5 end
        if inimigoAtual.tipo == "Agua" and jogador.tipo == "Fogo" then mult = 1.5 end
        if mult > 1 then mensagemLog = "SUPER EFETIVO! " end
        
        dano = math.floor(dano * mult)
        jogador.hp = math.max(0, jogador.hp - dano)
        mensagemLog = mensagemLog .. inimigoAtual.nome .. " causou " .. dano .. " dano!"
        tocar("entity.player.hurt", 1)
        
        if jogador.hp <= 0 then
            jogador.hp = 0; mensagemLog = "DESMAIOU! Voltando ao Inicio..."; atualizarTela()
            tocar("entity.wither.death", 0.5); os.sleep(3)
            jogador.x = 0; jogador.y = 0; jogador.hp = jogador.maxHp; ESTADO = "MAPA"; atualizarTela()
        end
    end
end

local function vitoria()
    tocar("entity.experience_orb.pickup", 1.5)
    jogador.xp = jogador.xp + inimigoAtual.xp
    mensagemLog = "Vitoria! +" .. inimigoAtual.xp .. " XP"
    atualizarTela(); os.sleep(1.5)
    
    if jogador.xp >= (jogador.nivel * 30) then
        jogador.xp = jogador.xp - (jogador.nivel * 30)
        jogador.nivel = jogador.nivel + 1
        jogador.maxHp = jogador.maxHp + 15; jogador.hp = jogador.maxHp
        mensagemLog = "MONSTRO SUBIU DE NIVEL!"
        tocar("entity.player.levelup", 1); atualizarTela(); os.sleep(2)
    end
    ESTADO = "MAPA"; atualizarTela()
end

-- =======================================================
-- LOOP DE TOQUES E EVENTOS
-- =======================================================
local function loopJogo()
    atualizarTela()
    
    while rodando do
        local ev, _, x, y = os.pullEvent("monitor_touch")
        local larg, alt = mon.getSize()
        local painelX = (larg - 24) + 1
        
        if ESTADO == "MENU" then
            if y >= 10 and y <= 12 then ESTADO = "ESCOLHA"; atualizarTela() end
            
        elseif ESTADO == "ESCOLHA" then
            if y >= 8 and y <= 10 then
                if x >= math.floor(larg/2)-25 and x <= math.floor(larg/2)-11 then
                    jogador.monstro = "Ignis"; jogador.tipo = "Fogo"
                elseif x >= math.floor(larg/2)-7 and x <= math.floor(larg/2)+7 then
                    jogador.monstro = "Aqua"; jogador.tipo = "Agua"
                elseif x >= math.floor(larg/2)+11 and x <= math.floor(larg/2)+26 then
                    jogador.monstro = "Flora"; jogador.tipo = "Planta"
                end
                if jogador.monstro ~= "Nenhum" then tocar("entity.player.levelup", 1.5); ESTADO = "MAPA"; atualizarTela() end
            end
            
        elseif ESTADO == "MAPA" then
            if y >= 12 and y <= 13 and x >= painelX + 9 and x <= painelX + 14 then moverJogador(0, -1)
            elseif y >= 18 and y <= 19 and x >= painelX + 9 and x <= painelX + 14 then moverJogador(0, 1)
            elseif y >= 15 and y <= 16 and x >= painelX + 2 and x <= painelX + 7 then moverJogador(-1, 0)
            elseif y >= 15 and y <= 16 and x >= painelX + 16 and x <= painelX + 21 then moverJogador(1, 0)
            end
            
        elseif ESTADO == "BATALHA" then
            if y >= alt - 2 and y <= alt - 1 then
                if x >= 4 and x <= 17 then
                    tocar("entity.player.attack.sweep", 1.2)
                    local dano = math.random(10 + (jogador.nivel*3), 15 + (jogador.nivel*5))
                    
                    -- Vantagem de Tipo
                    local mult = 1
                    if jogador.tipo == "Fogo" and inimigoAtual.tipo == "Planta" then mult = 1.5 end
                    if jogador.tipo == "Planta" and inimigoAtual.tipo == "Agua" then mult = 1.5 end
                    if jogador.tipo == "Agua" and inimigoAtual.tipo == "Fogo" then mult = 1.5 end
                    
                    if mult > 1 then mensagemLog = "SUPER EFETIVO! " else mensagemLog = "" end
                    dano = math.floor(dano * mult)
                    
                    inimigoAtual.hp = inimigoAtual.hp - dano
                    mensagemLog = mensagemLog .. jogador.monstro .. " causou " .. dano .. " dano!"
                    atualizarTela(); os.sleep(1)
                    if inimigoAtual.hp <= 0 then vitoria() else turnoInimigo(); atualizarTela() end
                    
                elseif x >= 20 and x <= 35 then
                    if jogador.pocoes > 0 then
                        jogador.pocoes = jogador.pocoes - 1; jogador.hp = math.min(jogador.maxHp, jogador.hp + 50)
                        mensagemLog = "Curou 50 HP!"; tocar("entity.generic.drink", 1)
                        atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                    else mensagemLog = "Sem pocoes!"; atualizarTela() end
                    
                elseif x >= 38 and x <= 49 then
                    if inimigoAtual.isBoss then
                        mensagemLog = "Nao fuja do CHEFE!"; tocar("entity.villager.no", 1); atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                    elseif math.random(1, 100) <= 60 then
                        mensagemLog = "Fugiu da batalha!"; atualizarTela(); os.sleep(1); ESTADO = "MAPA"; atualizarTela()
                    else
                        mensagemLog = "Falhou em fugir!"; atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                    end
                end
            end
        end
    end
end

local function escutarSaida()
    while rodando do
        local _, p1 = os.pullEvent("key")
        if p1 == keys.q then rodando = false; mon.setBackgroundColor(colors.black); mon.clear() end
    end
end

local sucesso, erro = pcall(function() parallel.waitForAny(escutarSaida, loopJogo, loopMusica) end)
if not sucesso then term.clear(); term.setCursorPos(1,1); print("ERRO:"); print(erro) end
