-- Tenta encontrar o Geo Scanner conectado ao computador
local geo = peripheral.wrap("top")

if not geo then
    print("Erro: Geo Scanner não encontrado!")
    print("Conecte o computador a um Geo Scanner do mod Advanced Peripherals.")
    return
end

-- Limpa a tela do computador
term.clear()
term.setCursorPos(1,1)
print("Iniciando escaneamento de minérios...")
print("-----------------------------------")

-- Escaneia os blocos num raio de 8 blocos (limite padrão do scanner)
local raio = 8 
local blocos = geo.scan(raio)

if not blocos then
    print("O escaneamento falhou. O scanner está resfriando (cooldown)?")
    return
end

local minerios_encontrados = 0

-- Vasculha a lista de todos os blocos encontrados no raio
for i, bloco in ipairs(blocos) do
    -- Verifica se o nome do bloco contém a palavra "ore" (minério)
    if string.find(bloco.name, "ore") then
        minerios_encontrados = minerios_encontrados + 1
        
        -- Formata o nome do minério para ficar mais bonito
        local nome_limpo = string.gsub(bloco.name, "minecraft:", "")
        nome_limpo = string.gsub(nome_limpo, "_ore", "")
        
        print(minerios_encontrados .. ". " .. string.upper(nome_limpo))
        -- Mostra a posição do minério em relação ao scanner
        print("   Coordenadas (Relativas):")
        print("   X: " .. bloco.x .. " | Y: " .. bloco.y .. " | Z: " .. bloco.z)
        print("-----------------------------------")
    end
end

if minerios_encontrados == 0 then
    print("Nenhum minério encontrado num raio de " .. raio .. " blocos.")
else
    print("Busca concluída! Total: " .. minerios_encontrados .. " minérios.")
end
