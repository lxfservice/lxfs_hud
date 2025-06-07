local ESX = exports.es_extended:getSharedObject()

local streetName, direction, zone, postal = "", "", "", ""

local function getDirection(heading)
    local directions = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
    return directions[math.floor((heading + 22.5) / 45.0) % 8 + 1]
end

local function getPostalCode(coords)
    return "90210"
end

CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)
        local zoneName = GetNameOfZone(coords.x, coords.y, coords.z)
        local zoneLabel = GetLabelText(zoneName)
        local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local street = GetStreetNameFromHashKey(street1)
        local direction = getDirection(heading)
        local postal = getPostalCode(coords)

        local hour = GetClockHours()
        local minute = GetClockMinutes()
        local day = GetClockDayOfMonth()
        local month = GetClockMonth()
        local year = GetClockYear()

        local timeStr = string.format("%02d:%02d", hour, minute)
        local dateStr = string.format("%02d.%02d.%d", day, month + 1, year)

        SendNUIMessage({
            action = "updateTopBar",
            street = street,
            direction = direction,
            postal = postal,
            time = timeStr,
            date = dateStr,
        })

        Wait(1000)
    end
end)

AddEventHandler('playerSpawned', function()
    RestorePlayerStamina(PlayerId(), 1.0)
end)

if exports.es_extended:getSharedObject() then
    local ESX = exports.es_extended:getSharedObject()
    print("Automatic using ESX Legacy!")
else
    while ESX == nil do
        TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
        Citizen.Wait(10)
        print("Automatic using old ESX!")
    end
end

function updateHudData()
    ESX.PlayerData = ESX.GetPlayerData()

    local cash = 0
    for _, account in pairs(ESX.PlayerData.accounts or {}) do
        if account.name == 'money' then
            cash = account.money
            break
        end
    end

    local job = "Unemployed"
    if ESX.PlayerData.job then
        local jobLabel = ESX.PlayerData.job.label or ESX.PlayerData.job.name
        local gradeLabel = ESX.PlayerData.job.grade_label or ESX.PlayerData.job.grade_name or tostring(ESX.PlayerData.job.grade)
        job = jobLabel .. " - " .. gradeLabel
    end

    local inVehicle = IsPedInAnyVehicle(PlayerPedId(), false)
    local talking = NetworkIsPlayerTalking(PlayerId())
    local playerArmor = GetPedArmour(PlayerPedId())

    local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
    local fuelLevel = 0
    local vehicleSpeed = 0
    local vehicleArmorPercent = 0

    if inVehicle and vehicle ~= 0 then
        fuelLevel = GetVehicleFuelLevel(vehicle)
        if Config.UseMPH == true then
            vehicleSpeed = math.floor(GetEntitySpeed(vehicle) * 2.23694)
        else
            vehicleSpeed = math.floor(GetEntitySpeed(vehicle) * 3.6)
        end

        local bodyHealth = GetVehicleBodyHealth(vehicle) or 0
        vehicleArmorPercent = math.floor(math.min(bodyHealth, 1000) / 10)
    end

    local energy = 100 - GetPlayerSprintStaminaRemaining(PlayerId())

    ESX.TriggerServerCallback('lxfs_hud:getBankMoney', function(bankMoney)
        TriggerEvent('esx_status:getStatus', 'hunger', function(hungerStatus)
            local hunger = 0
            if hungerStatus then
                hunger = hungerStatus.getPercent()
            end

            TriggerEvent('esx_status:getStatus', 'thirst', function(thirstStatus)
                local thirst = 0
                if thirstStatus then
                    thirst = thirstStatus.getPercent()
                end

                SendNUIMessage({
                    action = "updateHud",
                    cash = cash,
                    bank = bankMoney,
                    job = job,
                    voiceTalking = talking,
                    hunger = hunger,
                    thirst = thirst,
                    energy = energy,
                    speed = vehicleSpeed,
                    fuel = fuelLevel,
                    armor = vehicleArmorPercent,
                    inVehicle = inVehicle
                })
            end)
        end)
    end)
end

RegisterNetEvent('esx:setAccountMoney')
AddEventHandler('esx:setAccountMoney', function(account)
    if account.name == 'bank' or account.name == 'money' then
        ESX.PlayerData.accounts = ESX.PlayerData.accounts or {}
        for i=1, #ESX.PlayerData.accounts do
            if ESX.PlayerData.accounts[i].name == account.name then
                ESX.PlayerData.accounts[i].money = account.money
            end
        end
        updateHudData()
    end
end)

RegisterNetEvent('esx:setMoney')
AddEventHandler('esx:setMoney', function(money)
    ESX.PlayerData.money = money
    updateHudData()
end)

-- local hudMoveActive = false
-- local confirmOpen = false

-- RegisterCommand("hudmove", function()
--     confirmOpen = true
--     SetNuiFocus(true, true)
--     SendNUIMessage({ action = "openConfirm" })
-- end, false)

-- RegisterNUICallback('confirmMove', function(data, cb)
--     SetNuiFocus(true, true)
--     cb('ok')
-- end)

-- RegisterCommand('showconfirm', function()
--     SendNUIMessage({ action = 'openConfirm' })
--     SetNuiFocus(false, false)
-- end)

-- RegisterNUICallback('cancelMove', function(data, cb)
--     SetNuiFocus(false, false)
--     cb('ok')
-- end)

-- RegisterCommand("hudlock", function()
--     hudMoveActive = false
--     confirmOpen = false
--     SetNuiFocus(false, false)
--     SendNUIMessage({ action = "toggleFocus", enable = false })
-- end, false)

