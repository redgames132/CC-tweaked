-- =======================================================
-- PILGRAMO - VERSÃO 8-BIT DEFINITIVA (1 PC SÓ)
-- =======================================================
local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker")

if not mon then print("[ERRO] Monitor nao encontrado!") return end

local ESTADO = "MENU"
local volume = 1.0
local mensagemLog = "Bem-vindo a Pilgramo!"
local rodando = true

local jogador = { hp=60, maxHp=60, tp=0, level=1, xp=0, ouro=10, pocoes=3, pocoesMax=0, danoExtra=0, defesa=0, magiaExtra=0, zona=1, nodo=1 }
local inimigoAtual = nil
local eventoAtual = nil

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
            jogador.tp = 0; jogador.defesa = jogador.defesa or 0; jogador.magiaExtra = jogador.magiaExtra or 0
            jogador.pocoesMax = jogador.pocoesMax or 0; jogador.zona = jogador.zona or 1; jogador.nodo = jogador.nodo or 1
            return true
        end
    end
    return false
end

-- =======================================================
-- MOTOR DE AUDIO 8-BIT NATIVO (CC 1.120.0)
-- =======================================================
local function tocar(instrumento, pitch)
    if speaker then pcall(function() speaker.playNote(instrumento, volume, pitch) end) end
end

local melodia = {
    {12, 0.20}, {16, 0.20}, {19, 0.20}, {16, 0.20},
    {12, 0.20}, {16, 0.20}, {19, 0.40},
    {14, 0.20}, {17, 0.20}, {21, 0.20}, {17, 0.20},
    {14, 0.20}, {17, 0.20}, {21, 0.40},
    {10, 0.20}, {14, 0.20}, {17, 0.20}, {14, 0.20},
    {10, 0.20}, {14, 0.20}, {17, 0.40},
    {12, 0.20}, {16, 0.20}, {19, 0.20}, {24, 0.20},
    {19, 0.20}, {16, 0.20}, {12, 0.50}
}

