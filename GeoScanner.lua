-- Define o lado onde o scanner está conectado
local lado = "top"
local geo = peripheral.wrap(lado)

-- Limpa a tela
term.clear()
term.setCursorPos(1,1)

-- Verifica se existe algum bloco conectado no topo
if not geo then
    print("Erro: Nenhum periférico detectado no lado: " .. lado)
    return
end

-- Verifica se o bloco conectado realmente tem a função de escanear
if not geo.scan then
    local tipo_bloco = peripheral.getType(lado)
    print("Erro: O bloco no topo foi reconhecido como '" .. tipo_bloco .. "'.")
    print("Esse bloco não possui a função de escaneamento.")
    return
end

print("Iniciando escaneamento de minérios...")
print("-----------------------------------")

-- Define o raio máximo de escaneamento (o padrão máximo geralmente é 8)
local raio = 8 
local blocos = geo.scan(raio)

-- O scanner tem um tempo de recarga (cooldown). Se falhar, avisa o jogador.
if not blocos then
    print("Erro: O escaneamento falhou.")
    print("Aguarde alguns segundos. O scanner está em tempo de recarga (cooldown).")
    return
end

local minerios_encontrados = 0

-- Vasculha a lista de todos os blocos encontrados
for i, bloco in ipairs(blocos) do
    -- Procura pela palavra "ore" no nome do bloco
    if string.find(bloco.name, "ore") then
        minerios_encontrados = minerios_encontrados + 1
        
        -- Formata o nome para ficar limpo na tela
        local nome_limpo = string.gsub(bloco.name, "minecraft:", "")
        nome_limpo = string.gsub(nome_limpo, "forge:", "")
        nome_limpo = string.gsub(nome_limpo, "_ore", "")
        
        print(minerios_encontrados .. ". " .. string.upper(nome_limpo))
        print("   X: " .. bloco.x .. " | Y: " .. bloco.y .. " | Z: " .. bloco.z)
        print("-----------------------------------")
    end
end

if minerios_encontrados == 0 then
    print("Nenhum minério encontrado num raio de " .. raio .. " blocos.")
else
    print("Busca concluída! Total: " .. minerios_encontrados .. " minérios.")
end
