-- =======================================================
-- MODO DE SEGURANÇA - PILGRAMO
-- =======================================================
local mon = peripheral.find("monitor")
local speaker = peripheral.find("speaker") -- Volta a usar apenas 1 alto-falante para evitar crash

if not mon then print("[ERRO] Monitor nao encontrado!") return end

local ESTADO = "MENU"
local volume = 0.8
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

local function tocar(som, pitch)
    if speaker then pcall(function() speaker.playSound(som, volume, pitch or 1.0) end) end
end

local function loopMusica()
    while rodando do
        if speaker and (ESTADO == "MENU" or ESTADO == "BATALHA" or ESTADO == "MAPA") then
            pcall(function() speaker.playSound("music_disc.stal", 2.0, 1.0) end)
        end
        os.sleep(150)
    end
end

-- Bestiario Simplificado
local bestiario = {
    {nome = "Slime de Musgo", maxHp=18, dano=4, xp=6, ouro=15, cor=colors.lime, arte={"       ","  ___  "," (o.o) "," (___) "}},
    {nome = "Lobo Selvagem", maxHp=30, dano=6, xp=10, ouro=25, cor=colors.lightGray, arte={"       "," / \\__ "," (o.o )","  / /  "}},
    {nome = "Esqueleto Negro", maxHp=70, dano=14, xp=25, ouro=60, cor=colors.white, arte={"  .-.  "," (o o) ","  |O|  "," /| |\\ "}}
}
local chefes = {
    [1] = {nome="REI SLIME", maxHp=180, dano=18, xp=80, ouro=150, cor=colors.lime, arte={"   _^_   ","  /   \\  "," | O_O | ","  \\___/  "}},
    [2] = {nome="LORDE VAMPIRO", maxHp=350, dano=28, xp=200, ouro=300, cor=colors.red, arte={" \\_v_v_/ ","  (o o)  ","  /| |\\  ","  /   \\  "}}
}
local listaEventos = {
    {nome="Fonte Sagrada", desc="Voce bebeu agua cristalina e recuperou vida!", cor=colors.cyan, acao=function() jogador.hp=jogador.maxHp end},
    {nome="Bau de Tesouro", desc="Voce encontrou ouro escondido!", cor=colors.yellow, acao=function() jogador.ouro=jogador.ouro+80 end}
}

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

local function atualizarTela()
    mon.setTextScale(1)
    local larg, alt = mon.getSize()
    mon.setBackgroundColor(colors.black); mon.clear()
    
    if ESTADO == "MENU" then
        centralizar(3, "--- P I L G R A M O ---", colors.yellow, colors.black)
        if fs.exists(ARQUIVO_SAVE) then
            desenharBotao(math.floor(larg/2)-12, 8, 24, "CONTINUAR", colors.cyan, colors.black)
            desenharBotao(math.floor(larg/2)-12, 13, 24, "NOVO JOGO", colors.red, colors.white)
        else
            desenharBotao(math.floor(larg/2)-12, 10, 24, "NOVO JOGO", colors.lime, colors.black)
        end
        
    elseif ESTADO == "MAPA" then
        centralizar(2, "ZONA " .. jogador.zona .. " (NODO " .. jogador.nodo .. " DE 6)", colors.cyan, colors.black)
        centralizar(5, "HP: " .. jogador.hp .. "/" .. jogador.maxHp .. " | Ouro: " .. jogador.ouro, colors.lime, colors.black)
        desenharBotao(math.floor(larg/2)-18, 14, 16, "AVANCAR", colors.red, colors.white)
        desenharBotao(math.floor(larg/2)+2, 14, 16, "MERCADOR", colors.yellow, colors.black)
        
    elseif ESTADO == "BATALHA" then
        centralizar(1, "ZONA " .. jogador.zona .. " | HP: " .. jogador.hp, colors.white, colors.blue)
        if inimigoAtual then
            mon.setCursorPos(3, 3); mon.setTextColor(inimigoAtual.cor); mon.write(inimigoAtual.nome)
            desenharBarra(3, 4, 15, inimigoAtual.hp, inimigoAtual.maxHp, colors.red)
        end
        desenharCaixa(2, 12, larg-3, 3, colors.gray)
        mon.setCursorPos(4, 13); mon.setTextColor(colors.white); mon.setBackgroundColor(colors.gray); mon.write("* " .. mensagemLog)
        
        mon.setBackgroundColor(colors.black)
        desenharBotao(2, 16, 12, "[ ATACAR ]", colors.red, colors.white)
        desenharBotao(16, 16, 12, "[ FUGIR ]", colors.yellow, colors.black)
    end
end

local function loopJogo()
    atualizarTela()
    while rodando do
        -- Usando o pullEvent universal para nao travar o computador
        local ev, p1, x, y = os.pullEvent()
        
        if ev == "monitor_touch" then
            local larg, _ = mon.getSize()
            if ESTADO == "MENU" then
                if y >= 8 and y <= 10 and fs.exists(ARQUIVO_SAVE) then carregarJogo(); ESTADO="MAPA"; atualizarTela()
                elseif y >= 10 and y <= 14 then jogador = {hp=60, maxHp=60, tp=0, level=1, xp=0, ouro=10, pocoes=3, pocoesMax=0, danoExtra=0, defesa=0, magiaExtra=0, zona=1, nodo=1}; ESTADO="MAPA"; salvarJogo(); atualizarTela() end
            elseif ESTADO == "MAPA" then
                if y >= 14 and y <= 16 and x <= larg/2 then 
                    local temp = bestiario[1]; inimigoAtual = {nome=temp.nome, maxHp=temp.maxHp, hp=temp.maxHp, dano=temp.dano, xp=temp.xp, ouro=temp.ouro, cor=temp.cor}; ESTADO = "BATALHA"; atualizarTela() 
                end
            elseif ESTADO == "BATALHA" then
                if y >= 16 and y <= 18 then
                    if x >= 2 and x <= 14 then 
                        inimigoAtual.hp = inimigoAtual.hp - 10
                        if inimigoAtual.hp <= 0 then jogador.ouro = jogador.ouro + inimigoAtual.ouro; ESTADO="MAPA" else jogador.hp = jogador.hp - inimigoAtual.dano end
                        atualizarTela()
                    elseif x >= 16 and x <= 28 then ESTADO="MAPA"; atualizarTela() end
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
if not sucesso then term.clear(); term.setCursorPos(1,1); print("ERRO FATAL:"); print(erro) end