local function loopMusica()
    local idx = 1
    while rodando do
        if speaker and (ESTADO == "MAPA" or ESTADO == "BATALHA" or ESTADO == "LOJA") then
            local nota = melodia[idx]
            pcall(function() speaker.playNote("harp", volume * 0.4, nota[1]) end)
            idx = (idx % #melodia) + 1
            os.sleep(nota[2])
        else
            os.sleep(0.5)
        end
    end
end

-- =======================================================
-- DADOS DO JOGO (INIMIGOS E EVENTOS)
-- =======================================================
local bestiario = {
    {nome = "Slime de Musgo", maxHp=18, dano=4, xp=6, ouro=15, cor=colors.lime, arte={"       ","  ___  "," (o.o) "," (___) "}},
    {nome = "Lobo Selvagem", maxHp=30, dano=6, xp=10, ouro=25, cor=colors.lightGray, arte={"       "," / \\__ "," (o.o )","  / /  "}},
    {nome = "Goblin Ladrao", maxHp=45, dano=10, xp=16, ouro=40, cor=colors.green, arte={"  ^ ^  "," (O.O) "," / | \\ ","  / \\  "}},
    {nome = "Esqueleto Negro", maxHp=70, dano=14, xp=25, ouro=60, cor=colors.white, arte={"  .-.  "," (o o) ","  |O|  "," /| |\\ "}},
    {nome = "Cavaleiro Caido", maxHp=110, dano=18, xp=40, ouro=80, cor=colors.gray, arte={"  _|_  "," [o o] "," /[|]\\ ","  / \\  "}}
}
local chefes = {
    [1] = {nome="REI SLIME", maxHp=180, dano=18, xp=80, ouro=150, cor=colors.lime, arte={"   _^_   ","  /   \\  "," | O_O | ","  \\___/  "}},
    [2] = {nome="LORDE VAMPIRO", maxHp=350, dano=28, xp=200, ouro=300, cor=colors.red, arte={" \\_v_v_/ ","  (o o)  ","  /| |\\  ","  /   \\  "}},
    [3] = {nome="GOLEM OBSIDIANA", maxHp=550, dano=38, xp=400, ouro=500, cor=colors.gray, arte={"  [___]  ","  [O_O]  "," /[| |]\\ ","  /   \\  "}},
    [4] = {nome="REINADO FANTASMA", maxHp=800, dano=48, xp=700, ouro=750, cor=colors.cyan, arte={"  /~~~\\  "," ( o_o ) "," /|   |\\ ","  \\___/  "}},
    [5] = {nome="DRAGAO DO FIM", maxHp=1200, dano=60, xp=1200, ouro=1500, cor=colors.purple, arte={" \\ ||| / ","  (O_O)  "," /|   |\\ ","  |___|  "}}
}
local listaEventos = {
    {nome="Fonte Sagrada", desc="Recuperou toda sua vida!", cor=colors.cyan, acao=function() jogador.hp=jogador.maxHp end},
    {nome="Bau de Tesouro", desc="Encontrou moedas de ouro!", cor=colors.yellow, acao=function() jogador.ouro=jogador.ouro+80 end},
    {nome="Acampamento Seguro", desc="Descansou, recuperou vida e ganhou pocao!", cor=colors.lime, acao=function() jogador.hp=math.min(jogador.maxHp, jogador.hp+30); jogador.pocoes=jogador.pocoes+1 end},
    {nome="Estatua Antiga", desc="+5 de Dano Permanente!", cor=colors.magenta, acao=function() jogador.danoExtra=jogador.danoExtra+5 end},
    {nome="Fada da Floresta", desc="+15 de Vida Maxima!", cor=colors.pink, acao=function() jogador.maxHp=jogador.maxHp+15; jogador.hp=jogador.hp+15 end}
}

-- =======================================================
-- UTILITARIOS VISUAIS E UI PADRONIZADA
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
    for i=0, alt-1 do mon.setCursorPos(x, y+i); mon.write(string.rep(" ", larg)) end
end

local function desenharBotao(x, y, larg, texto, corFundo, corTexto)
    desenharCaixa(x, y, larg, 3, corFundo)
    mon.setCursorPos(x + math.floor((larg - #texto)/2), y + 1)
    mon.setTextColor(corTexto); mon.write(texto)
end

local function desenharBarra(x, y, larg, valor, maxValor, corBarra)
    mon.setCursorPos(x, y); mon.setBackgroundColor(colors.gray); mon.write(string.rep(" ", larg))
    local preenchido = math.floor((valor / maxValor) * larg)
    if preenchido > 0 then
        mon.setCursorPos(x, y); mon.setBackgroundColor(corBarra); mon.write(string.rep(" ", preenchido))
    end
    mon.setBackgroundColor(colors.black)
end

local function desenharCabecalho(texto, corFundo, corTexto)
    local larg, _ = mon.getSize()
    mon.setCursorPos(1, 1); mon.setBackgroundColor(corFundo or colors.blue); mon.write(string.rep(" ", larg))
    centralizar(1, " " .. texto .. " ", corTexto or colors.white, corFundo or colors.blue)
end

local function desenharRodape(texto)
    local larg, alt = mon.getSize()
    mon.setCursorPos(1, alt); mon.setBackgroundColor(colors.gray); mon.write(string.rep(" ", larg))
    centralizar(alt, texto, colors.lightGray, colors.gray)
end

-- =======================================================
-- TELAS DO JOGO
-- =======================================================
local function desenharMenu()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, _ = mon.getSize()
    desenharCabecalho("P I L G R A M O", colors.gray, colors.yellow)
    centralizar(4, "A Campanha dos Reinos", colors.lightGray, colors.black)
    
    if fs.exists(ARQUIVO_SAVE) then
        desenharBotao(math.floor(larg/2)-12, 7, 24, "CONTINUAR CAMPANHA", colors.cyan, colors.black)
        desenharBotao(math.floor(larg/2)-12, 11, 24, "NOVO JOGO", colors.red, colors.white)
    else
        desenharBotao(math.floor(larg/2)-12, 9, 24, "NOVO JOGO", colors.lime, colors.black)
    end
    desenharRodape("Aperte Q no terminal para sair")
end

local function desenharMapa()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, _ = mon.getSize()
    desenharCabecalho("MAPA DO MUNDO - ZONA " .. jogador.zona, colors.blue, colors.white)
    
    local linhaMapa = ""
    for i = 1, 6 do
        if i < jogador.nodo then linhaMapa = linhaMapa .. "(OK)"
        elseif i == jogador.nodo then linhaMapa = linhaMapa .. "[VC]"
        elseif i == 6 then linhaMapa = linhaMapa .. "[BOSS]"
        else linhaMapa = linhaMapa .. "(?)" end
        if i < 6 then linhaMapa = linhaMapa .. "-" end
    end
    
    centralizar(6, linhaMapa, colors.white, colors.black)
    centralizar(9, string.format("HP: %d/%d | Ouro: %d | Lvl: %d", jogador.hp, jogador.maxHp, jogador.ouro, jogador.level), colors.lime, colors.black)
    
    desenharBotao(math.floor(larg/2)-18, 12, 16, "AVANCAR", colors.red, colors.white)
    desenharBotao(math.floor(larg/2)+2, 12, 16, "MERCADOR", colors.yellow, colors.black)
    desenharRodape("Prepare-se para o Nodo " .. jogador.nodo .. " de 6")
end

local function desenharEvento()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, _ = mon.getSize()
    desenharCabecalho("EVENTO NO CAMINHO", colors.purple, colors.white)
    
    if eventoAtual then
        centralizar(5, eventoAtual.nome, eventoAtual.cor, colors.black)
        desenharCaixa(4, 7, larg - 8, 4, colors.gray)
        mon.setCursorPos(6, 8); mon.setTextColor(colors.white); mon.setBackgroundColor(colors.gray); mon.write(eventoAtual.desc)
    end
    
    desenharBotao(math.floor(larg/2) - 10, 14, 20, "CONTINUAR", colors.lime, colors.black)
    desenharRodape("A jornada continua...")
end

local function desenharLoja()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, _ = mon.getSize()
    desenharCabecalho("MERCADOR DA ZONA " .. jogador.zona, colors.yellow, colors.black)
    centralizar(3, "Ouro: " .. jogador.ouro .. " | Defesa: " .. jogador.defesa .. " | Dano Extra: +" .. jogador.danoExtra, colors.lime, colors.black)
    
    desenharBotao(2, 5, 26, "POCAO (+25HP) - 10G", colors.gray, colors.white)
    desenharBotao(30, 5, 26, "SUPER POCAO (+50HP) - 25G", colors.gray, colors.white)
    desenharBotao(2, 9, 26, "ESPADA (+5 Dano) - 35G", colors.gray, colors.white)
    desenharBotao(30, 9, 26, "ESCUDO (+2 Def) - 35G", colors.gray, colors.white)
    desenharBotao(2, 13, 26, "ARMADURA (+20 HP) - 45G", colors.gray, colors.white)
    desenharBotao(30, 13, 26, "ANEL MAGIA (+10 Mag) - 55G", colors.gray, colors.white)
    
    desenharBotao(math.floor(larg/2) - 10, 17, 20, "VOLTAR AO MAPA", colors.blue, colors.white)
end

local function desenharBatalha()
    mon.setBackgroundColor(colors.black); mon.clear()
    local larg, _ = mon.getSize()
    desenharCabecalho(string.format("ZONA:%d | NODO:%d | LVL:%d | XP:%d | OURO:%d", jogador.zona, jogador.nodo, jogador.level, jogador.xp, jogador.ouro), colors.blue, colors.white)

    if inimigoAtual then
        mon.setCursorPos(3, 3); mon.setTextColor(inimigoAtual.cor); mon.write(inimigoAtual.nome)
        desenharBarra(3, 4, 15, inimigoAtual.hp, inimigoAtual.maxHp, colors.red)
        for i, linha in ipairs(inimigoAtual.arte) do mon.setCursorPos(5, 5+i); mon.setTextColor(inimigoAtual.cor); mon.write(linha) end
    end

    mon.setCursorPos(30, 3); mon.setTextColor(colors.cyan); mon.write("PILGRAMO")
    mon.setCursorPos(30, 5); mon.setTextColor(colors.white); mon.write(string.format("HP: %3d / %3d", jogador.hp, jogador.maxHp))
    desenharBarra(30, 6, 20, jogador.hp, jogador.maxHp, colors.lime)
    mon.setCursorPos(30, 8); mon.write(string.format("TP: %3d %%", jogador.tp))
    desenharBarra(30, 9, 20, jogador.tp, 100, colors.orange)

    desenharCaixa(2, 12, larg-3, 3, colors.gray)
    mon.setCursorPos(4, 13); mon.setTextColor(colors.white); mon.setBackgroundColor(colors.gray); mon.write("* " .. mensagemLog)

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
        desenharBotao(2, 16, 24, "POCAO ("..(jogador.pocoes+jogador.pocoesMax).."x)", colors.lime, colors.black)
        desenharBotao(28, 16, 10, "VOLTAR", colors.gray, colors.white)
    end
end

local function atualizarTela()
    mon.setTextScale(1)
    if ESTADO == "MENU" then desenharMenu()
    elseif ESTADO == "MAPA" then desenharMapa()
    elseif ESTADO == "EVENTO" then desenharEvento()
    elseif ESTADO == "LOJA" then desenharLoja()
    elseif ESTADO == "BATALHA" or ESTADO == "SUBMENU_MAGIA" or ESTADO == "SUBMENU_ITEM" then desenharBatalha()
    end
end

-- =======================================================
-- LOGICA DE COMBATE
-- =======================================================
local function turnoInimigo()
    if inimigoAtual and inimigoAtual.hp > 0 then
        if math.random(1, 100) <= 12 then
            mensagemLog = inimigoAtual.nome .. " ERROU!"; tocar("hat", 10); return
        end
        local danoReal = math.max(1, math.random(math.floor(inimigoAtual.dano/2), inimigoAtual.dano) - jogador.defesa)
        jogador.hp = math.max(0, jogador.hp - danoReal); jogador.tp = math.min(100, jogador.tp + 15)
        mensagemLog = inimigoAtual.nome .. " causou " .. danoReal .. " dano!"; tocar("snare", 5)
        if jogador.hp <= 0 then jogador.hp=0; ESTADO="MENU"; fs.delete(ARQUIVO_SAVE); tocar("bass", 2) end
    end
end

local function vitoria()
    tocar("chime", 20)
    if inimigoAtual.isBoss then jogador.zona=jogador.zona+1; jogador.nodo=1; mensagemLog="CHEFE DERROTADO!"
    else jogador.nodo=jogador.nodo+1; mensagemLog="Vitoria! +"..inimigoAtual.xp.."XP e "..inimigoAtual.ouro.." Ouro." end
    jogador.xp = jogador.xp + inimigoAtual.xp; jogador.ouro = jogador.ouro + inimigoAtual.ouro
    atualizarTela(); os.sleep(2.0)
    if jogador.xp >= jogador.level * 20 then
        jogador.xp = jogador.xp - (jogador.level * 20); jogador.level = jogador.level + 1
        jogador.maxHp = jogador.maxHp + 10; jogador.hp = jogador.maxHp
        mensagemLog="LEVEL UP!"; tocar("chime", 24); atualizarTela(); os.sleep(1.5)
    end
    ESTADO="MAPA"; salvarJogo(); atualizarTela()
end

local function loopJogo()
    atualizarTela()
    while rodando do
        local ev, _, x, y = os.pullEvent("monitor_touch")
        local larg, _ = mon.getSize()
        
        if ESTADO == "MENU" then
            local temSave = fs.exists(ARQUIVO_SAVE)
            if temSave and y>=7 and y<=9 then carregarJogo(); tocar("chime", 15); ESTADO="MAPA"; atualizarTela()
            elseif (not temSave and y>=9 and y<=11) or (temSave and y>=11 and y<=15) then
                jogador={hp=60, maxHp=60, tp=0, level=1, xp=0, ouro=10, pocoes=3, pocoesMax=0, danoExtra=0, defesa=0, magiaExtra=0, zona=1, nodo=1}
                tocar("chime", 15); ESTADO="MAPA"; salvarJogo(); atualizarTela()
            end
            
        elseif ESTADO == "MAPA" then
            if y>=12 and y<=14 then
                if x<=larg/2 then
                    salvarJogo()
                    if jogador.nodo == 6 then
                        local bt = chefes[jogador.zona] or chefes[5]
                        local mz = 1.0 + ((jogador.zona - 1) * 0.20)
                        local hp = math.floor(bt.maxHp * mz)
                        inimigoAtual={nome=bt.nome, maxHp=hp, hp=hp, dano=math.floor(bt.dano*mz), xp=math.floor(bt.xp*mz), ouro=math.floor(bt.ouro*mz), cor=bt.cor, arte=bt.arte, isBoss=true}
                        mensagemLog="CUIDADO CHEFE!"; tocar("bass", 5); ESTADO="BATALHA"
                    else
                        if math.random(1, 100)<=35 then
                            eventoAtual=listaEventos[math.random(1, #listaEventos)]; eventoAtual.acao(); tocar("chime", 18); ESTADO="EVENTO"
                        else
                            local mz = 1.0 + ((jogador.zona - 1) * 0.20)
                            local bt = bestiario[math.random(1, math.min(jogador.level, #bestiario))]
                            local hp = math.floor(bt.maxHp * mz)
                            inimigoAtual={nome=bt.nome, maxHp=hp, hp=hp, dano=math.floor(bt.dano*mz), xp=math.floor(bt.xp*mz), ouro=math.floor(bt.ouro*mz), cor=bt.cor, arte=bt.arte, isBoss=false}
                            mensagemLog=inimigoAtual.nome.." ataca!"; tocar("snare", 10); ESTADO="BATALHA"
                        end
                    end
                    atualizarTela()
                else tocar("hat", 12); ESTADO="LOJA"; atualizarTela() end
            end
            
        elseif ESTADO == "EVENTO" then
            if y>=13 and y<=15 then tocar("hat", 12); jogador.nodo=jogador.nodo+1; if jogador.nodo>6 then jogador.nodo=6 end; ESTADO="MAPA"; salvarJogo(); atualizarTela() end
            
        elseif ESTADO == "LOJA" then
            if y>=5 and y<=7 then
                if x<=28 and jogador.ouro>=10 then jogador.ouro=jogador.ouro-10; jogador.pocoes=jogador.pocoes+1; tocar("chime", 20)
                elseif x>28 and jogador.ouro>=25 then jogador.ouro=jogador.ouro-25; jogador.pocoesMax=jogador.pocoesMax+1; tocar("chime", 20) end
            elseif y>=9 and y<=11 then
                if x<=28 and jogador.ouro>=35 then jogador.ouro=jogador.ouro-35; jogador.danoExtra=jogador.danoExtra+5; tocar("chime", 20)
                elseif x>28 and jogador.ouro>=35 then jogador.ouro=jogador.ouro-35; jogador.defesa=jogador.defesa+2; tocar("chime", 20) end
            elseif y>=13 and y<=15 then
                if x<=28 and jogador.ouro>=45 then jogador.ouro=jogador.ouro-45; jogador.maxHp=jogador.maxHp+20; jogador.hp=jogador.hp+20; tocar("chime", 20)
                elseif x>28 and jogador.ouro>=55 then jogador.ouro=jogador.ouro-55; jogador.magiaExtra=jogador.magiaExtra+10; tocar("chime", 20) end
            elseif y>=17 and y<=19 then tocar("hat", 12); salvarJogo(); ESTADO="MAPA" end
            atualizarTela()
            
        elseif ESTADO == "BATALHA" or ESTADO == "SUBMENU_MAGIA" or ESTADO == "SUBMENU_ITEM" then
            if y>=16 and y<=18 then
                if ESTADO == "BATALHA" then
                    if x>=2 and x<=14 then
                        tocar("hat", 12); jogador.tp=math.min(100, jogador.tp+15)
                        local mult=1; if math.random(1,100)<=20 then mult=2; tocar("bell", 20); mensagemLog="CRITICO! " else mensagemLog="" end
                        local dano = (math.random(6+(jogador.level*2), 12+(jogador.level*3)) + jogador.danoExtra) * mult
                        inimigoAtual.hp=inimigoAtual.hp-dano; mensagemLog=mensagemLog.."Causou "..dano.." de dano!"; atualizarTela(); os.sleep(1)
                        if inimigoAtual.hp<=0 then vitoria() else turnoInimigo(); atualizarTela() end
                    elseif x>=16 and x<=28 then tocar("hat", 12); ESTADO="SUBMENU_MAGIA"; atualizarTela()
                    elseif x>=30 and x<=42 then tocar("hat", 12); ESTADO="SUBMENU_ITEM"; atualizarTela()
                    elseif x>=44 and x<=56 then
                        if inimigoAtual.isBoss then mensagemLog="Nao fuja!"; tocar("bass", 5); atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                        else
                            if math.random(1,100)<=75 then mensagemLog="Fugiu!"; tocar("hat", 15); atualizarTela(); os.sleep(1); ESTADO="MAPA"; atualizarTela()
                            else mensagemLog="Falhou!"; tocar("bass", 5); atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela() end
                        end
                    end
                elseif ESTADO == "SUBMENU_MAGIA" then
                    if x<=22 and jogador.tp>=40 then
                        jogador.tp=jogador.tp-40; jogador.hp=math.min(jogador.maxHp, jogador.hp+40); mensagemLog="Curou! (+40)"; tocar("chime", 18)
                        ESTADO="BATALHA"; atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                    elseif x>22 and x<=44 and jogador.tp>=50 then
                        jogador.tp=jogador.tp-50; local d = 30+(jogador.level*5)+jogador.magiaExtra; inimigoAtual.hp=inimigoAtual.hp-d; mensagemLog="Raio! ("..d.." Dano)"
                        tocar("chime", 22); ESTADO="BATALHA"; atualizarTela(); os.sleep(1); if inimigoAtual.hp<=0 then vitoria() else turnoInimigo(); atualizarTela() end
                    elseif x>44 then tocar("hat", 12); ESTADO="BATALHA"; atualizarTela() end
                elseif ESTADO == "SUBMENU_ITEM" then
                    if x<=26 then
                        if jogador.pocoes>0 or jogador.pocoesMax>0 then
                            if jogador.pocoesMax>0 then jogador.pocoesMax=jogador.pocoesMax-1; jogador.hp=math.min(jogador.maxHp, jogador.hp+50)
                            else jogador.pocoes=jogador.pocoes-1; jogador.hp=math.min(jogador.maxHp, jogador.hp+25) end
                            mensagemLog="Usou pocao!"; tocar("chime", 18); ESTADO="BATALHA"; atualizarTela(); os.sleep(1); turnoInimigo(); atualizarTela()
                        end
                    elseif x>26 then tocar("hat", 12); ESTADO="BATALHA"; atualizarTela() end
                end
            end
        end
    end
end

local function escutarSaida()
    while rodando do
        local _, p1 = os.pullEvent("key")
        if p1 == keys.q then rodando=false; mon.setBackgroundColor(colors.black); mon.clear() end
    end
end

local sucesso, erro = pcall(function() parallel.waitForAny(escutarSaida, loopJogo, loopMusica) end)
if not sucesso then term.clear(); term.setCursorPos(1,1); print("ERRO DETECTADO:"); print(erro) end