Citizen.CreateThread(function()
    while ESX.GetPlayerData().job == nil do
        Citizen.Wait(10)
    end

    PlayerData = ESX.GetPlayerData()
    updateHudData()
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(jobData)
    ESX.PlayerData.job = jobData
    updateHudData()
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        updateHudData()
    end
end)

if Config.UseAEB == true then
    print("AEB: Activated")
    local aebEnabled = true
    local checkInterval = 50
    local detectionDistance = Config.DetectionDistance
    local minSpeedToBrake = Config.MinSpeedToBrake
    local aebActive = false
    local isFrozen = false

    Citizen.CreateThread(function()
        while true do
            Wait(checkInterval)

            if not aebEnabled then
                ResetVehicleState()
                goto continue
            end

            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) then
                ResetVehicleState()
                goto continue
            end

            local veh = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(veh, -1) ~= ped then
                ResetVehicleState()
                goto continue
            end

            local speed = GetEntitySpeed(veh)
            local coords = GetEntityCoords(veh)
            local forwardVector = GetEntityForwardVector(veh)
            local velocity = GetEntityVelocity(veh)
            local dot = velocity.x * forwardVector.x + velocity.y * forwardVector.y

            if dot < -0.1 then
                ResetVehicleState()
                goto continue
            end

            local to = coords + forwardVector * detectionDistance

            local hit, hitCoords, hitEntity = RaycastForward(coords, to, veh)

            if hit and DoesEntityExist(hitEntity) then
                if (IsEntityAVehicle(hitEntity) or IsEntityAnObject(hitEntity) or
                    (IsEntityAPed(hitEntity) and not IsPedInVehicle(hitEntity, veh, true))) then

                    if speed > 0.1 then
                        if not aebActive then
                            aebActive = true
                            StartVehicleHorn(veh, 5000, GetHashKey("NORMAL"), false)
                            SetVehicleIndicatorLights(veh, 0, true)
                            SetVehicleIndicatorLights(veh, 1, true)
                            ESX.ShowNotification("WARNING: Keep Distance!")
                            SetVehicleEnginePowerMultiplier(veh, 0.5)
                            SetVehicleHandbrake(veh, false)
                            isFrozen = false
                        end

                        local newSpeed = math.max(speed - 0.5 * (checkInterval / 1000), 0)
                        SetVehicleForwardSpeed(veh, newSpeed)
                        TaskVehicleTempAction(ped, veh, 3, checkInterval)
                    else
                        if aebActive then
                            aebActive = false
                            FreezeEntityPosition(veh, true)

                            SetVehicleIndicatorLights(veh, 0, false)
                            SetVehicleIndicatorLights(veh, 1, false)
                            SetVehicleEnginePowerMultiplier(veh, 1.0)

                            FreezeEntityPosition(veh, true)
                            isFrozen = true
                            Citizen.CreateThread(function()
                                local timer = GetGameTimer()
                                while GetGameTimer() - timer < 5000 do
                                    Wait(50)
                                    if IsControlPressed(0, 71) or IsControlPressed(0, 72) then
                                        FreezeEntityPosition(veh, false)
                                        SetVehicleHandbrake(veh, false)
                                        isFrozen = false
                                        break
                                    end
                                end
                                if isFrozen then
                                    FreezeEntityPosition(veh, false)
                                    SetVehicleHandbrake(veh, false)
                                    isFrozen = false
                                end
                            end)
                        end
                    end
                else
                    ResetVehicleState()
                end
            else
                ResetVehicleState()
            end

            ::continue::
        end
    end)

    function ResetVehicleState()
        local ped = PlayerPedId()
        if not IsPedInAnyVehicle(ped, false) then return end

        local veh = GetVehiclePedIsIn(ped, false)

        aebActive = false
        isFrozen = false
        SetVehicleHandbrake(veh, false)
        if not GetIsVehicleEngineRunning(veh) then
            SetVehicleEngineOn(veh, false, true, true)
        end
        SetVehicleIndicatorLights(veh, 0, false)
        SetVehicleIndicatorLights(veh, 1, false)
        SetVehicleEnginePowerMultiplier(veh, 1.0)
        FreezeEntityPosition(veh, false)
    end

    function RaycastForward(from, to, vehicle)
        local rayHandle = StartShapeTestCapsule(
            from.x, from.y, from.z + 1.0,
            to.x, to.y, to.z + 1.0,
            2.0,
            10,
            vehicle,
            7
        )
        local a, b, c, d, e = GetShapeTestResult(rayHandle)
        return b, c, e
    end
else
    print("AEB: Disabled")
end

local blacklistedVehicles = Config.Blacklist

Citizen.CreateThread(function()
    while true do
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            local modelHash = GetEntityModel(vehicle)
            local modelName = GetDisplayNameFromVehicleModel(modelHash):lower()

            local speed = GetEntitySpeed(vehicle) * 3.6
            local rpm = GetVehicleCurrentRpm(vehicle) * 8000

            local indicatorState = GetVehicleIndicatorLights(vehicle)
            local leftBlinker = indicatorState == 1 or indicatorState == 3
            local rightBlinker = indicatorState == 2 or indicatorState == 3

            SendNUIMessage({
                action = "update",
                speed = speed,
                rpm = rpm,
                model = modelName,
                blinkLeft = leftBlinker,
                blinkRight = rightBlinker,
            })

            Citizen.Wait(0)
        else
            SendNUIMessage({ action = "hide" })
            Citizen.Wait(500)
        end
    end
end)
